import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/app_user.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  List<Map<String, dynamic>> feedback = [];

  @override
  void initState() {
    super.initState();
    loadFeedback();
  }

  Future<void> loadFeedback() async {
    setState(() => loading = true);

    final res = await supabase
        .from('app_feedback')
        .select()
        .eq('is_public', true)
        .order('created_at', ascending: false);

    setState(() {
      feedback = List<Map<String, dynamic>>.from(res);
      loading = false;
    });
  }

  Future<void> addFeedback() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String type = 'suggestion';

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Send Feedback'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'bug', child: Text('Bug')),
                  DropdownMenuItem(value: 'suggestion', child: Text('Suggestion')),
                  DropdownMenuItem(value: 'feature_request', child: Text('Feature Request')),
                  DropdownMenuItem(value: 'question', child: Text('Question')),
                ],
                onChanged: (v) => type = v ?? 'suggestion',
              ),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(labelText: 'Message'),
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await supabase.from('app_feedback').insert({
                'created_by': AppUser.userId,
                'created_by_name': AppUser.name,
                'created_by_email': supabase.auth.currentUser?.email,
                'type': type,
                'title': titleController.text.trim(),
                'message': messageController.text.trim(),
                'status': 'open',
                'priority': 'normal',
                'is_public': true,
              });

              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (saved == true) {
      await loadFeedback();
    }
  }

  Future<void> adminReply(Map<String, dynamic> item) async {
    final replyController = TextEditingController(
      text: item['admin_reply'] ?? '',
    );

    String status = item['status'] ?? 'open';

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Admin Reply'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'open', child: Text('Open')),
                  DropdownMenuItem(value: 'reviewing', child: Text('Reviewing')),
                  DropdownMenuItem(value: 'planned', child: Text('Planned')),
                  DropdownMenuItem(value: 'fixed', child: Text('Fixed')),
                  DropdownMenuItem(value: 'closed', child: Text('Closed')),
                ],
                onChanged: (v) => status = v ?? 'open',
              ),
              TextField(
                controller: replyController,
                decoration: const InputDecoration(labelText: 'Reply'),
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await supabase.from('app_feedback').update({
                'admin_reply': replyController.text.trim(),
                'status': status,
                'replied_at': DateTime.now().toIso8601String(),
                'replied_by': AppUser.userId,
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('id', item['id']);

              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Save Reply'),
          ),
        ],
      ),
    );

    if (saved == true) {
      await loadFeedback();
    }
  }

  Color statusColor(String status) {
    switch (status) {
      case 'planned':
        return Colors.purple.shade100;
      case 'fixed':
        return Colors.green.shade100;
      case 'closed':
        return Colors.grey.shade300;
      case 'reviewing':
        return Colors.orange.shade100;
      default:
        return Colors.blue.shade100;
    }
  }

  Widget feedbackCard(Map<String, dynamic> item) {
    final status = item['status'] ?? 'open';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item['title'] ?? '',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(status),
                  backgroundColor: statusColor(status),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${item['type'] ?? ''} • ${item['created_by_name'] ?? ''}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 10),
            Text(item['message'] ?? ''),
            if ((item['admin_reply'] ?? '').toString().isNotEmpty) ...[
              const Divider(height: 24),
              const Text(
                'Eric / Admin Reply',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(item['admin_reply']),
            ],
            if (AppUser.isAdmin) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => adminReply(item),
                  icon: const Icon(Icons.reply),
                  label: const Text('Reply / Update'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback & Ideas'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addFeedback,
        icon: const Icon(Icons.add_comment),
        label: const Text('New'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : feedback.isEmpty
              ? const Center(child: Text('No feedback yet.'))
              : RefreshIndicator(
                  onRefresh: loadFeedback,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: feedback.length,
                    itemBuilder: (_, index) {
                      return feedbackCard(feedback[index]);
                    },
                  ),
                ),
    );
  }
}