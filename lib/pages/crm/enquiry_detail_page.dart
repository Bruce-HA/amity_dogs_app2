import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'conversation_page.dart';

class EnquiryDetailPage extends StatefulWidget {
  final String inquiryId;

  const EnquiryDetailPage({
    super.key,
    required this.inquiryId,
  });

  @override
  State<EnquiryDetailPage> createState() => _EnquiryDetailPageState();
}

class _EnquiryDetailPageState extends State<EnquiryDetailPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool isLoading = true;
  bool isSaving = false;

  Map<String, dynamic>? inquiry;
  Map<String, dynamic>? person;
  Map<String, dynamic>? puppy;
  List<Map<String, dynamic>> communications = [];

  final TextEditingController noteController = TextEditingController();

  final List<String> stages = const [
    'new',
    'qualified',
    'waiting',
    'deposit_paid',
    'allocated',
    'completed',
    'lost',
  ];

  @override
  void initState() {
    super.initState();
    fetchEnquiry();
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  Future<void> fetchEnquiry() async {
    setState(() => isLoading = true);

    try {
      final inquiryRes = await supabase
          .from('inquiries')
          .select()
          .eq('id', widget.inquiryId)
          .single();

      final inquiryMap = Map<String, dynamic>.from(inquiryRes);

      Map<String, dynamic>? personMap;
      Map<String, dynamic>? puppyMap;
      List<Map<String, dynamic>> comms = [];

      if (inquiryMap['person_id'] != null) {
        final personRes = await supabase
            .from('people')
            .select()
            .eq('people_id', inquiryMap['person_id'])
            .single();

        personMap = Map<String, dynamic>.from(personRes);

        final commsRes = await supabase
            .from('communications')
            .select()
            .eq('people_id', inquiryMap['person_id'])
            .order('created_at', ascending: false);

        comms = List<Map<String, dynamic>>.from(commsRes);
      }

      if (inquiryMap['puppy_dog_id'] != null) {
        final puppyRes = await supabase
            .from('dogs')
            .select()
            .eq('id', inquiryMap['puppy_dog_id'])
            .single();

        puppyMap = Map<String, dynamic>.from(puppyRes);
      }

      noteController.text = (inquiryMap['notes'] ?? '').toString();

      setState(() {
        inquiry = inquiryMap;
        person = personMap;
        puppy = puppyMap;
        communications = comms;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Enquiry detail load error: $e');

      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load enquiry: $e')),
      );
    }
  }

  Future<void> updateStage(String newStage) async {
    if (inquiry == null) return;

    final oldStage = (inquiry!['status'] ?? '').toString();

    if (oldStage == newStage) return;

    setState(() => isSaving = true);

    try {
      await supabase.from('inquiries').update({
        'status': newStage,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.inquiryId);

      await supabase.from('inquiry_status_history').insert({
        'inquiry_id': widget.inquiryId,
        'old_status': oldStage,
        'new_status': newStage,
        'changed_at': DateTime.now().toIso8601String(),
        'changed_by': supabase.auth.currentUser?.email ?? 'app',
      });

      await fetchEnquiry();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stage changed to ${_prettyStage(newStage)}')),
      );
    } catch (e) {
      debugPrint('Stage update error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update stage: $e')),
      );
    }

    if (mounted) {
      setState(() => isSaving = false);
    }
  }

  Future<void> saveNotes() async {
    if (inquiry == null) return;

    setState(() => isSaving = true);

    try {
      await supabase.from('inquiries').update({
        'notes': noteController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.inquiryId);

      await fetchEnquiry();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes saved')),
      );
    } catch (e) {
      debugPrint('Save notes error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save notes: $e')),
      );
    }

    if (mounted) {
      setState(() => isSaving = false);
    }
  }

  Future<void> toggleDeposit(bool value) async {
    if (inquiry == null) return;

    setState(() => isSaving = true);

    try {
      await supabase.from('inquiries').update({
        'deposit_received': value,
        'status': value ? 'deposit_paid' : inquiry!['status'],
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.inquiryId);

      if (value) {
        await supabase.from('inquiry_status_history').insert({
          'inquiry_id': widget.inquiryId,
          'old_status': inquiry!['status'],
          'new_status': 'deposit_paid',
          'changed_at': DateTime.now().toIso8601String(),
          'changed_by': supabase.auth.currentUser?.email ?? 'app',
        });
      }

      await fetchEnquiry();
    } catch (e) {
      debugPrint('Deposit update error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update deposit: $e')),
      );
    }

    if (mounted) {
      setState(() => isSaving = false);
    }
  }

  String _personName() {
    if (person == null) return 'Unknown buyer';

    final first = (person!['first_name_1st'] ?? '').toString().trim();
    final last = (person!['last_name_1st'] ?? '').toString().trim();
    final name = '$first $last'.trim();

    if (name.isNotEmpty) return name;

    return (person!['business_name'] ?? 'Unnamed buyer').toString();
  }

  String _personContact() {
    if (person == null) return '';

    final email = (person!['email_1st'] ?? person!['email'] ?? '').toString();
    final phone = (person!['phone_1st'] ?? person!['phone'] ?? '').toString();

    if (email.isNotEmpty && phone.isNotEmpty) return '$email • $phone';
    if (email.isNotEmpty) return email;
    if (phone.isNotEmpty) return phone;

    return '';
  }

  String _prettyStage(String raw) {
    if (raw.isEmpty) return 'New';

    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';

    try {
      final date = DateTime.parse(value.toString()).toLocal();
      return DateFormat('dd MMM yyyy • h:mm a').format(date);
    } catch (_) {
      return '';
    }
  }

  Color _stageColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return Colors.blue;
      case 'qualified':
        return Colors.orange;
      case 'waiting':
        return Colors.teal;
      case 'deposit_paid':
        return Colors.green;
      case 'allocated':
        return Colors.deepPurple;
      case 'completed':
        return Colors.indigo;
      case 'lost':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
    IconData? icon,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _stageChip(String stage) {
    final current = (inquiry?['status'] ?? 'new').toString();
    final selected = current == stage;
    final color = _stageColor(stage);

    return ChoiceChip(
      label: Text(_prettyStage(stage)),
      selected: selected,
      selectedColor: color.withOpacity(.18),
      onSelected: isSaving ? null : (_) => updateStage(stage),
      labelStyle: TextStyle(
        color: selected ? color : null,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
      ),
    );
  }

  Widget _buildHeader() {
    final status = (inquiry?['status'] ?? 'new').toString();
    final color = _stageColor(status);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 7),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.teal.shade700,
            Colors.teal.shade400,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _personName(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _personContact(),
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _prettyStage(status),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerCard() {
    return _sectionCard(
      title: 'Buyer Details',
      icon: Icons.person,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow('Name', _personName()),
          _infoRow('Contact', _personContact()),
          _infoRow(
            'Address',
            [
              person?['street_address'],
              person?['suburb_address'],
              person?['state_address'],
              person?['postcode_address'],
            ].where((v) => v != null && v.toString().trim().isNotEmpty).join(', '),
          ),
          _infoRow('Buyer', person?['is_buyer'] == true ? 'Yes' : ''),
          _infoRow('Prospect', person?['is_prospect'] == true ? 'Yes' : ''),
        ],
      ),
    );
  }

  Widget _buildStageCard() {
    return _sectionCard(
      title: 'Enquiry Stage',
      icon: Icons.timeline,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: stages.map(_stageChip).toList(),
      ),
    );
  }

  Widget _buildSalesCard() {
    final depositReceived = inquiry?['deposit_received'] == true;
    final depositAmount = inquiry?['deposit_amount']?.toString() ?? '';
    final interest = inquiry?['interest_level']?.toString() ?? '';

    return _sectionCard(
      title: 'Sales Details',
      icon: Icons.sell,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Deposit received'),
            value: depositReceived,
            onChanged: isSaving ? null : toggleDeposit,
          ),
          _infoRow('Deposit', depositAmount),
          _infoRow('Interest', interest),
          _infoRow('Litter ID', inquiry?['litter_id']?.toString() ?? ''),
          _infoRow('Puppy ID', inquiry?['puppy_dog_id']?.toString() ?? ''),
          if (puppy != null) ...[
            const Divider(),
            _infoRow('Puppy', puppy?['dog_name']?.toString() ?? ''),
            _infoRow('ALA', puppy?['dog_ala']?.toString() ?? ''),
            _infoRow('Sex', puppy?['sex']?.toString() ?? ''),
            _infoRow('Colour', puppy?['colour']?.toString() ?? puppy?['color']?.toString() ?? ''),
          ],
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return _sectionCard(
      title: 'Notes',
      icon: Icons.note_alt,
      child: Column(
        children: [
          TextField(
            controller: noteController,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Add enquiry notes here...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : saveNotes,
              icon: const Icon(Icons.save),
              label: const Text('Save Notes'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesCard() {
    return _sectionCard(
      title: 'Messages Timeline',
      icon: Icons.message,
      child: Column(
        children: [
          if (person != null)
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ConversationPage(
                        personId: person!['people_id'],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat),
                label: const Text('Open Conversation'),
              ),
            ),
          const SizedBox(height: 10),
          if (communications.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('No messages yet.'),
            )
          else
            ...communications.take(8).map((msg) {
              final inbound = msg['direction'] == 'inbound';

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: inbound
                      ? Colors.grey.shade100
                      : Colors.blue.withOpacity(.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inbound ? 'Inbound' : 'Outbound',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: inbound ? Colors.grey.shade700 : Colors.blue,
                      ),
                    ),
                    if ((msg['subject'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        msg['subject'].toString(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      (msg['message_body'] ?? '').toString(),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(msg['created_at']),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = person == null ? 'Enquiry' : _personName();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: fetchEnquiry,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : inquiry == null
              ? const Center(child: Text('Enquiry not found.'))
              : Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: fetchEnquiry,
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          _buildHeader(),
                          _buildBuyerCard(),
                          _buildStageCard(),
                          _buildSalesCard(),
                          _buildNotesCard(),
                          _buildMessagesCard(),
                        ],
                      ),
                    ),
                    if (isSaving)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(.08),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}