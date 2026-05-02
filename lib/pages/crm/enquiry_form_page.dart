import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EnquiryFormPage extends StatefulWidget {
  const EnquiryFormPage({super.key});

  @override
  State<EnquiryFormPage> createState() => _EnquiryFormPageState();
}

class _EnquiryFormPageState extends State<EnquiryFormPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool isSaving = false;

  Map<String, dynamic>? selectedPerson;

  final TextEditingController searchController = TextEditingController();
  final TextEditingController enquirySubmittedAtController =
    TextEditingController();

  // Person fields
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  // Website form fields
  final TextEditingController addressController = TextEditingController();
  final TextEditingController sizePreferenceController =
      TextEditingController();
  final TextEditingController sexPreferenceController = TextEditingController();
  final TextEditingController colourPreferenceController =
      TextEditingController();
  final TextEditingController timeframePreferenceController =
      TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController agreementNotesController =
      TextEditingController();

  List<Map<String, dynamic>> searchResults = [];

  String selectedStatus = 'new';
  String interestLevel = 'interested';
  String formSource = 'manual';

  @override
  void dispose() {
    searchController.dispose();

    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();

    addressController.dispose();
    sizePreferenceController.dispose();
    sexPreferenceController.dispose();
    colourPreferenceController.dispose();
    timeframePreferenceController.dispose();
    
    enquirySubmittedAtController.dispose();
    notesController.dispose();
    agreementNotesController.dispose();

    super.dispose();
  }

  Future<void> searchPeople(String value) async {
    final search = value.trim();

    if (search.isEmpty) {
      setState(() => searchResults = []);
      return;
    }

    try {
      final res = await supabase
          .from('people')
          .select()
          .or(
            'first_name_1st.ilike.%$search%,'
            'last_name_1st.ilike.%$search%,'
            'email_1st.ilike.%$search%,'
            'email.ilike.%$search%,'
            'phone_1st.ilike.%$search%,'
            'phone.ilike.%$search%',
          )
          .limit(10);

      setState(() {
        searchResults = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      debugPrint('People search error: $e');
    }
  }

  void selectPerson(Map<String, dynamic> person) {
    setState(() {
      selectedPerson = person;
      searchResults = [];

      searchController.text =
          '${person['first_name_1st'] ?? ''} ${person['last_name_1st'] ?? ''}'
              .trim();

      firstNameController.text = person['first_name_1st'] ?? '';
      lastNameController.text = person['last_name_1st'] ?? '';
      emailController.text = person['email_1st'] ?? person['email'] ?? '';
      phoneController.text = person['phone_1st'] ?? person['phone'] ?? '';

      addressController.text = [
        person['street_address'],
        person['suburb_address'],
        person['state_address'],
        person['postcode_address'],
      ]
          .where((v) => v != null && v.toString().trim().isNotEmpty)
          .join(', ');
    });
  }

  void clearSelectedPerson() {
    setState(() {
      selectedPerson = null;
      searchController.clear();
      searchResults = [];
    });
  }

  Future<String> createPerson() async {
    final first = firstNameController.text.trim();
    final last = lastNameController.text.trim();

    if (first.isEmpty && last.isEmpty) {
      throw 'Please enter a first or last name.';
    }

    final res = await supabase.from('people').insert({
      'first_name_1st': first.isEmpty ? 'Unknown' : first,
      'last_name_1st': last.isEmpty ? 'Buyer' : last,
      'email_1st': emailController.text.trim(),
      'phone_1st': phoneController.text.trim(),
      'street_address': addressController.text.trim(),
      'is_buyer': true,
      'is_prospect': true,
    }).select().single();

    return res['people_id'];
  }

  Future<void> updateExistingPerson(String personId) async {
    await supabase.from('people').update({
      'email_1st': emailController.text.trim(),
      'phone_1st': phoneController.text.trim(),
      'street_address': addressController.text.trim(),
      'is_buyer': true,
      'is_prospect': true,
    }).eq('people_id', personId);
  }
  DateTime? _parseDateTime(String value) {
    if (value.isEmpty) return null;

    try {
      return DateTime.parse(value);
    } catch (_) {
      // fallback: just use now if parsing fails
      return DateTime.now();
    }
  }


  Future<void> saveEnquiry() async {
    if (isSaving) return;

    setState(() => isSaving = true);

    try {
      String? personId = selectedPerson?['people_id'];

      if (personId == null) {
        personId = await createPerson();
      } else {
        await updateExistingPerson(personId);
      }

      final enquiryRes = await supabase.from('inquiries').insert({
          'person_id': personId,
          'status': selectedStatus,
          'interest_level': interestLevel,
          'notes': notesController.text.trim(),
          'size_preference': sizePreferenceController.text.trim(),
          'sex_preference': sexPreferenceController.text.trim(),
          'colour_preference': colourPreferenceController.text.trim(),
          'timeframe_preference': timeframePreferenceController.text.trim(),
          'address_summary': addressController.text.trim(),
          'form_source': formSource,
          'agreement_notes': agreementNotesController.text.trim(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).select().single();

        final enquiryId = enquiryRes['id'];

        if (notesController.text.trim().isNotEmpty) {
          await supabase.from('inquiry_notes').insert({
            'inquiry_id': enquiryId,
            'note_text': notesController.text.trim(),
            'is_pinned': false,
            'created_at': DateTime.now().toIso8601String(),
            'created_by': supabase.auth.currentUser?.id,
          });
        }

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enquiry created')),
      );
    } catch (e) {
      debugPrint('Save enquiry error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save enquiry: $e')),
      );
    }

    if (mounted) {
      setState(() => isSaving = false);
    }
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
    IconData? icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller, {
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildPersonSearch() {
    return _sectionCard(
      title: 'Person',
      icon: Icons.person_search,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: searchController,
            onChanged: searchPeople,
            decoration: const InputDecoration(
              labelText: 'Search existing person',
              hintText: 'Search name, email or phone',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),

          if (searchResults.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...searchResults.map((p) {
              final name =
                  '${p['first_name_1st'] ?? ''} ${p['last_name_1st'] ?? ''}'
                      .trim();
              final contact = (p['email_1st'] ??
                      p['email'] ??
                      p['phone_1st'] ??
                      p['phone'] ??
                      '')
                  .toString();

              return ListTile(
                title: Text(name.isEmpty ? 'Unnamed person' : name),
                subtitle: Text(contact),
                onTap: () => selectPerson(p),
              );
            }),
          ],

          if (selectedPerson != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.withOpacity(.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selected: ${searchController.text}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: clearSelectedPerson,
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          _textField(firstNameController, label: 'First Name'),
          _textField(lastNameController, label: 'Last Name'),
          _textField(
            emailController,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
          ),
          _textField(
            phoneController,
            label: 'Phone',
            keyboardType: TextInputType.phone,
          ),
          _textField(
            addressController,
            label: 'Address',
            hint: 'Street, suburb, state, postcode',
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildPreferences() {
    return _sectionCard(
      title: 'Website Form Preferences',
      icon: Icons.pets,
      child: Column(
        children: [
          _textField(
            sizePreferenceController,
            label: 'Size Preference',
            hint: 'Example: Miniature / Medium 43-52cm',
          ),
          _textField(
            sexPreferenceController,
            label: 'Sex Preference',
            hint: 'Example: Female / Male / Don’t Mind',
          ),
          _textField(
            colourPreferenceController,
            label: 'Coat Colour Preference',
            hint: 'Example: Gold / Caramel / Chocolate',
          ),
          _textField(
            timeframePreferenceController,
            label: 'Time Frame',
            hint: 'Example: No Rush / ASAP / Next litter',
          ),
        ],
      ),
    );
  }

  Widget _buildEnquiryDetails() {
    return _sectionCard(
      title: 'Enquiry Details',
      icon: Icons.assignment,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: selectedStatus,
            decoration: const InputDecoration(
              labelText: 'Stage',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'new', child: Text('New')),
              DropdownMenuItem(value: 'qualified', child: Text('Qualified')),
              DropdownMenuItem(value: 'waiting', child: Text('Waiting')),
              DropdownMenuItem(value: 'deposit_paid', child: Text('Deposit Paid')),
              DropdownMenuItem(value: 'allocated', child: Text('Allocated')),
              DropdownMenuItem(value: 'completed', child: Text('Completed')),
              DropdownMenuItem(value: 'lost', child: Text('Lost')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => selectedStatus = value);
            },
          ),

          const SizedBox(height: 10),

          DropdownButtonFormField<String>(
            value: interestLevel,
            decoration: const InputDecoration(
              labelText: 'Interest Level',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'interested', child: Text('Interested')),
              DropdownMenuItem(value: 'warm', child: Text('Warm')),
              DropdownMenuItem(value: 'hot', child: Text('Hot')),
              DropdownMenuItem(value: 'not_suitable', child: Text('Not Suitable')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => interestLevel = value);
            },
          ),

          const SizedBox(height: 10),

          DropdownButtonFormField<String>(
            value: formSource,
            decoration: const InputDecoration(
              labelText: 'Form Source',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'manual', child: Text('Manual')),
              DropdownMenuItem(value: 'website_long_form', child: Text('Website Long Form')),
              DropdownMenuItem(value: 'website_short_form', child: Text('Website Short Form')),
              DropdownMenuItem(value: 'email', child: Text('Email')),
              DropdownMenuItem(value: 'phone', child: Text('Phone')),
              DropdownMenuItem(value: 'facebook', child: Text('Facebook')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => formSource = value);
            },
          ),

          const SizedBox(height: 10),

          _textField(
            enquirySubmittedAtController,
            label: 'Enquiry Received Date & Time',
            hint: 'Example: 12 Jan 2026 3:42pm',
          ),

          _textField(
            notesController,
            label: 'Comment or Message',
            hint: 'Paste the buyer message here',
            maxLines: 6,
          ),

          _textField(
            agreementNotesController,
            label: 'Agreement Notes',
            hint: 'Example: agreed to desexing, training, allocation, deposit terms',
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Enquiry'),
        actions: [
          TextButton.icon(
            onPressed: isSaving ? null : saveEnquiry,
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text(
              'Save',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _buildPersonSearch(),
              _buildPreferences(),
              _buildEnquiryDetails(),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isSaving ? null : saveEnquiry,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Enquiry'),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),

          if (isSaving)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(.08),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}