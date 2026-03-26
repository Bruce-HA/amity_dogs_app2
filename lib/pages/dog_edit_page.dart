import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  String? status;
  String? desexed;

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

  @override
  void initState() {
    super.initState();

    nameController =
        TextEditingController(text: widget.dog['dog_name']);
    alaController =
        TextEditingController(text: widget.dog['dog_ala']);
    microchipController =
        TextEditingController(text: widget.dog['microchip']);
    dobController =
        TextEditingController(text: widget.dog['dob']);

    spayDueController =
        TextEditingController(text: widget.dog['spay_due'] ?? '');

    status = widget.dog['status'];
    desexed = widget.dog['desexed'] ?? 'Unknown';
  }

  Future<void> save() async {
    await supabase.from('dogs').update({
      'dog_name': nameController.text,
      'dog_ala': alaController.text,
      'microchip': microchipController.text,
      'dob': dobController.text,
      'status': status,
      'desexed': desexed,
      'spay_due': spayDueController.text.isEmpty
          ? null
          : spayDueController.text,
    }).eq('id', widget.dog['id']);

    Navigator.pop(context);
  }

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
      controller.text =
          picked.toIso8601String().split('T').first;
    }
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
                  const InputDecoration(labelText: "Dog Name"),
            ),

            TextField(
              controller: alaController,
              decoration: const InputDecoration(labelText: "ALA"),
            ),

            TextField(
              controller: microchipController,
              decoration:
                  const InputDecoration(labelText: "Microchip"),
            ),

            TextField(
              controller: dobController,
              readOnly: true,
              decoration:
                  const InputDecoration(labelText: "DOB"),
              onTap: () => pickDate(dobController),
            ),

            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              value: status,
              items: statuses
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => status = v),
              decoration:
                  const InputDecoration(labelText: "Status"),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: desexed,
              items: desexedOptions
                  .map((d) => DropdownMenuItem(
                        value: d,
                        child: Text(d),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => desexed = v),
              decoration:
                  const InputDecoration(labelText: "Desexed"),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: spayDueController,
              readOnly: true,
              decoration: const InputDecoration(
                  labelText: "Spay Due Date"),
              onTap: () => pickDate(spayDueController),
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