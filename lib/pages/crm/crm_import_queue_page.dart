import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CrmImportQueuePage extends StatefulWidget {
  const CrmImportQueuePage({super.key});

  @override
  State<CrmImportQueuePage> createState() => _CrmImportQueuePageState();
}

class _CrmImportQueuePageState extends State<CrmImportQueuePage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  List<Map<String, dynamic>> pendingEmails = [];

  @override
  void initState() {
    super.initState();
    _loadPendingEmails();
  }

  Future<void> _loadPendingEmails() async {
    setState(() => loading = true);

    final data = await supabase
        .from('crm_email_import_log')
        .select()
        .eq('import_status', 'pending')
        .order('received_at', ascending: false);

    setState(() {
      pendingEmails = List<Map<String, dynamic>>.from(data);
      loading = false;
    });
  }

  Future<void> _approveEmail(Map<String, dynamic> email) async {
    final logId = email['id'];

    try {
      await supabase.rpc(
        'process_email_import',
        params: {'p_log_id': logId},
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email imported into CRM')),
      );

      await _loadPendingEmails();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  Future<void> _rejectEmail(Map<String, dynamic> email) async {
    final logId = email['id'];

    await supabase
        .from('crm_email_import_log')
        .update({
          'import_status': 'rejected',
          'error_message': 'Rejected manually from CRM Import Queue',
        })
        .eq('id', logId);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email rejected')),
    );

    await _loadPendingEmails();
  }

  String _preview(String? rawBody) {
    if (rawBody == null || rawBody.trim().isEmpty) {
      return 'No email body found.';
    }

    final clean = rawBody.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (clean.length <= 260) return clean;
    return '${clean.substring(0, 260)}...';
  }

  String _formatReceived(dynamic value) {
    if (value == null) return 'Unknown date';

    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();

    final local = parsed.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();

    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day-$month-$year\n$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FA),
      appBar: AppBar(
        title: const Text('CRM Import Queue'),
        backgroundColor: const Color(0xFF6F3FA7),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingEmails,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : pendingEmails.isEmpty
              ? const Center(
                  child: Text(
                    'No pending email imports',
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: pendingEmails.length,
                  itemBuilder: (context, index) {
                    final email = pendingEmails[index];
                    final senderName = (email['parsed_name'] ?? '').toString().trim();
                    final senderEmail = (email['parsed_email'] ?? email['from_email'] ?? '').toString().trim();
                    final senderPhone = (email['parsed_phone'] ?? '').toString().trim();
                    

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const CircleAvatar(
                                  backgroundColor: Color(0xFFE9DDF7),
                                  child: Icon(
                                    Icons.mark_email_unread,
                                    color: Color(0xFF6F3FA7),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        email['subject'] ?? 'No subject',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (senderName.isNotEmpty)
                                                Text(
                                                  senderName,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.black87,
                                                  ),
                                                ),

                                              if (senderEmail.isNotEmpty)
                                                Text(
                                                  senderEmail,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.black54,
                                                  ),
                                                ),

                                              if (senderPhone.isNotEmpty)
                                                Text(
                                                  senderPhone,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _formatReceived(email['received_at']),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2ECF8),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                _preview(email['raw_body']),
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.35,
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.close),
                                    label: const Text('Reject'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red.shade700,
                                      side: BorderSide(
                                        color: Colors.red.shade300,
                                      ),
                                    ),
                                    onPressed: () => _rejectEmail(email),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.check),
                                    label: const Text('Approve Import'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF6F3FA7),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => _approveEmail(email),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}