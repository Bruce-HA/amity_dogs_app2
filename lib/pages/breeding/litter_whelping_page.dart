// Flutter-style pseudo implementation (Dart)
// You can adapt into your existing Flutter project

import 'package:flutter/material.dart';

class CreatePuppiesPage extends StatefulWidget {
  final String litterId;
  final int totalPuppies;
  final int maleCount;
  final int femaleCount;

  const CreatePuppiesPage({
    super.key,
    required this.litterId,
    required this.totalPuppies,
    required this.maleCount,
    required this.femaleCount,
  });

  @override
  State<CreatePuppiesPage> createState() => _CreatePuppiesPageState();
}

class PuppyRow {
  String name = '';
  String sex = 'Male';
  String colour = '';
  String collar = '';
  TimeOfDay? time;
  int? weight;
}

class _CreatePuppiesPageState extends State<CreatePuppiesPage> {
  late List<PuppyRow> puppies;

  @override
  void initState() {
    super.initState();
    puppies = List.generate(widget.totalPuppies, (_) => PuppyRow());
  }

  Future<void> _pickTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        puppies[index].time = picked;
      });
    }
  }

  void _save() {
    // TODO: send to Supabase
    for (var pup in puppies) {
      debugPrint(pup.name);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Puppies created successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Puppies')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: puppies.length,
                itemBuilder: (context, index) {
                  final pup = puppies[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Puppy ${index + 1}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),

                          TextField(
                            decoration:
                                const InputDecoration(labelText: 'Name'),
                            onChanged: (v) => pup.name = v,
                          ),

                          DropdownButtonFormField<String>(
                            value: pup.sex,
                            items: const [
                              DropdownMenuItem(value: 'Male', child: Text('Male')),
                              DropdownMenuItem(value: 'Female', child: Text('Female')),
                            ],
                            onChanged: (v) => pup.sex = v!,
                            decoration:
                                const InputDecoration(labelText: 'Sex'),
                          ),

                          TextField(
                            decoration:
                                const InputDecoration(labelText: 'Colour'),
                            onChanged: (v) => pup.colour = v,
                          ),

                          TextField(
                            decoration: const InputDecoration(
                                labelText: 'Collar Colour'),
                            onChanged: (v) => pup.collar = v,
                          ),

                          Row(
                            children: [
                              Expanded(
                                child: Text(pup.time == null
                                    ? 'No time selected'
                                    : pup.time!.format(context)),
                              ),
                              TextButton(
                                onPressed: () => _pickTime(index),
                                child: const Text('Pick Time'),
                              )
                            ],
                          ),

                          TextField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Weight (g)'),
                            onChanged: (v) => pup.weight = int.tryParse(v),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            ElevatedButton(
              onPressed: _save,
              child: const Text('Create Puppies'),
            )
          ],
        ),
      ),
    );
  }
}
