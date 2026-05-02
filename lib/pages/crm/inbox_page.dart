import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'conversation_page.dart';
import 'enquiry_detail_page.dart';
import 'enquiry_form_page.dart';
import 'reply_templates_page.dart';

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

  List<Map<String, dynamic>> get filteredRows {
    return inboxRows.where((row) {
      final inquiry = row['inquiry'] as Map<String, dynamic>;
      final person = row['person'] as Map<String, dynamic>?;

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
      return DateFormat('dd MMM yyyy').format(date);
    } catch (_) {
      return '';
    }
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

    if (status.isEmpty) return 'New';

    return status[0].toUpperCase() + status.substring(1);
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

    final lastContact = _formatDate(
      latestMessage?['created_at'] ?? inquiry['updated_at'] ?? inquiry['created_at'],
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
                  if (lastContact.isNotEmpty)
                    Text(
                      lastContact,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),

              if (contact.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  contact,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // STAGE / FLAGS
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _miniChip(stageLabel, stageColor),
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