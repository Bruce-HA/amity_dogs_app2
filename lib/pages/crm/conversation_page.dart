import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ConversationPage extends StatefulWidget {
  final String personId;

  const ConversationPage({Key? key, required this.personId})
      : super(key: key);

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  List messages = [];
  Map<String, dynamic>? person;

  final TextEditingController _controller = TextEditingController();
  bool isSending = false;

  @override
  void initState() {
    super.initState();
    fetchConversation();
  }

  Future<void> fetchConversation() async {
    try {
      final msgs = await supabase
          .from('communications')
          .select()
          .eq('people_id', widget.personId)
          .order('created_at', ascending: true);

      final personData = await supabase
          .from('people')
          .select()
          .eq('people_id', widget.personId)
          .single();

      setState(() {
        messages = msgs;
        person = personData;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading conversation: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => isSending = true);

    try {
      final user = supabase.auth.currentUser;

      // 🔹 Get person's email
      final personData = await supabase
          .from('people')
          .select('email')
          .eq('people_id', widget.personId)
          .single();

      final email = personData['email'];

      // 🔹 Call Edge Function (send email)
      await supabase.functions.invoke(
        'send-email',
        body: {
          'to': email,
          'subject': 'Reply from Amity Labradoodles',
          'message': text,
        },
      );

      // 🔹 Save to communications
      await supabase.from('communications').insert({
        'communication_id': const Uuid().v4(),
        'people_id': widget.personId,
        'message_body': text,
        'created_at': DateTime.now().toIso8601String(),
        'channel': 'email',
        'direction': 'outbound',
        'created_by': user?.id,
      });

      _controller.clear();
      await fetchConversation();

    } catch (e) {
      debugPrint('Send error: $e');
    }

    setState(() => isSending = false);
  }

  String formatTime(String? timestamp) {
    if (timestamp == null) return '';

    final date = DateTime.parse(timestamp).toLocal();
    return DateFormat('dd MMM • h:mm a').format(date);
  }

  Widget buildMessageBubble(Map msg) {
    final isInbound = msg['direction'] == 'inbound';

    return Align(
      alignment:
          isInbound ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isInbound ? Colors.grey[300] : Colors.blue,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg['message_body'] ?? '',
              style: TextStyle(
                color: isInbound ? Colors.black : Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              formatTime(msg['created_at']),
              style: TextStyle(
                fontSize: 10,
                color: isInbound ? Colors.black54 : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String getPersonName() {
    if (person == null) return 'Conversation';

    return '${person!['first_name_1st'] ?? ''} ${person!['last_name_1st'] ?? ''}'
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(getPersonName()),
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? const Center(child: Text('No messages yet'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 10),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          return buildMessageBubble(messages[index]);
                        },
                      ),
          ),

          // 🔽 Reply Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                isSending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: sendMessage,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}