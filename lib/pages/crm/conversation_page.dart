import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ConversationPage extends StatefulWidget {
  final String personId;

  const ConversationPage({
    super.key,
    required this.personId,
  });

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  bool isSending = false;

  List<Map<String, dynamic>> messages = [];
  Map<String, dynamic>? person;
  Map<String, dynamic>? inquiry;

  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchConversation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> fetchConversation() async {
    setState(() => isLoading = true);

    try {
      final personData = await supabase
          .from('people')
          .select()
          .eq('people_id', widget.personId)
          .single();

      final inquiryData = await supabase
          .from('inquiries')
          .select()
          .eq('person_id', widget.personId)
          .order('updated_at', ascending: false)
          .limit(1);

      final msgData = await supabase
          .from('communications')
          .select()
          .eq('people_id', widget.personId)
          .order('created_at', ascending: true);

      setState(() {
        person = Map<String, dynamic>.from(personData);
        messages = List<Map<String, dynamic>>.from(msgData);
        isLoading = false;
        inquiry = inquiryData.isNotEmpty
        ? Map<String, dynamic>.from(inquiryData.first)
        : null;
      });
    } catch (e) {
      debugPrint('Conversation load error: $e');
      setState(() => isLoading = false);
    }
  }

  String mergeTemplate(String text) {
    if (person == null) return text;

    final firstName = (person!['first_name_1st'] ?? '').toString();
    final lastName = (person!['last_name_1st'] ?? '').toString();
    final fullName = '$firstName $lastName'.trim();
    final email = (person!['email_1st'] ?? person!['email'] ?? '').toString();
    final phone = (person!['phone_1st'] ?? person!['phone'] ?? '').toString();

    final enquiryStatus = (inquiry?['status'] ?? '').toString();
    final interestLevel = (inquiry?['interest_level'] ?? '').toString();
    final depositAmount = (inquiry?['deposit_amount'] ?? '').toString();
    final depositReceived =
        inquiry?['deposit_received'] == true ? 'Yes' : 'No';

    final sizePreference = (inquiry?['size_preference'] ?? '').toString();
    final sexPreference = (inquiry?['sex_preference'] ?? '').toString();
    final colourPreference = (inquiry?['colour_preference'] ?? '').toString();
    final timeframePreference =
        (inquiry?['timeframe_preference'] ?? '').toString();

    final notes = (inquiry?['notes'] ?? '').toString();

    return text
        .replaceAll('{{first_name}}', firstName)
        .replaceAll('{{last_name}}', lastName)
        .replaceAll('{{full_name}}', fullName)
        .replaceAll('{{email}}', email)
        .replaceAll('{{phone}}', phone)
        .replaceAll('{{enquiry_status}}', enquiryStatus)
        .replaceAll('{{interest_level}}', interestLevel)
        .replaceAll('{{deposit_amount}}', depositAmount)
        .replaceAll('{{deposit_received}}', depositReceived)
        .replaceAll('{{size_preference}}', sizePreference)
        .replaceAll('{{sex_preference}}', sexPreference)
        .replaceAll('{{colour_preference}}', colourPreference)
        .replaceAll('{{timeframe_preference}}', timeframePreference)
        .replaceAll('{{notes}}', notes);
  }

  Future<void> openTemplatePicker() async {
    try {
      final templates = await supabase
          .from('crm_reply_templates')
          .select()
          .eq('is_active', true)
          .order('category', ascending: true)
          .order('title', ascending: true);

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) {
          if (templates.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No active templates found.'),
            );
          }

          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: ListView.builder(
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];

                final title = (template['title'] ?? '').toString();
                final category = (template['category'] ?? '').toString();
                final subject = (template['subject'] ?? '').toString();
                final photoUrl = (template['photo_url'] ?? '').toString();

                  var mergedBody = mergeTemplate(template['body'] ?? '');

                  if (photoUrl.isNotEmpty) {
                    mergedBody = '$mergedBody\n\nPhoto:\n$photoUrl';
                  }

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ExpansionTile(
                    leading: const Icon(Icons.text_snippet),
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      category.isEmpty ? subject : '$category • $subject',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          mergedBody,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Insert'),
                              onPressed: () {
                                setState(() {
                                  final current = _controller.text.trim();

                                  _controller.text = current.isEmpty
                                      ? mergedBody
                                      : '$current\n\n$mergedBody';

                                  _controller.selection =
                                      TextSelection.fromPosition(
                                    TextPosition(offset: _controller.text.length),
                                  );
                                });

                                Navigator.pop(context);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.swap_horiz),
                              label: const Text('Replace'),
                              onPressed: () {
                                setState(() {
                                  _controller.text = mergedBody;
                                  _controller.selection =
                                      TextSelection.fromPosition(
                                    TextPosition(offset: _controller.text.length),
                                  );
                                });

                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.send),
                          label: const Text('Send Now'),
                          onPressed: () async {
                            Navigator.pop(context);

                            setState(() {
                              _controller.text = mergedBody;
                            });

                            await sendMessage(
                              overrideSubject: subject.isEmpty
                                  ? 'Reply from Amity Labradoodles'
                                  : subject,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('Template picker error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load templates: $e')),
      );
    }
  }

  Future<void> sendMessage({String? overrideSubject}) async {
    final text = _controller.text.trim();
    if (text.isEmpty || person == null) return;

    setState(() => isSending = true);

    try {
      final user = supabase.auth.currentUser;

      await supabase.from('communications').insert({
        'communication_id': const Uuid().v4(),
        'people_id': widget.personId,
        'channel': 'email',
        'direction': 'outbound',
        'subject': overrideSubject ?? 'Reply from Amity Labradoodles',
        'message_body': text,
        'status': 'sent',
        'created_at': DateTime.now().toIso8601String(),
        'created_by': user?.id,
      });

      _controller.clear();
      await fetchConversation();
    } catch (e) {
      debugPrint('Send message error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send message: $e')),
      );
    }

    if (mounted) {
      setState(() => isSending = false);
    }
  }

  String getPersonName() {
    if (person == null) return 'Conversation';

    final first = (person!['first_name_1st'] ?? '').toString();
    final last = (person!['last_name_1st'] ?? '').toString();

    return '$first $last'.trim();
  }

  String formatTime(dynamic value) {
    if (value == null) return '';

    try {
      final date = DateTime.parse(value.toString()).toLocal();
      return DateFormat('dd MMM • h:mm a').format(date);
    } catch (_) {
      return '';
    }
  }

  Widget buildMessageBubble(Map<String, dynamic> msg) {
    final inbound = msg['direction'] == 'inbound';

    return Align(
      alignment: inbound ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: inbound ? Colors.grey.shade200 : Colors.teal,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((msg['subject'] ?? '').toString().isNotEmpty) ...[
              Text(
                msg['subject'],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: inbound ? Colors.black : Colors.white,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              msg['message_body'] ?? '',
              style: TextStyle(
                color: inbound ? Colors.black : Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              formatTime(msg['created_at']),
              style: TextStyle(
                fontSize: 11,
                color: inbound ? Colors.black54 : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildReplyBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Use Template',
            icon: const Icon(Icons.text_snippet),
            onPressed: openTemplatePicker,
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Write a reply...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            onPressed: isSending ? null : sendMessage,
          ),
        ],
      ),
    );
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
                    ? const Center(child: Text('No messages yet.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          return buildMessageBubble(messages[index]);
                        },
                      ),
          ),
          buildReplyBar(),
        ],
      ),
    );
  }
}