import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/person_picker.dart';
import 'widgets/dog_ala_picker.dart';

class DogEditPage extends StatefulWidget {
  final Map<String, dynamic> dog;

  const DogEditPage({super.key, required this.dog});

  @override
  State<DogEditPage> createState() => _DogEditPageState();
}

class _DogEditPageState extends State<DogEditPage> {
  final supabase = Supabase.instance.client;

  late TextEditingController nameController;
  late TextEditingController alaController;
  late TextEditingController microchipController;
  late TextEditingController dobController;
  late TextEditingController spayDueController;
  late TextEditingController pedigreeController;
  late TextEditingController coatController;
  late TextEditingController sizeController;
  late TextEditingController colourController;
  late TextEditingController ecgController;

  String? status;
  String? desexed;
  Map<String, dynamic>? breeder;
  Map<String, dynamic>? owner;
  Map<String, dynamic>? dam;
  Map<String, dynamic>? sire;

  final List<String> statuses = [
    'Pending',
    'Pet',
    'Active',
    'Breeding',
    'Guardian',
    'Retired',
    'Deceased',
    'Forsale',
    'Unknown',
  ];

  final List<String> desexedOptions = [
    'Yes',
    'No',
    'Pending',
    'Unknown',
  ];

  @override
  void initState() {
    super.initState();

    nameController =
        TextEditingController(text: widget.dog['dog_name']?.toString() ?? '');
    alaController =
        TextEditingController(text: widget.dog['dog_ala']?.toString() ?? '');
    microchipController =
        TextEditingController(text: widget.dog['microchip']?.toString() ?? '');
    dobController =
    TextEditingController(text: widget.dog['dob']?.toString() ?? '');

    spayDueController =
        TextEditingController(text: widget.dog['spay_due']?.toString() ?? '');
    pedigreeController =
        TextEditingController(text: widget.dog['pedigree_number']?.toString() ?? '');

    coatController =
        TextEditingController(text: widget.dog['coat']?.toString() ?? '');

    sizeController =
        TextEditingController(text: widget.dog['size']?.toString() ?? '');

    colourController =
        TextEditingController(text: widget.dog['colour']?.toString() ?? '');

    ecgController =
        TextEditingController(text: widget.dog['ecg']?.toString() ?? '');

    status = widget.dog['status'];
    desexed = widget.dog['desexed'] ?? 'Unknown';

    // 🔥 LOAD RELATIONS
    loadRelations();
  }

  Future<void> save() async {
    print('SAVING SPAY DUE: ${spayDueController.text}');
    await supabase.from('dogs').update({
      'mother_id': dam != null ? dam!['id'] : null,
      'father_id': sire != null ? sire!['id'] : null,
      'dog_name': nameController.text,
      'dog_ala': alaController.text,
      'microchip': microchipController.text,
      'dob': dobController.text,
      'status': status,
      'desexed': desexed,
      'spay_due':
          spayDueController.text.isEmpty ? null : spayDueController.text,
      'breeder_person_id':
          breeder != null ? breeder!['people_id'] : null,
      'owner_person_id':
          owner != null ? owner!['people_id'] : null,
      'coat': coatController.text,
      'size': sizeController.text,
      'colour': colourController.text,
      'ecg': ecgController.text,
    }).eq('id', widget.dog['id']);

    if (!mounted) return;

    // ✅ SHOW CONFIRMATION HERE
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dog saved')),
    );

    // small delay so user actually sees it
    await Future.delayed(const Duration(milliseconds: 300));

    Navigator.of(context).pop(true);
  }
