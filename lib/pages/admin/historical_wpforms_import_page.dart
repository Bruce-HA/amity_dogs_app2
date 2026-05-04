import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoricalWpFormsImportPage extends StatefulWidget {
  const HistoricalWpFormsImportPage({super.key});

  @override
  State<HistoricalWpFormsImportPage> createState() =>
      _HistoricalWpFormsImportPageState();
}

class _HistoricalWpFormsImportPageState
    extends State<HistoricalWpFormsImportPage> {
  final supabase = Supabase.instance.client;

  bool loading = false;
  bool imported = false;

  String formType = 'long';
  String fileName = '';

  List<Map<String, dynamic>> previewRows = [];
  List<String> logLines = [];

  Future<void> pickWorkbook() async {
    setState(() {
      loading = true;
      imported = false;
      previewRows = [];
      logLines = [];
      fileName = '';
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) {
        setState(() => loading = false);
        return;
      }

      final file = result.files.single;
      fileName = file.name;

      final rows = parseWorkbook(file.bytes!);

      setState(() {
        previewRows = rows;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      _snack('Could not read workbook: $e');
    }
  }

  List<Map<String, dynamic>> parseWorkbook(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables.values.first;

    if (sheet.rows.isEmpty) return [];

    final headers = sheet.rows.first
        .map((cell) => cell?.value?.toString().trim() ?? '')
        .toList();

    final parsed = <Map<String, dynamic>>[];

    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];

      String value(String header) {
        final index = headers.indexWhere(
          (h) => h.toLowerCase() == header.toLowerCase(),
        );

        if (index == -1 || index >= row.length) return '';

        return row[index]?.value?.toString().trim() ?? '';
      }

      Map<String, dynamic> item;

      if (formType == 'short') {
        final first = value('Name: First');
        final last = value('Name: Last');

        item = {
          'first_name': first,
          'last_name': last,
          'full_name': '$first $last'.trim(),
          'email': value('Email'),
          'phone': cleanPhone(value('Phone')),
          'message': value('Comment or Message'),
          'entry_date': value('Entry Date'),
          'submitter_ip': value('User IP'),
          'form_source': 'wpforms_short_contact',
        };
      } else {
        item = {
          'full_name': value('Name'),
          'email': value('Email'),
          'phone': cleanPhone(value('Contact Phone')),
          'address': [
            value('Address: Address Line 1'),
            value('Address: Address Line 2'),
            value('Address: City'),
            value('Address: State'),
            value('Address: Zip/Postal Code'),
            value('Address: Country'),
          ].where((v) => v.toString().trim().isNotEmpty).join('\n'),
          'size_preference': value('Size'),
          'sex_preference': value('Sex'),
          'colour_preference': value('Coat Colour'),
          'timeframe_preference': value('Time frame'),
          'message': value('Comment or Message'),
          'entry_date': value('Entry Date'),
          'submitter_ip': value('User IP'),
          'form_source': 'wpforms_long_contact',
        };

        final nameParts = item['full_name'].toString().split(' ');
        item['first_name'] = nameParts.isNotEmpty ? nameParts.first : '';
        item['last_name'] =
            nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      }

      if ((item['email'] ?? '').toString().isEmpty &&
          (item['phone'] ?? '').toString().isEmpty &&
          (item['full_name'] ?? '').toString().isEmpty) {
        continue;
      }

      item['submitted_at'] = parseEntryDate(item['entry_date']);
      parsed.add(item);
    }

    return parsed;
  }

  String cleanPhone(String value) {
    return value.replaceAll("'", '').replaceAll(' ', '').trim();
  }

  DateTime? parseEntryDate(String value) {
    if (value.trim().isEmpty) return null;

    final months = {
      'January': 1,
      'February': 2,
      'March': 3,
      'April': 4,
      'May': 5,
      'June': 6,
      'July': 7,
      'August': 8,
      'September': 9,
      'October': 10,
      'November': 11,
      'December': 12,
    };

    try {
      final parts = value.split(' ');
      final month = months[parts[0]];
      final day = int.parse(parts[1].replaceAll(',', ''));
      final year = int.parse(parts[2]);

      final time = parts[3];
      final ampm = parts[4].toLowerCase();

      final hm = time.split(':');
      var hour = int.parse(hm[0]);
      final minute = int.parse(hm[1]);

      if (ampm == 'pm' && hour != 12) hour += 12;
      if (ampm == 'am' && hour == 12) hour = 0;

      return DateTime(year, month!, day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  Future<String?> findExistingPerson(Map<String, dynamic> row) async {
    final email = row['email']?.toString() ?? '';
    final phone = row['phone']?.toString() ?? '';

    if (email.isNotEmpty) {
      final res = await supabase
          .from('people')
          .select()
          .or('email_1st.eq.$email,email.eq.$email')
          .limit(1);

      if (res.isNotEmpty) return res.first['people_id'];
    }

    if (phone.isNotEmpty) {
      final res = await supabase
          .from('people')
          .select()
          .or('phone_1st.eq.$phone,phone.eq.$phone')
          .limit(1);

      if (res.isNotEmpty) return res.first['people_id'];
    }

    return null;
  }

  Future<void> importRows() async {
    if (previewRows.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import historical enquiries?'),
        content: Text(
          'This will import ${previewRows.length} rows as Historical CRM enquiries.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      loading = true;
      logLines = [];
    });

    int createdPeople = 0;
    int matchedPeople = 0;
    int createdInquiries = 0;

    try {
      for (final row in previewRows) {
        String? personId = await findExistingPerson(row);

        final payload = {
          'first_name_1st': row['first_name']?.toString().isNotEmpty == true
              ? row['first_name']
              : 'Unknown',
          'last_name_1st': row['last_name']?.toString().isNotEmpty == true
              ? row['last_name']
              : 'Buyer',
          'email_1st': row['email'],
          'phone_1st': row['phone'],
          'street_address': row['address'] ?? '',
          'is_buyer': true,
          'is_prospect': true,
        };

        if (personId == null) {
          final personRes =
              await supabase.from('people').insert(payload).select().single();

          personId = personRes['people_id'];
          createdPeople++;
        } else {
          await supabase.from('people').update(payload).eq('people_id', personId);
          matchedPeople++;
        }

        final submittedAt =
            (row['submitted_at'] as DateTime?)?.toIso8601String();

        final inquiryRes = await supabase.from('inquiries').insert({
          'person_id': personId,
          'status': 'new',
          'interest_level': 'interested',
          'notes': row['message'] ?? '',
          'size_preference': row['size_preference'] ?? '',
          'sex_preference': row['sex_preference'] ?? '',
          'colour_preference': row['colour_preference'] ?? '',
          'timeframe_preference': row['timeframe_preference'] ?? '',
          'address_summary': row['address'] ?? '',
          'form_source': row['form_source'],
          'is_historical': true,
          'imported_from': fileName,
          'submitter_ip': row['submitter_ip'],
          'enquiry_submitted_at': submittedAt,
          'created_at': submittedAt ?? DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).select().single();

        final inquiryId = inquiryRes['id'];
        createdInquiries++;

        if ((row['message'] ?? '').toString().trim().isNotEmpty) {
          await supabase.from('inquiry_notes').insert({
            'inquiry_id': inquiryId,
            'note_text': row['message'],
            'is_pinned': false,
            'created_at': submittedAt ?? DateTime.now().toIso8601String(),
            'created_by': supabase.auth.currentUser?.id,
          });
        }

        await supabase.from('communications').insert({
          'people_id': personId,
          'channel': 'email',
          'direction': 'inbound',
          'subject': row['form_source'] == 'wpforms_long_contact'
              ? 'Historical Website Puppy Enquiry'
              : 'Historical Website Contact Form',
          'message_body': row['message'] ?? '',
          'status': 'historical',
          'submitter_ip': row['submitter_ip'],
          'created_at': submittedAt ?? DateTime.now().toIso8601String(),
          'created_by': supabase.auth.currentUser?.id,
        });
      }

      setState(() {
        loading = false;
        imported = true;
        logLines = [
          'Imported ${previewRows.length} rows',
          'Created people: $createdPeople',
          'Matched existing people: $matchedPeople',
          'Created enquiries: $createdInquiries',
        ];
      });

      _snack('Historical import complete');
    } catch (e) {
      setState(() => loading = false);
      _snack('Import failed: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Widget previewCard(Map<String, dynamic> row) {
    return Card(
      child: ListTile(
        title: Text(row['full_name'] ?? 'Unknown'),
        subtitle: Text(
          '${row['email'] ?? ''}\n'
          '${row['phone'] ?? ''}\n'
          '${row['entry_date'] ?? ''}\n'
          'IP: ${row['submitter_ip'] ?? ''}',
        ),
        isThreeLine: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sample = previewRows.take(20).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historical WPForms Import'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Safe Historical Import',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose whether this is the long puppy form or the short contact form, then select the Excel workbook.',
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: formType,
                    decoration: const InputDecoration(
                      labelText: 'Workbook type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'long',
                        child: Text('Long puppy enquiry form'),
                      ),
                      DropdownMenuItem(
                        value: 'short',
                        child: Text('Short contact form'),
                      ),
                    ],
                    onChanged: loading
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() {
                              formType = value;
                              previewRows = [];
                              logLines = [];
                              imported = false;
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: loading ? null : pickWorkbook,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Choose Excel Workbook'),
                  ),
                ],
              ),
            ),
          ),

          if (loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),

          if (previewRows.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Preview: ${previewRows.length} rows found',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),

            ...sample.map(previewCard),

            if (previewRows.length > sample.length)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '+ ${previewRows.length - sample.length} more rows',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: loading || imported ? null : importRows,
              icon: const Icon(Icons.cloud_upload),

              label: const Text('Import as Historical'),
            ),
          ],

          if (logLines.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Import Summary',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    ...logLines.map((line) => Text(line)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}