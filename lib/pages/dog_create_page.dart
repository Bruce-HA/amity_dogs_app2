import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DogCreatePage extends StatefulWidget {
  const DogCreatePage({super.key});

  @override
  State<DogCreatePage> createState() => _DogCreatePageState();
}

class _DogCreatePageState extends State<DogCreatePage> {
  final supabase = Supabase.instance.client;

  final dogNameController = TextEditingController();
  final alaController = TextEditingController();
  final microchipController = TextEditingController();

  final breederController = TextEditingController();
  final ownerController = TextEditingController();

  List<Map<String, dynamic>> people = [];
  List<Map<String, dynamic>> filteredBreeders = [];
  List<Map<String, dynamic>> filteredOwners = [];

  String? selectedBreederId;
  String? selectedOwnerId;

  bool showBreederList = false;
  bool showOwnerList = false;

  DateTime? dob;
  DateTime? spayDate;

  @override
  void initState() {
    super.initState();
    loadPeople();
  }

  Future<void> loadPeople() async {
    final res = await supabase.from('people').select();
    setState(() {
      people = List<Map<String, dynamic>>.from(res);
    });
  }

  String personLabel(Map<String, dynamic> p) {
    final first = p['first_name_1st'] ?? '';
    final last = p['last_name_1st'] ?? '';
    final business = p['business_name'] ?? '';

    if (business.toString().isNotEmpty) return business;
    return "$first $last";
  }

  void filterPeople(String value, bool isBreeder) {
    final filtered = people.where((p) {
      final name = personLabel(p).toLowerCase();
      return name.contains(value.toLowerCase());
    }).toList();

    setState(() {
      if (isBreeder) {
        filteredBreeders = filtered;
        showBreederList = true;
      } else {
        filteredOwners = filtered;
        showOwnerList = true;
      }
    });
  }

  Future<void> showCreatePersonDialog() async {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Person'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Name or Business'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;

              final res = await supabase.from('people').insert({
                'business_name': name,
              }).select().single();

              setState(() {
                people.add(res);
              });

              Navigator.pop(context);
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  Widget _buildPeopleDropdown({
    required List<Map<String, dynamic>> list,
    required Function(Map<String, dynamic>) onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          ...list.map((p) => ListTile(
                title: Text(personLabel(p)),
                onTap: () => onTap(p),
              )),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add new person'),
            onTap: showCreatePersonDialog,
          ),
        ],
      ),
    );
  }

  Future<void> createDog() async {
    await supabase.from('dogs').insert({
      'dog_name': dogNameController.text,
      'dog_ala': alaController.text,
      'microchip': microchipController.text,
      'breeder_person_id': selectedBreederId,
      'owner_person_id': selectedOwnerId,
      'dob': dob?.toIso8601String(),
      'spay_due': spayDate?.toIso8601String(),
    });

    if (mounted) Navigator.pop(context);
  }

  Widget _input(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _dateField(String label, DateTime? value, Function(DateTime) onPick) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null) onPick(picked);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value == null
                ? label
                : "$label: ${value.toLocal().toString().split(' ')[0]}",
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Dog'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: createDog,
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _input('Dog Name', dogNameController),
          _input('ALA', alaController),
          _input('Microchip', microchipController),

          _dateField('DOB', dob, (d) => setState(() => dob = d)),

          // 🔍 BREEDER
          TextField(
            controller: breederController,
            decoration: InputDecoration(
              labelText: 'Breeder',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (v) => filterPeople(v, true),
          ),

          if (showBreederList)
            _buildPeopleDropdown(
              list: filteredBreeders,
              onTap: (p) {
                setState(() {
                  breederController.text = personLabel(p);
                  selectedBreederId = p['people_id'].toString();
                  showBreederList = false;
                });
              },
            ),

          const SizedBox(height: 16),

          // 🔍 OWNER
          TextField(
            controller: ownerController,
            decoration: InputDecoration(
              labelText: 'Owner',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (v) => filterPeople(v, false),
          ),

          if (showOwnerList)
            _buildPeopleDropdown(
              list: filteredOwners,
              onTap: (p) {
                setState(() {
                  ownerController.text = personLabel(p);
                  selectedOwnerId = p['people_id'].toString();
                  showOwnerList = false;
                });
              },
            ),

          const SizedBox(height: 16),

          _dateField('Spay Due Date', spayDate,
              (d) => setState(() => spayDate = d)),

          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: createDog,
            icon: const Icon(Icons.save),
            label: const Text('Save Dog'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}