//
  Future<void> loadRelations() async {
    final dog = widget.dog;

    // 🐶 Load parents
    if (dog['mother_id'] != null) {
      dam = await supabase
          .from('dogs')
          .select('id, dog_name, dog_ala')
          .eq('id', dog['mother_id'])
          .maybeSingle();
    }

    if (dog['father_id'] != null) {
      sire = await supabase
          .from('dogs')
          .select('id, dog_name, dog_ala')
          .eq('id', dog['father_id'])
          .maybeSingle();
    }

    // 👤 Load breeder
    if (dog['breeder_person_id'] != null) {
      breeder = await supabase
          .from('people')
          .select()
          .eq('people_id', dog['breeder_person_id'])
          .maybeSingle();
    }

    // 👤 Load owner
    if (dog['owner_person_id'] != null) {
      owner = await supabase
          .from('people')
          .select()
          .eq('people_id', dog['owner_person_id'])
          .maybeSingle();
    }

    setState(() {});
  }
///
  Future<void> pickDate(TextEditingController controller) async {
    DateTime initialDate = DateTime.now();

    if (controller.text.isNotEmpty) {
      try {
        initialDate = DateTime.parse(controller.text);
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

      if (picked != null) {
    setState(() {
      controller.text = picked.toIso8601String().split('T').first;
    });
  }
  }

  InputDecoration _dec(String label, String? hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint ?? '',
      border: const OutlineInputBorder(),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    alaController.dispose();
    microchipController.dispose();
    dobController.dispose();
    spayDueController.dispose();

    pedigreeController.dispose();
    coatController.dispose();
    sizeController.dispose();
    colourController.dispose();
    ecgController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Dog"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: save,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: nameController,
              decoration:
                  _dec("Dog Name", widget.dog['dog_name']),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: alaController,
              decoration:
                  _dec("ALA", widget.dog['dog_ala']),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: microchipController,
              decoration:
                  _dec("Microchip", widget.dog['microchip']),
            ),

            const SizedBox(height: 20),

            Text("🧬 Genetics", style: TextStyle(fontWeight: FontWeight.w600)),

            const SizedBox(height: 10),

            TextField(
              controller: coatController,
              decoration: _dec("Coat", null),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: sizeController,
              decoration: _dec("Size", null),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: colourController,
              decoration: _dec("Colour", null),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: ecgController,
              decoration: _dec("ECG", null),
            ),

                        const SizedBox(height: 12),

            TextField(
              controller: dobController,
              readOnly: true,
              decoration: _dec("DOB", widget.dog['dob']),
              onTap: () => pickDate(dobController),
            ),

            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              value: statuses.contains(status) ? status : null,  
              items: statuses
                  .map((s) =>
                      DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => status = v),
              decoration: const InputDecoration(
                labelText: "Status",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: desexed,
              items: desexedOptions
                  .map((d) =>
                      DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) => setState(() => desexed = v),
              decoration: const InputDecoration(
                labelText: "Desexed",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: spayDueController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: "Spay Due Date",
                border: const OutlineInputBorder(),

                // 👇 ADD CLEAR BUTTON
                suffixIcon: spayDueController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: "Clear date",
                        onPressed: () {
                          setState(() {
                            spayDueController.clear(); // 👈 THIS makes it NULL on save
                          });
                        },
                      )
                    : null,
              ),
              onTap: () => pickDate(spayDueController),
            ),

            const SizedBox(height: 16),

            DogAlaPicker(
              label: 'Mother (Dam)',
              selectedDog: dam,
              onSelected: (dog) {
                setState(() => dam = dog);
              },
            ),

            const SizedBox(height: 12),

            DogAlaPicker(
              label: 'Father (Sire)',
              selectedDog: sire,
              onSelected: (dog) {
                setState(() => sire = dog);
              },
            ),

            const SizedBox(height: 16),

            PersonPicker(
              label: 'Breeder',
              useBusinessName: true,
              selectedPerson: breeder,
              onSelected: (person) {
                setState(() => breeder = person);
              },
            ),

            const SizedBox(height: 12),

            PersonPicker(
              label: 'Owner',
              selectedPerson: owner,
              onSelected: (person) {
                setState(() => owner = person);
              },
            ),

            const SizedBox(height: 30),

            ElevatedButton.icon(
              onPressed: save,
              icon: const Icon(Icons.save),
              label: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}