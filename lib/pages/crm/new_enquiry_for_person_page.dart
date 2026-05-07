import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'enquiry_detail_page.dart';

class NewEnquiryForPersonPage extends StatefulWidget {
  const NewEnquiryForPersonPage({super.key});

  @override
  State<NewEnquiryForPersonPage> createState() =>
      _NewEnquiryForPersonPageState();
}

class _NewEnquiryForPersonPageState extends State<NewEnquiryForPersonPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController searchController = TextEditingController();

  bool isSearching = false;
  bool isCreating = false;

  List<Map<String, dynamic>> people = [];
  Map<String, dynamic>? selectedPerson;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> searchPeople(String value) async {
    final search = value.trim();

    if (search.isEmpty) {
      setState(() {
        people = [];
        selectedPerson = null;
      });
      return;
    }

    setState(() => isSearching = true);

    try {
      final res = await supabase
          .from('people')
          .select('people_id, first_name_1st, last_name_1st, email_1st, email, phone_1st, phone, business_name')
          .or(
            'first_name_1st.ilike.%$search%,'
            'last_name_1st.ilike.%$search%,'
            'email_1st.ilike.%$search%,'
            'email.ilike.%$search%,'
            'phone_1st.ilike.%$search%,'
            'phone.ilike.%$search%,'
            'business_name.ilike.%$search%',
          )
          .limit(20);

      setState(() {
        people = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      debugPrint('Search people error: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not search people: $e')),
      );
    }

    if (mounted) setState(() => isSearching = false);
  }

  String personName(Map<String, dynamic> person) {
    final first = (person['first_name_1st'] ?? '').toString().trim();
    final last = (person['last_name_1st'] ?? '').toString().trim();
    final name = '$first $last'.trim();

    if (name.isNotEmpty) return name;

    final business = (person['business_name'] ?? '').toString().trim();
    if (business.isNotEmpty) return business;

    return 'Unnamed person';
  }

  String personContact(Map<String, dynamic> person) {
    final email = (person['email_1st'] ?? person['email'] ?? '').toString();
    final phone = (person['phone_1st'] ?? person['phone'] ?? '').toString();

    if (email.isNotEmpty && phone.isNotEmpty) return '$email • $phone';
    if (email.isNotEmpty) return email;
    if (phone.isNotEmpty) return phone;

    return '';
  }

  Future<void> createEnquiry() async {
    final person = selectedPerson;
    if (person == null) return;

    setState(() => isCreating = true);

    try {
      final now = DateTime.now().toIso8601String();

      final res = await supabase
          .from('inquiries')
          .insert({
            'person_id': person['people_id'],
            'status': 'new',
            'interest_level': 'interested',
            'form_source': 'existing_person',
            'imported_from': 'crm_existing_person',
            'enquiry_submitted_at': now,
            'created_at': now,
            'updated_at': now,
          })
          .select('id')
          .single();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EnquiryDetailPage(
            inquiryId: res['id'].toString(),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Create enquiry error: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create enquiry: $e')),
      );
    }

    if (mounted) setState(() => isCreating = false);
  }

  @override
  Widget build(BuildContext context) {
    final selected = selectedPerson;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Enquiry for Person'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          TextField(
            controller: searchController,
            onChanged: searchPeople,
            decoration: const InputDecoration(
              labelText: 'Search existing person',
              hintText: 'Name, email, phone, or business',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),

          if (isSearching)
            const Center(child: CircularProgressIndicator()),

          if (!isSearching && people.isEmpty && searchController.text.isNotEmpty)
            const Text('No matching people found.'),

          ...people.map((person) {
            final isSelected =
                selectedPerson?['people_id'] == person['people_id'];

            return Card(
              child: ListTile(
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.person_outline,
                  color: isSelected ? Colors.green : null,
                ),
                title: Text(personName(person)),
                subtitle: Text(personContact(person)),
                onTap: () {
                  setState(() {
                    selectedPerson = person;
                  });
                },
              ),
            );
          }),

          const SizedBox(height: 18),

          if (selected != null)
            Card(
              color: Colors.teal.withOpacity(.08),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selected Person',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(personName(selected)),
                    if (personContact(selected).isNotEmpty)
                      Text(personContact(selected)),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isCreating ? null : createEnquiry,
                        icon: isCreating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add),
                        label: Text(
                          isCreating
                              ? 'Creating...'
                              : 'Create New Enquiry',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}