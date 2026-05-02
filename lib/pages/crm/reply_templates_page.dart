import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReplyTemplatesPage extends StatefulWidget {
  const ReplyTemplatesPage({super.key});

  @override
  State<ReplyTemplatesPage> createState() => _ReplyTemplatesPageState();
}

class _ReplyTemplatesPageState extends State<ReplyTemplatesPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool isLoading = true;
  List<Map<String, dynamic>> templates = [];

  @override
  void initState() {
    super.initState();
    fetchTemplates();
  }

  Future<void> fetchTemplates() async {
    setState(() => isLoading = true);

    try {
      final res = await supabase
          .from('crm_reply_templates')
          .select()
          .order('category', ascending: true)
          .order('title', ascending: true);

      setState(() {
        templates = List<Map<String, dynamic>>.from(res);
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Template load error: $e');
      setState(() => isLoading = false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load templates: $e')),
      );
    }
  }

  Future<void> saveTemplate({
    String? id,
    required String title,
    required String category,
    required String subject,
    required String body,
    required bool isActive,
  }) async {
    try {
      final payload = {
        'title': title.trim(),
        'category': category.trim(),
        'subject': subject.trim(),
        'body': body.trim(),
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (id == null) {
        await supabase.from('crm_reply_templates').insert(payload);
      } else {
        await supabase
            .from('crm_reply_templates')
            .update(payload)
            .eq('id', id);
      }

      await fetchTemplates();
    } catch (e) {
      debugPrint('Template save error: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save template: $e')),
      );
    }
  }

  Future<void> deleteTemplate(String id) async {
    try {
      await supabase.from('crm_reply_templates').delete().eq('id', id);
      await fetchTemplates();
    } catch (e) {
      debugPrint('Template delete error: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete template: $e')),
      );
    }
  }

  void openTemplateForm({Map<String, dynamic>? template}) {
    final titleController =
        TextEditingController(text: template?['title'] ?? '');
    final categoryController =
        TextEditingController(text: template?['category'] ?? '');
    final subjectController =
        TextEditingController(text: template?['subject'] ?? '');
    final bodyController =
        TextEditingController(text: template?['body'] ?? '');

    bool isActive = template?['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(template == null ? 'New Template' : 'Edit Template'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          hintText: 'New enquiry reply',
                        ),
                      ),
                      TextField(
                        controller: categoryController,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          hintText: 'ENQUIRY',
                        ),
                      ),
                      TextField(
                        controller: subjectController,
                        decoration: const InputDecoration(
                          labelText: 'Email Subject',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: bodyController,
                        minLines: 8,
                        maxLines: 16,
                        decoration: const InputDecoration(
                          labelText: 'Reply Body',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                          helperText:
                              'Merge fields: {{first_name}}, {{last_name}}, {{full_name}}, {{email}}, {{phone}}',
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        value: isActive,
                        onChanged: (value) {
                          setModalState(() => isActive = value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty ||
                        bodyController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Title and body are required.'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(context);

                    await saveTemplate(
                      id: template?['id'],
                      title: titleController.text,
                      category: categoryController.text,
                      subject: subjectController.text,
                      body: bodyController.text,
                      isActive: isActive,
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _templateTile(Map<String, dynamic> template) {
    final active = template['is_active'] == true;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Icon(
          active ? Icons.text_snippet : Icons.visibility_off,
          color: active ? Colors.teal : Colors.grey,
        ),
        title: Text(
          template['title'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((template['category'] ?? '').toString().isNotEmpty)
              Text('Category: ${template['category']}'),
            if ((template['subject'] ?? '').toString().isNotEmpty)
              Text('Subject: ${template['subject']}'),
            const SizedBox(height: 4),
            Text(
              template['body'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              openTemplateForm(template: template);
            }

            if (value == 'delete') {
              deleteTemplate(template['id']);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'edit',
              child: Text('Edit'),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
        ),
        onTap: () => openTemplateForm(template: template),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount =
        templates.where((t) => t['is_active'] == true).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reply Templates'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: fetchTemplates,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openTemplateForm(),
        icon: const Icon(Icons.add),
        label: const Text('Template'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : templates.isEmpty
              ? const Center(
                  child: Text('No reply templates yet.'),
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(.10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.teal.withOpacity(.25)),
                      ),
                      child: Text(
                        '$activeCount active templates • ${templates.length} total',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: fetchTemplates,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 90),
                          itemCount: templates.length,
                          itemBuilder: (context, index) {
                            return _templateTile(templates[index]);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}