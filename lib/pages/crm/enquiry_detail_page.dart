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
  List<Map<String, dynamic>> inquiryNotes = [];

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

      final notesRes = await supabase
          .from('inquiry_notes')
          .select()
          .eq('inquiry_id', widget.inquiryId)
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false);

      final notesList = List<Map<String, dynamic>>.from(notesRes);

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
        inquiryNotes = notesList;
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

  String _formatDateTime(dynamic value) {
    if (value == null) return '—';

    try {
      final date = _parseSupabaseTime(value);

      const months = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];

      final day = date.day;
      final month = months[date.month - 1];

      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final ampm = date.hour >= 12 ? 'pm' : 'am';

      return '$day $month $hour:$minute$ampm';
    } catch (_) {
      return value.toString();
    }
  }
  DateTime _parseSupabaseTime(dynamic value) {
    final raw = value.toString();

    final hasTimezone =
        raw.endsWith('Z') ||
        raw.contains('+') ||
        RegExp(r'-\d\d:\d\d$').hasMatch(raw);

    final fixed = hasTimezone ? raw : '${raw}Z';

    return DateTime.parse(fixed).toLocal();
  }


  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;

    try {
      return _parseSupabaseTime(value);
    } catch (_) {
      return null;
    }
  }

  String _timeAgo(dynamic value) {
    final date = _toDateTime(value);
    if (date == null) return '';

    final diff = DateTime.now().difference(date);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final weeks = (diff.inDays / 7).floor();
    return '${weeks}w ago';
  }

  Color _enquiryAgeColor() {
    final received = _toDateTime(inquiry?['enquiry_submitted_at']);
    if (received == null) return Colors.grey;

    final diff = DateTime.now().difference(received);

    if (diff.inHours < 12) return Colors.green;
    if (diff.inHours < 24) return Colors.orange;

    return Colors.red;
  }

  String _responseTimeText() {
    final received = _toDateTime(inquiry?['enquiry_submitted_at']);
    if (received == null) return 'Not available';

    Map<String, dynamic>? firstOutbound;

    for (final msg in communications.reversed) {
      if (msg['direction'] == 'outbound') {
        firstOutbound = msg;
        break;
      }
    }

    if (firstOutbound == null) return 'No reply sent yet';

    final replied = _toDateTime(firstOutbound['created_at']);
    if (replied == null) return 'Not available';

    final diff = replied.difference(received);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h ${diff.inMinutes % 60}m';

    return '${diff.inDays}d ${diff.inHours % 24}h';
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
  Future<void> addNote() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Note'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Enter note...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    await supabase.from('inquiry_notes').insert({
      'inquiry_id': widget.inquiryId,
      'note_text': result,
      'created_by': supabase.auth.currentUser?.id,
    });

    await fetchEnquiry();
  }

  Future<void> editNote(Map<String, dynamic> note) async {
    final controller = TextEditingController(text: note['note_text'] ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Note'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    await supabase.from('inquiry_notes').update({
      'note_text': result,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', note['id']);

    await fetchEnquiry();
  }

  Future<void> deleteNote(Map<String, dynamic> note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This note will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete),
            label: const Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await supabase.from('inquiry_notes').delete().eq('id', note['id']);

    await fetchEnquiry();
  }

  Future<void> togglePinnedNote(Map<String, dynamic> note) async {
    final current = note['is_pinned'] == true;

    await supabase.from('inquiry_notes').update({
      'is_pinned': !current,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', note['id']);

    await fetchEnquiry();
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: addNote,
              icon: const Icon(Icons.add),
              label: const Text('Add Note'),
            ),
          ),

          const SizedBox(height: 10),

          if (inquiryNotes.isEmpty)
            const Text('No notes yet.')
          else
            ...inquiryNotes.map((note) {
              final pinned = note['is_pinned'] == true;

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: pinned
                      ? Colors.amber.withOpacity(.12)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: pinned
                        ? Colors.amber.withOpacity(.6)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (pinned) ...[
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            _formatDate(note['created_at']),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: pinned ? 'Unpin note' : 'Mark important',
                          icon: Icon(
                            pinned ? Icons.star : Icons.star_border,
                            color: pinned ? Colors.amber : Colors.grey,
                          ),
                          onPressed: () => togglePinnedNote(note),
                        ),
                        IconButton(
                          tooltip: 'Edit note',
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => editNote(note),
                        ),
                        IconButton(
                          tooltip: 'Delete note',
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: Colors.red,
                          onPressed: () => deleteNote(note),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Text(
                      note['note_text'] ?? '',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              );
            }),
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
  Widget _buildTimingCard() {
    final ageColor = _enquiryAgeColor();
    final receivedAgo = _timeAgo(inquiry?['enquiry_submitted_at']);

    return _sectionCard(
      title: 'Timing',
      icon: Icons.schedule,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(
            'Received',
            '${_formatDateTime(inquiry?['enquiry_submitted_at'])}'
            '${receivedAgo.isNotEmpty ? ' ($receivedAgo)' : ''}',
          ),

          _infoRow(
            'Entered',
            _formatDateTime(inquiry?['created_at']),
          ),

          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: ageColor.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ageColor.withOpacity(.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: ageColor),
                const SizedBox(width: 6),
                Text(
                  receivedAgo.isEmpty
                      ? 'No received time recorded'
                      : 'Enquiry age: $receivedAgo',
                  style: TextStyle(
                    color: ageColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          _infoRow(
            'Response',
            _responseTimeText(),
          ),
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
                          _buildTimingCard(),   // 👈 ADD THIS
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