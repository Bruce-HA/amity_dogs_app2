import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'conversation_page.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({Key? key}) : super(key: key);

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  List<Map<String, dynamic>> conversations = [];

  @override
  void initState() {
    super.initState();
    fetchInbox();
  }

  Future<void> fetchInbox() async {
    try {
      final response = await supabase
          .from('communications')
          .select()
          .order('created_at', ascending: false);

      // Group latest message per person
      final Map<String, Map<String, dynamic>> grouped = {};

      for (var msg in response) {
        final personId = msg['people_id'];
        if (!grouped.containsKey(personId)) {
          grouped[personId] = msg;
        }
      }

      final conversationsList = grouped.values.toList();

      // Get all unique people_ids
      final peopleIds =
          conversationsList.map((e) => e['people_id']).toSet().toList();

      // Fetch people
      final peopleResponse = await supabase
          .from('people')
          .select()
          .inFilter('people_id', peopleIds);

      // Map people by id
      final Map<String, dynamic> peopleMap = {
        for (var p in peopleResponse) p['people_id']: p
      };

      // Attach person to each conversation
      for (var convo in conversationsList) {
        convo['person'] = peopleMap[convo['people_id']];
      }

      setState(() {
        conversations = conversationsList;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching inbox: $e');
      setState(() => isLoading = false);
    }
  }

  String formatTime(String? timestamp) {
    if (timestamp == null) return '';

    final date = DateTime.parse(timestamp).toLocal();
    final now = DateTime.now();

    if (now.difference(date).inDays == 0) {
      return DateFormat('h:mm a').format(date);
    } else {
      return DateFormat('dd MMM').format(date);
    }
  }

  String responseTimer(Map<String, dynamic> msg) {
    final createdAt = DateTime.parse(msg['created_at']).toLocal();
    final direction = msg['direction'];

    if (direction == 'inbound') {
      final diff = DateTime.now().difference(createdAt);

      if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h';
      } else {
        return '${diff.inDays}d';
      }
    }

    return '✓';
  }

  Color timerColor(Map<String, dynamic> msg) {
    final createdAt = DateTime.parse(msg['created_at']).toLocal();
    final direction = msg['direction'];

    if (direction != 'inbound') return Colors.green;

    final diff = DateTime.now().difference(createdAt);

    if (diff.inHours < 1) return Colors.green;
    if (diff.inHours < 3) return Colors.orange;

    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : conversations.isEmpty
              ? const Center(child: Text('No messages yet'))
              : RefreshIndicator(
                  onRefresh: fetchInbox,
                  child: ListView.builder(
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final msg = conversations[index];
                      final person = msg['person'];

                      final name =
                          '${person?['first_name_1st'] ?? ''} ${person?['last_name_1st'] ?? ''}'
                              .trim();

                      final preview = msg['message_body'] ?? '';
                      final channel = msg['channel'] ?? '';
                      final time = formatTime(msg['created_at']);

                      return ListTile(
                       onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ConversationPage(
                                personId: msg['people_id'],
                              ),
                            ),
                          );
                        },
                        leading: CircleAvatar(
                          child: Text(
                            name.isNotEmpty ? name[0] : '?',
                          ),
                        ),
                        title: Text(name.isNotEmpty ? name : 'Unknown'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              channel,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              time,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              responseTimer(msg),
                              style: TextStyle(
                                color: timerColor(msg),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}