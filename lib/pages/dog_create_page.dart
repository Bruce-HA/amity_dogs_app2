import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DogCreatePage extends StatefulWidget {
  const DogCreatePage({super.key});

  @override
  State<DogCreatePage> createState() => _DogCreatePageState();
}

class _DogCreatePageState extends State<DogCreatePage> {
  final supabase = Supabase.instance.client;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController alaController = TextEditingController();
  final TextEditingController microchipController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController spayDueController = TextEditingController();

  String status = 'Unknown';
  String desexed = 'Unknown';

  List<Map<String, dynamic>> people = [];

  String? selectedBreederId;
  String? selectedOwnerId;

  final List<String> statuses = [
    'pending',
    'Pet',
    'Active',
    'Guardian',
    'Retired',
    'Deceased',
    'Forsale',
    'Sold',
    'Unknown',
  ];

  final List<String> desexedOptions = [
    'Yes',
    'No',
    'Pending',
    'Unknown',
  ];

  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    loadPeople();
  }

  Future<void> loadPeople() async {
    final res = await supabase
        .from('people')
        .select('people_id, first_name_1st, last_name_1st, business_name')
        .order('last_name_1st');

    setState(() {
      people = List<Map<String, dynamic>>.from(res);
    });
  }

  String personLabel(Map<String, dynamic> p) {
    final business = p['business_name'];
    if (business != null && business.toString().isNotEmpty) {
      return business;
    }
    return "${p['first_name_1st'] ?? ''} ${p['last_name_1st'] ?? ''}";
  }

  Future<void> pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      controller.text =
          picked.toIso8601String().split('T').first;
    }
  }

  Future<void> createDog() async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dog name is required')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      await supabase.from('dogs').insert({
        'dog_name': nameController.text.trim(),
        'dog_ala': alaController.text.trim(),
        'microchip': microchipController.text.trim(),
        'dob': dobController.text.trim().isEmpty
            ? null
            : dobController.text.trim(),
        'status': status,
        'desexed': desexed,
        'spay_due': spayDueController.text.isEmpty
            ? null
            : spayDueController.text,
        'breeder_person_id': selectedBreederId == null
            ? null
            : int.parse(selectedBreederId!),

        'owner_person_id': selectedOwnerId == null
            ? null
            : int.parse(selectedOwnerId!),
      });

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating dog: $e')),
      );
    }

    setState(() => isSaving = false);
  }

  @override
  void dispose() {
    nameController.dispose();
    alaController.dispose();
    microchipController.dispose();
    dobController.dispose();
    spayDueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Dog'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: isSaving ? null : createDog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Dog Name'),
            ),

            TextField(
              controller: alaController,
              decoration: const InputDecoration(labelText: 'ALA'),
            ),

            TextField(
              controller: microchipController,
              decoration: const InputDecoration(labelText: 'Microchip'),
            ),

            TextField(
              controller: dobController,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'DOB'),
              onTap: () => pickDate(dobController),
            ),

            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              value: status,
              items: statuses
                  .map((s) =>
                      DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => status = v!),
              decoration: const InputDecoration(labelText: 'Status'),
            ),

            DropdownButtonFormField<String>(
              value: desexed,
              items: desexedOptions
                  .map((d) =>
                      DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) => setState(() => desexed = v!),
              decoration: const InputDecoration(labelText: 'Desexed'),
            ),

            TextField(
              controller: spayDueController,
              readOnly: true,
              decoration:
                  const InputDecoration(labelText: 'Spay Due Date'),
              onTap: () => pickDate(spayDueController),
            ),

            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              value: selectedBreederId,
              hint: const Text("Select Breeder"),
              items: people
                  .map((p) => DropdownMenuItem(
                        value: p['people_id'].toString(),
                        child: Text(personLabel(p)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => selectedBreederId = v),
            ),

            DropdownButtonFormField<String>(
              value: selectedOwnerId,
              hint: const Text("Select Owner"),
              items: people
                  .map((p) => DropdownMenuItem(
                        value: p['people_id'].toString(),
                        child: Text(personLabel(p)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => selectedOwnerId = v),
            ),

            const SizedBox(height: 30),

            ElevatedButton.icon(
              onPressed: isSaving ? null : createDog,
              icon: const Icon(Icons.save),
              label: const Text('Save Dog'),
            ),
          ],
        ),
      ),
    );
  }
}