import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EnquiryFormPage extends StatefulWidget {
  const EnquiryFormPage({super.key});

  @override
  State<EnquiryFormPage> createState() => _EnquiryFormPageState();
}

class _EnquiryFormPageState extends State<EnquiryFormPage> {
  final supabase = Supabase.instance.client;

  bool isSaving = false;

  Map<String, dynamic>? selectedPerson;

  final TextEditingController searchController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  final TextEditingController notesController = TextEditingController();

  List<Map<String, dynamic>> searchResults = [];

  String selectedStatus = 'new';
  String interestLevel = 'interested';

  // -------------------------
  // SEARCH PEOPLE
  // -------------------------

  Future<void> searchPeople(String value) async {
    if (value.isEmpty) {
      setState(() => searchResults = []);
      return;
    }

    final res = await supabase
        .from('people')
        .select()
        .or(
          'first_name_1st.ilike.%$value%,last_name_1st.ilike.%$value%,email_1st.ilike.%$value%,phone_1st.ilike.%$value%',
        )
        .limit(10);

    setState(() {
      searchResults = List<Map<String, dynamic>>.from(res);
    });
  }

  // -------------------------
  // CREATE PERSON
  // -------------------------

  Future<String> createPerson() async {
    final res = await supabase.from('people').insert({
      'first_name_1st': firstNameController.text.trim(),
      'last_name_1st': lastNameController.text.trim(),
      'email_1st': emailController.text.trim(),
      'phone_1st': phoneController.text.trim(),
      'is_buyer': true,
      'is_prospect': true,
    }).select().single();

    return res['people_id'];
  }

  // -------------------------
  // SAVE ENQUIRY
  // -------------------------

  Future<void> saveEnquiry() async {
    if (isSaving) return;

    setState(() => isSaving = true);

    try {
      String? personId = selectedPerson?['people_id'];

      if (personId == null) {
        if (firstNameController.text.isEmpty) {
          throw 'Please select or create a person';
        }

        personId = await createPerson();
      }

      await supabase.from('inquiries').insert({
        'person_id': personId,
        'status': selectedStatus,
        'interest_level': interestLevel,
        'notes': notesController.text.trim(),
      });

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enquiry created')),
      );
    } catch (e) {
      debugPrint('Save enquiry error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }

    if (mounted) {
      setState(() => isSaving = false);
    }
  }

  // -------------------------
  // UI
  // -------------------------

  Widget buildSearchResults() {
    return Column(
      children: searchResults.map((p) {
        return ListTile(
          title: Text(
              '${p['first_name_1st'] ?? ''} ${p['last_name_1st'] ?? ''}'),
          subtitle: Text(p['email_1st'] ?? ''),
          onTap: () {
            setState(() {
              selectedPerson = p;
              searchResults = [];
              searchController.text =
                  '${p['first_name_1st']} ${p['last_name_1st']}';
            });
          },
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Enquiry'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // SEARCH
            const Text('Find Person'),
            TextField(
              controller: searchController,
              onChanged: searchPeople,
              decoration: const InputDecoration(
                hintText: 'Search name, email, phone',
              ),
            ),

            buildSearchResults(),

            const SizedBox(height: 10),

            // CREATE PERSON
            if (selectedPerson == null) ...[
              const Text('Or Create New'),

              TextField(
                controller: firstNameController,
                decoration: const InputDecoration(labelText: 'First Name'),
              ),
              TextField(
                controller: lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
            ],

            const SizedBox(height: 20),

            // STATUS
            DropdownButtonFormField(
              value: selectedStatus,
              items: const [
                DropdownMenuItem(value: 'new', child: Text('New')),
                DropdownMenuItem(value: 'qualified', child: Text('Qualified')),
                DropdownMenuItem(value: 'waiting', child: Text('Waiting')),
              ],
              onChanged: (v) => setState(() => selectedStatus = v.toString()),
              decoration: const InputDecoration(labelText: 'Stage'),
            ),

            const SizedBox(height: 10),

            // NOTES
            TextField(
              controller: notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes',
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: isSaving ? null : saveEnquiry,
              child: const Text('Save Enquiry'),
            ),
          ],
        ),
      ),
    );
  }
}