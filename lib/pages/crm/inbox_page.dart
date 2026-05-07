import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'email_import_page.dart';
import 'conversation_page.dart';
import 'enquiry_detail_page.dart';
import 'enquiry_form_page.dart';
import 'reply_templates_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'new_enquiry_for_person_page.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool isLoading = true;
  String selectedFilter = 'All';
  String searchText = '';
  String selectedLitterFilter = 'All Litters';

  final List<String> filters = const [
    'All',
    'New',
    'Qualified',
    'Deposit Paid',
    'Waiting',
    'Allocated',
  ];

  List<Map<String, dynamic>> inboxRows = [];

  @override
  void initState() {
    super.initState();
    fetchInbox();
  }

  Future<void> fetchInbox() async {
    setState(() => isLoading = true);

    try {
      final inquiries = await supabase
          .from('inquiries')
          .select()
          .order('updated_at', ascending: false);

      final people = await supabase.from('people').select();

      final communications = await supabase
          .from('communications')
          .select()
          .order('created_at', ascending: false);

      final Map<String, Map<String, dynamic>> peopleById = {
        for (final p in people)
          if (p['people_id'] != null) p['people_id']: Map<String, dynamic>.from(p),
      };

      final Map<String, Map<String, dynamic>> latestMessageByPerson = {};

      for (final msg in communications) {
        final peopleId = msg['people_id'];
        if (peopleId == null) continue;

        latestMessageByPerson.putIfAbsent(
          peopleId,
          () => Map<String, dynamic>.from(msg),
        );
      }

      final List<Map<String, dynamic>> builtRows = [];

      for (final inquiryRaw in inquiries) {
        final inquiry = Map<String, dynamic>.from(inquiryRaw);
        final personId = inquiry['person_id'];

        if (personId == null) continue;

        final person = peopleById[personId];
        final latestMessage = latestMessageByPerson[personId];

        builtRows.add({
          'inquiry': inquiry,
          'person': person,
          'latest_message': latestMessage,
        });
      }

      setState(() {
        inboxRows = builtRows;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('CRM inbox load error: $e');

      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load CRM inbox: $e')),
      );
    }
  }

   Future<void> _callNumber(String phone) async {
        final uri = Uri.parse('tel:$phone');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }

      Future<void> _sendEmail(String email) async {
        final uri = Uri.parse('mailto:$email');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }

  List<Map<String, dynamic>> get filteredRows {
    final rows = inboxRows.where((row) {
      final inquiry = row['inquiry'] as Map<String, dynamic>;
      final person = row['person'] as Map<String, dynamic>?;
      final litterName =
       (inquiry['preferred_litter_name'] ?? '').toString().trim();

      final status = (inquiry['status'] ?? '').toString().toLowerCase();

      final firstName = (person?['first_name_1st'] ?? '').toString();
      final lastName = (person?['last_name_1st'] ?? '').toString();
      final email = (person?['email_1st'] ??
              person?['email'] ??
              '')
          .toString();
      final phone = (person?['phone_1st'] ??
              person?['phone'] ??
              '')
          .toString();

      final haystack = '$firstName $lastName $email $phone'.toLowerCase();

      if (searchText.trim().isNotEmpty &&
          !haystack.contains(searchText.trim().toLowerCase())) {
        return false;
      }
      

      if (selectedLitterFilter != 'All Litters' &&
          litterName != selectedLitterFilter) {
        return false;
      }


      switch (selectedFilter) {
        case 'New':
          return status == 'new';
        case 'Qualified':
          return status == 'qualified';
        case 'Deposit Paid':
          return inquiry['deposit_received'] == true;
        case 'Waiting':
          return status == 'waiting';
        case 'Allocated':
          return inquiry['puppy_dog_id'] != null;
        case 'All':
        default:
          return true;
      }
    }).toList();

    // 👇 SORTING ADDED HERE
    rows.sort((a, b) {
      final aInquiry = a['inquiry'] as Map<String, dynamic>;
      final bInquiry = b['inquiry'] as Map<String, dynamic>;

      final aLatest = a['latest_message'] as Map<String, dynamic>?;
      final bLatest = b['latest_message'] as Map<String, dynamic>?;

      final aDate = DateTime.tryParse(
            (aLatest?['created_at'] ??
                    aInquiry['enquiry_submitted_at'] ??
                    aInquiry['created_at'])
                .toString(),
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      final bDate = DateTime.tryParse(
            (bLatest?['created_at'] ??
                    bInquiry['enquiry_submitted_at'] ??
                    bInquiry['created_at'])
                .toString(),
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate); // 👈 newest first
    });

    return rows;
  }

  List<String> get litterFilters {
    final names = inboxRows
        .map((row) {
          final inquiry = row['inquiry'] as Map<String, dynamic>;
          return (inquiry['preferred_litter_name'] ?? '').toString().trim();
        })
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();

    names.sort();

    return ['All Litters', ...names];
  }

  String _personName(Map<String, dynamic>? person) {
    if (person == null) return 'Unknown buyer';

    final first = (person['first_name_1st'] ?? '').toString().trim();
    final last = (person['last_name_1st'] ?? '').toString().trim();

    final name = '$first $last'.trim();

    if (name.isNotEmpty) return name;

    final business = (person['business_name'] ?? '').toString().trim();
    if (business.isNotEmpty) return business;

    return 'Unnamed buyer';
  }

  String _personContact(Map<String, dynamic>? person) {
    if (person == null) return '';

    final email = (person['email_1st'] ?? person['email'] ?? '').toString();
    final phone = (person['phone_1st'] ?? person['phone'] ?? '').toString();

    if (email.isNotEmpty && phone.isNotEmpty) return '$email • $phone';
    if (email.isNotEmpty) return email;
    if (phone.isNotEmpty) return phone;

    return '';
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';

    try {
      final date = DateTime.parse(value.toString()).toLocal();
      return DateFormat('dd MMM • h:mm a').format(date);
    } catch (_) {
      return '';
    }
  }
  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;

    try {
      return DateTime.parse(value.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }
//
  String _formatDateOnly(dynamic value) {
    if (value == null) return '';

    try {
      final date = DateTime.parse(value.toString()).toLocal();
      return DateFormat('dd MMM yyyy').format(date);
    } catch (_) {
      return '';
    }
  }

  String _formatTimeOnly(dynamic value) {
    if (value == null) return '';

    try {
      final date = DateTime.parse(value.toString()).toLocal();
      return DateFormat('h:mm a').format(date);
    } catch (_) {
      return '';
    }
  }

///
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

  bool _hasOutboundReply(Map<String, dynamic>? latestMessage) {
    if (latestMessage == null) return false;
    return latestMessage['direction'] == 'outbound';
  }

  Color _receivedWarningColor({
    required dynamic receivedAt,
    required Map<String, dynamic>? latestMessage,
  }) {
    final received = _toDateTime(receivedAt);
    if (received == null) return Colors.grey;

    final hasReply = _hasOutboundReply(latestMessage);
    if (hasReply) return Colors.green;

    final diff = DateTime.now().difference(received);

    if (diff.inHours < 12) return Colors.green;
    if (diff.inHours < 24) return Colors.orange;

    return Colors.red;
  }
  String _durationTimer(dynamic fromValue) {
    final from = _toDateTime(fromValue);
    if (from == null) return '';

    final diff = DateTime.now().difference(from);

    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;

    return '${days.toString().padLeft(2, '0')}d '
        '${hours.toString().padLeft(2, '0')}h '
        '${minutes.toString().padLeft(2, '0')}m';
  }
  Future<void> deleteInquiry(String inquiryId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete enquiry?'),
        content: const Text(
          'This will remove this enquiry from the CRM inbox. The person record will remain.',
        ),
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

    try {
      await supabase.from('inquiries').delete().eq('id', inquiryId);

      await fetchInbox();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enquiry deleted')),
      );
    } catch (e) {
      debugPrint('Delete inquiry error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete enquiry: $e')),
      );
    }
  }


  String _receivedWarningText({
    required dynamic receivedAt,
    required Map<String, dynamic>? latestMessage,
  }) {
    final timer = _durationTimer(receivedAt);
    final hasReply = _hasOutboundReply(latestMessage);

    if (timer.isEmpty) return 'Received time missing';

    if (hasReply) {
      return 'Replied • received $timer ago';
    }

    return 'No reply • $timer';
  }


  Color _stageColor(String status, bool depositPaid, bool allocated) {
    if (allocated) return Colors.deepPurple;
    if (depositPaid) return Colors.green;

    switch (status.toLowerCase()) {
      case 'new':
        return Colors.blue;
      case 'qualified':
        return Colors.orange;
      case 'waiting':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _stageLabel(Map<String, dynamic> inquiry) {
    final allocated = inquiry['puppy_dog_id'] != null;
    final depositPaid = inquiry['deposit_received'] == true;

    if (allocated) return 'Allocated';
    if (depositPaid) return 'Deposit Paid';

    final status = (inquiry['status'] ?? 'new').toString();

    final litterName =
      (inquiry['preferred_litter_name'] ?? '').toString().trim();

    if (status.isEmpty) return 'New';

    return status[0].toUpperCase() + status.substring(1);
  }
  Widget _buildLitterFilterDropdown() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: DropdownButtonFormField<String>(
        value: selectedLitterFilter,
        decoration: const InputDecoration(
          labelText: 'Filter by litter',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: litterFilters.map((name) {
          return DropdownMenuItem(
            value: name,
            child: Text(name),
          );
        }).toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() => selectedLitterFilter = value);
        },
      ),
    );
  }

  Widget _buildFilterBar() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = selectedFilter == filter;

          return ChoiceChip(
            label: Text(filter),
            selected: selected,
            onSelected: (_) {
              setState(() => selectedFilter = filter);
            },
          );
        },
      ),
    );
  }

  Widget _buildInboxTile(Map<String, dynamic> row) {
    final inquiry = row['inquiry'] as Map<String, dynamic>;
    final person = row['person'] as Map<String, dynamic>?;
    final latestMessage = row['latest_message'] as Map<String, dynamic>?;

    final personName = _personName(person);
    final contact = _personContact(person);

    final status = (inquiry['status'] ?? 'new').toString();
    final depositPaid = inquiry['deposit_received'] == true;
    final allocated = inquiry['puppy_dog_id'] != null;

    final stageColor = _stageColor(status, depositPaid, allocated);
    final stageLabel = _stageLabel(inquiry);

    final preview = (latestMessage?['message_body'] ??
            inquiry['notes'] ??
            'No message yet')
        .toString();

    final lastContactValue =
      latestMessage?['created_at'] ??
      inquiry['enquiry_submitted_at'] ??
      inquiry['created_at'];

  final lastContactDate = _formatDateOnly(lastContactValue);
  final lastContactTime = _formatTimeOnly(lastContactValue);

    final receivedAt =
        inquiry['enquiry_submitted_at'] ?? inquiry['created_at'];

    final receivedWarningColor = _receivedWarningColor(
      receivedAt: receivedAt,
      latestMessage: latestMessage,
    );

    final receivedWarningText = _receivedWarningText(
      receivedAt: receivedAt,
      latestMessage: latestMessage,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          final personId = person?['people_id'];

          if (personId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This inquiry has no linked person yet.')),
            );
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EnquiryDetailPage(
                inquiryId: inquiry['id'],
              ),
            ),
          ).then((_) => fetchInbox());
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TOP ROW
              Row(
                children: [
                  Expanded(
                    child: Text(
                      personName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (lastContactDate.isNotEmpty || lastContactTime.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              lastContactDate,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Text(
                              lastContactTime,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      IconButton(
                        tooltip: 'Delete enquiry',
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: Colors.red,
                        onPressed: () {
                          deleteInquiry(inquiry['id']);
                        },
                      ),
                    ],
                  ),
                ],
              ),

              if (person != null) ...[
                const SizedBox(height: 3),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((person['email_1st'] ?? person['email'] ?? '').toString().isNotEmpty)
                            GestureDetector(
                              onTap: () => _sendEmail(
                                (person['email_1st'] ?? person['email']).toString(),
                              ),
                              child: Text(
                                (person['email_1st'] ?? person['email']).toString(),
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),

                          if ((person['phone_1st'] ?? person['phone'] ?? '').toString().isNotEmpty)
                            GestureDetector(
                              onTap: () => _callNumber(
                                (person['phone_1st'] ?? person['phone']).toString(),
                              ),
                              child: Text(
                                (person['phone_1st'] ?? person['phone']).toString(),
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // 👇 ICON BUTTONS
                    Column(
                    children: [
                      if ((person['email_1st'] ?? person['email'] ?? '').toString().isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.email, size: 20),
                          onPressed: () => _sendEmail(
                            (person['email_1st'] ?? person['email']).toString(),
                          ),
                        ),

                      if ((person['phone_1st'] ?? person['phone'] ?? '').toString().isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.phone, size: 20),
                          onPressed: () => _callNumber(
                            (person['phone_1st'] ?? person['phone']).toString(),
                          ),
                        ),
                    ],
                  ),
                  ],
                ),
              ],

              const SizedBox(height: 10),

              // STAGE / FLAGS
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _miniChip(stageLabel, stageColor),
                  _miniChip(receivedWarningText, receivedWarningColor),
                  if (depositPaid) _miniChip('Deposit', Colors.green),
                  if (allocated) _miniChip('Puppy linked', Colors.deepPurple),
                  if (inquiry['litter_id'] != null) _miniChip('Litter linked', Colors.teal),
                ],
              ),

              const SizedBox(height: 10),

              // PREVIEW
              Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = filteredRows;

    return Scaffold(
      appBar: AppBar(
      title: const Text('CRM Inbox'),
     /////
      actions: [
        IconButton(
          tooltip: 'Import Website Enquiry',
          icon: const Icon(Icons.file_upload),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EmailImportPage(),
              ),
            ).then((_) => fetchInbox());
          },
        ),
        IconButton(
          tooltip: 'Reply Templates',
          icon: const Icon(Icons.text_snippet),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ReplyTemplatesPage(),
              ),
            );
          },
        ),

        IconButton(
          tooltip: 'New enquiry for existing person',
          icon: const Icon(Icons.person_add_alt_1),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NewEnquiryForPersonPage(),
              ),
            ).then((_) => fetchInbox());
          },
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: fetchInbox,
          icon: const Icon(Icons.refresh),
        ),
 
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EnquiryFormPage(),
              ),
            ).then((_) => fetchInbox());
          },
        ),
      ],
    ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search buyer, email or phone...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onChanged: (value) {
                setState(() => searchText = value);
              },
            ),
          ),

          _buildFilterBar(),
          _buildLitterFilterDropdown(),

          const SizedBox(height: 4),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? const Center(
                        child: Text('No CRM enquiries found.'),
                      )
                    : RefreshIndicator(
                        onRefresh: fetchInbox,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            return _buildInboxTile(list[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}