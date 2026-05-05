import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TemplatePickerResult {
  final String subject;
  final String body;

  const TemplatePickerResult({
    required this.subject,
    required this.body,
  });
}

class TemplatePickerPage extends StatefulWidget {
  final Map<String, dynamic>? person;
  final Map<String, dynamic>? inquiry;

  const TemplatePickerPage({
    super.key,
    required this.person,
    required this.inquiry,
  });

  @override
  State<TemplatePickerPage> createState() => _TemplatePickerPageState();
}

class _TemplatePickerPageState extends State<TemplatePickerPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool loading = true;

  List<Map<String, dynamic>> templates = [];
  String selectedCategory = 'All';
  Map<String, dynamic>? selectedTemplate;

  @override
  void initState() {
    super.initState();
    fetchTemplates();
  }

  Future<void> fetchTemplates() async {
    setState(() => loading = true);

    try {
      final data = await supabase
          .from('crm_reply_templates')
          .select()
          .eq('is_active', true)
          .order('category', ascending: true)
          .order('title', ascending: true);

      setState(() {
        templates = List<Map<String, dynamic>>.from(data);
        if (templates.isNotEmpty) {
          selectedTemplate = templates.first;
        }
        loading = false;
      });
    } catch (e) {
      debugPrint('Template picker load error: $e');

      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load templates: $e')),
      );
    }
  }

  List<String> get categories {
    final values = templates
        .map((t) => (t['category'] ?? '').toString().trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();

    values.sort();

    return ['All', ...values];
  }

  List<Map<String, dynamic>> get filteredTemplates {
    if (selectedCategory == 'All') return templates;

    return templates.where((template) {
      return (template['category'] ?? '').toString().trim() == selectedCategory;
    }).toList();
  }

  String mergeTemplate(String text) {
    final person = widget.person;
    final inquiry = widget.inquiry;

    final firstName = (person?['first_name_1st'] ?? '').toString();
    final lastName = (person?['last_name_1st'] ?? '').toString();
    final fullName = '$firstName $lastName'.trim();
    final email = (person?['email_1st'] ?? person?['email'] ?? '').toString();
    final phone = (person?['phone_1st'] ?? person?['phone'] ?? '').toString();

    final enquiryStatus = (inquiry?['status'] ?? '').toString();
    final interestLevel = (inquiry?['interest_level'] ?? '').toString();
    final depositAmount = (inquiry?['deposit_amount'] ?? '').toString();
    final depositReceived = inquiry?['deposit_received'] == true ? 'Yes' : 'No';

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

  TemplatePickerResult _buildResult(Map<String, dynamic> template) {
    final subject = mergeTemplate(
      (template['subject'] ?? 'Reply from Amity Labradoodles').toString(),
    );

    var body = mergeTemplate((template['body'] ?? '').toString());

    final photoUrl = (template['photo_url'] ?? '').toString().trim();
    if (photoUrl.isNotEmpty) {
      body = '$body\n\nPhoto:\n$photoUrl';
    }

    return TemplatePickerResult(
      subject: subject,
      body: body,
    );
  }

  void _returnTemplate({required bool replace}) {
    final template = selectedTemplate;
    if (template == null) return;

    final result = _buildResult(template);

    Navigator.pop(context, {
      'replace': replace,
      'subject': result.subject,
      'body': result.body,
    });
  }

  Widget _buildCategoryBar() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = selectedCategory == category;

          return ChoiceChip(
            label: Text(category),
            selected: selected,
            onSelected: (_) {
              setState(() {
                selectedCategory = category;
                selectedTemplate = filteredTemplates.isNotEmpty
                    ? filteredTemplates.first
                    : null;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildTemplateList() {
    final list = filteredTemplates;

    if (list.isEmpty) {
      return const Center(
        child: Text('No templates in this category.'),
      );
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final template = list[index];
        final selected = template['id'] == selectedTemplate?['id'];

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          color: selected ? Colors.teal.withOpacity(.10) : null,
          child: ListTile(
            leading: Icon(
              selected ? Icons.check_circle : Icons.text_snippet,
              color: selected ? Colors.teal : Colors.grey,
            ),
            title: Text(
              (template['title'] ?? '').toString(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              [
                (template['category'] ?? '').toString(),
                (template['subject'] ?? '').toString(),
              ].where((v) => v.trim().isNotEmpty).join(' • '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              setState(() => selectedTemplate = template);
            },
          ),
        );
      },
    );
  }

  Widget _buildPreview() {
    final template = selectedTemplate;

    if (template == null) {
      return const Center(
        child: Text('Select a template to preview.'),
      );
    }

    final result = _buildResult(template);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preview',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          if (result.subject.trim().isNotEmpty) ...[
            Text(
              result.subject,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                result.body,
                style: const TextStyle(fontSize: 14, height: 1.35),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Insert'),
                  onPressed: () => _returnTemplate(replace: false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Replace'),
                  onPressed: () => _returnTemplate(replace: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Reply Template'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: fetchTemplates,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : templates.isEmpty
              ? const Center(child: Text('No active reply templates found.'))
              : Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildCategoryBar(),
                    const Divider(height: 1),
                    Expanded(
                      child: isWide
                          ? Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: _buildTemplateList(),
                                ),
                                Expanded(
                                  flex: 5,
                                  child: _buildPreview(),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildTemplateList(),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: _buildPreview(),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
    );
  }
}