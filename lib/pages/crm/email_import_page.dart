import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/crm_email_parser.dart';

class EmailImportPage extends StatefulWidget {
  const EmailImportPage({super.key});

  @override
  State<EmailImportPage> createState() => _EmailImportPageState();
}

class _EmailImportPageState extends State<EmailImportPage> {
  Map<String, dynamic>? existingPerson;
  String? existingPersonId;
  final SupabaseClient supabase = Supabase.instance.client;

  final rawController = TextEditingController();

  ParsedCrmEnquiry? parsed;
  bool isSaving = false;

  @override
  void dispose() {
    rawController.dispose();
    super.dispose();
  }

  Future<void> parseText() async {
  final raw = rawController.text.trim();

  if (raw.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Paste the enquiry first.')),
    );
    return;
  }

  final parsedData = CrmEmailParser.parse(raw);

  Map<String, dynamic>? foundPerson;

  // 🔍 Check by email
  if (parsedData.email.isNotEmpty) {
    final res = await supabase
        .from('people')
        .select()
        .or('email_1st.eq.${parsedData.email},email.eq.${parsedData.email}')
        .limit(1);

    if (res.isNotEmpty) {
      foundPerson = res.first;
    }
  }

  // 🔍 Check by phone (fallback)
  if (foundPerson == null && parsedData.phone.isNotEmpty) {
    final res = await supabase
        .from('people')
        .select()
        .or('phone_1st.eq.${parsedData.phone},phone.eq.${parsedData.phone}')
        .limit(1);

    if (res.isNotEmpty) {
      foundPerson = res.first;
    }
  }
  setState(() {
    parsed = parsedData;
    existingPerson = foundPerson;
    existingPersonId = foundPerson?['people_id'];
  });
}

  Future<String?> findExistingPersonId(ParsedCrmEnquiry data) async {
    if (data.email.isNotEmpty) {
      final res = await supabase
          .from('people')
          .select()
          .or('email_1st.eq.${data.email},email.eq.${data.email}')
          .limit(1);

      if (res.isNotEmpty) return res.first['people_id'];
    }

    if (data.phone.isNotEmpty) {
      final res = await supabase
          .from('people')
          .select()
          .or('phone_1st.eq.${data.phone},phone.eq.${data.phone}')
          .limit(1);

      if (res.isNotEmpty) return res.first['people_id'];
    }

    return null;
  }

  Future<String> createOrUpdatePerson(ParsedCrmEnquiry data) async {
    final existingId = await findExistingPersonId(data);
    if (existingPersonId != null) {
      return existingPersonId!;
    }
    final payload = {
      'first_name_1st': data.firstName.isEmpty ? 'Unknown' : data.firstName,
      'last_name_1st': data.lastName.isEmpty ? 'Buyer' : data.lastName,
      'email_1st': data.email,
      'phone_1st': data.phone,
      'street_address': data.address,
      'is_buyer': true,
      'is_prospect': true,
    };

    if (existingId != null) {
      await supabase.from('people').update(payload).eq('people_id', existingId);
      return existingId;
    }

    final res = await supabase.from('people').insert(payload).select().single();
    return res['people_id'];
  }

  Future<void> saveToCrm() async {
    final data = parsed;
    if (data == null) return;

    setState(() => isSaving = true);

    try {
      final personId = await createOrUpdatePerson(data);

      final inquiryRes = await supabase
          .from('inquiries')
          .insert({
            'person_id': personId,
            'status': 'new',
            'interest_level': 'interested',
            'notes': data.message,
            'size_preference': data.sizePreference,
            'sex_preference': data.sexPreference,
            'colour_preference': data.colourPreference,
            'timeframe_preference': data.timeframePreference,
            'address_summary': data.address,
            'form_source': data.formSource,
            'agreement_notes': data.agreementNotes,
            'enquiry_submitted_at': data.enquirySubmittedAt?.toIso8601String(),
            'created_at': data.enquirySubmittedAt?.toIso8601String()
                ?? DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();  // 👈 THIS IS THE KEY

      final inquiryId = inquiryRes['id'];  // 👈 NOW IT EXISTS

      if (data.message.trim().isNotEmpty) {
      await supabase.from('inquiry_notes').insert({
        'inquiry_id': inquiryId,
        'note_text': data.message.trim(),
        'is_pinned': false,
        'created_at': data.enquirySubmittedAt?.toIso8601String()
            ?? DateTime.now().toIso8601String(),
        'created_by': supabase.auth.currentUser?.id,
      });
    }

      await supabase.from('communications').insert({
        'people_id': personId,
        'channel': 'email',
        'direction': 'inbound',
        'subject': data.formSource == 'website_long_form'
            ? 'Website Puppy Enquiry'
            : 'Website Contact Form',
        'message_body': data.rawText,
        'status': 'new',
        // 👇 SAME FIX HERE
        'created_at': data.enquirySubmittedAt?.toIso8601String()
            ?? DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enquiry imported to CRM')),
      );
    } catch (e) {
      debugPrint('Import error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not import enquiry: $e')),
      );
    }

    if (mounted) setState(() => isSaving = false);
  }
  List<String> _personRoles(Map<String, dynamic> person) {
  final roles = <String>[];

  if (person['is_breeder'] == true) roles.add('Breeder');
  if (person['is_supplier'] == true) roles.add('Supplier');
  if (person['is_owner'] == true) roles.add('Owner');
  if (person['is_guardian'] == true) roles.add('Guardian');
  if (person['is_buyer'] == true) roles.add('Buyer');
  if (person['is_prospect'] == true) roles.add('Prospect');

  return roles;
}

Widget _alertChip(String label, Color color, {IconData? icon}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(.4)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}

Widget _existingPersonAlert() {
  if (existingPerson == null) return const SizedBox.shrink();

  final roles = _personRoles(existingPerson!);

  final warningFlags = List<String>.from(
    existingPerson!['crm_warning_flags'] ?? [],
  );

  final warningNotes =
      (existingPerson!['crm_warning_notes'] ?? '').toString().trim();

  final name =
      '${existingPerson!['first_name_1st'] ?? ''} ${existingPerson!['last_name_1st'] ?? ''}'
          .trim();

  final email = (existingPerson!['email_1st'] ??
          existingPerson!['email'] ??
          '')
      .toString();

  final phone = (existingPerson!['phone_1st'] ??
          existingPerson!['phone'] ??
          '')
      .toString();

  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 12, bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.orange.withOpacity(.10),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.orange.withOpacity(.55)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              'Existing person found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Text(
          name.isEmpty ? 'Unnamed person' : name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),

        if (email.isNotEmpty) Text(email),
          if (phone.isNotEmpty) Text(phone),

          const SizedBox(height: 10),

          if (roles.isNotEmpty) ...[
            const Text(
              'Current roles',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: roles
                  .map((role) => _alertChip(role, Colors.blueGrey))
                  .toList(),
            ),
            const SizedBox(height: 10),
          ],

          if (warningFlags.isNotEmpty) ...[
            const Text(
              'CRM warnings',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: warningFlags.map((flag) {
                if (flag == 'Possible 2nd dog buyer') {
                  return _alertChip(
                    flag,
                    Colors.green,
                    icon: Icons.star,
                  );
                }

                if (flag == 'Do not proceed') {
                  return _alertChip(
                    flag,
                    Colors.red,
                    icon: Icons.block,
                  );
                }

                return _alertChip(
                  flag,
                  Colors.orange,
                  icon: Icons.report_problem,
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],

          if (warningNotes.isNotEmpty) ...[
            const Text(
              'Warning notes',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(warningNotes),
          ],

          const SizedBox(height: 10),

          const Text(
            'This enquiry will be linked to the existing person record.',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }


  Widget _previewRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _previewCard() {
    final data = parsed;
    if (data == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(top: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _existingPersonAlert(),   // 👈 ADD THIS LINE
            _previewRow('Source', data.formSource),
            _previewRow('Name', data.name),
            _previewRow('Email', data.email),
            _previewRow('Phone', data.phone),
            _previewRow('Address', data.address),
            _previewRow('Size', data.sizePreference),
            _previewRow('Sex', data.sexPreference),
            _previewRow('Colour', data.colourPreference),
            _previewRow('Timeframe', data.timeframePreference),
            _previewRow(
              'Submitted',
              data.enquirySubmittedAt?.toString() ?? 'Not found',
            ),
            const Divider(),
            _previewRow('Message', data.message),
            _previewRow('Agreements', data.agreementNotes),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : saveToCrm,
                icon: const Icon(Icons.save),
                label: const Text('Save to CRM'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Website Enquiry'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(14),
            children: [
              const Text(
                'Paste the whole website enquiry email below.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: rawController,
                minLines: 12,
                maxLines: 20,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Paste full enquiry email here...',
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: parseText,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Parse / Preview'),
              ),
              _previewCard(),
            ],
          ),
          if (isSaving)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(.08),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}