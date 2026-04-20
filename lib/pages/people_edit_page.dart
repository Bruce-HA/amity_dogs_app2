import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PeopleEditPage extends StatefulWidget {
  final Map<String, dynamic> person;

  const PeopleEditPage({
    super.key,
    required this.person,
  });

  @override
  State<PeopleEditPage> createState() => _PeopleEditPageState();
}

class _PeopleEditPageState extends State<PeopleEditPage> {
  final supabase = Supabase.instance.client;

  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController businessController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController notesController;
  late TextEditingController streetController;
  late TextEditingController suburbController;
  late TextEditingController postcodeController;
  late TextEditingController stateController;

  late TextEditingController firstName2Controller;
  late TextEditingController lastName2Controller;
  late TextEditingController relationship2Controller;
  late TextEditingController email2Controller;
  late TextEditingController phone2Controller;

  bool isBreeder = false;
  bool isOwner = false;
  bool isGuardian = false;
  bool isProspect = false;
  bool isBuyer = false;
  bool isSupplier = false;

  @override
  void initState() {
    super.initState();

    final p = widget.person;

    firstNameController =
        TextEditingController(text: p['first_name_1st'] ?? '');
    lastNameController =
        TextEditingController(text: p['last_name_1st'] ?? '');
    businessController =
        TextEditingController(text: p['business_name'] ?? '');

    emailController =
        TextEditingController(text: p['email_1st'] ?? '');
    phoneController =
        TextEditingController(text: p['phone_1st'] ?? '');

    streetController =
        TextEditingController(text: p['street_address'] ?? '');
    suburbController =
        TextEditingController(text: p['suburb_address'] ?? '');
    postcodeController =
        TextEditingController(text: p['postcode_address'] ?? '');
    stateController =
        TextEditingController(text: p['state_address'] ?? '');
    firstName2Controller =
        TextEditingController(text: p['first_name_2nd'] ?? '');
    lastName2Controller =
        TextEditingController(text: p['last_name_2nd'] ?? '');
    relationship2Controller =
        TextEditingController(text: p['relationship_2nd'] ?? '');
    email2Controller =
        TextEditingController(text: p['email_2nd'] ?? '');
    phone2Controller =
        TextEditingController(text: p['phone_2nd'] ?? '');
    notesController = 
        TextEditingController(text: p['notes'] ?? '');

    isBreeder = p['is_breeder'] ?? false;
    isOwner = p['is_owner'] ?? false;
    isGuardian = p['is_guardian'] ?? false;
    isProspect = p['is_prospect'] ?? false;
    isBuyer = p['is_buyer'] ?? false;
    isSupplier = p['is_supplier'] ?? false;
  }

  Future<void> save() async {
    final data = {
      'first_name_1st': firstNameController.text,
      'last_name_1st': lastNameController.text,
      'business_name': businessController.text,
      'email_1st': emailController.text,
      'phone_1st': phoneController.text,
      'street_address': streetController.text,
      'suburb_address': suburbController.text,
      'postcode_address': postcodeController.text,
      'state_address': stateController.text,
      'is_breeder': isBreeder,
      'is_owner': isOwner,
      'is_guardian': isGuardian,
      'is_prospect': isProspect,
      'is_buyer': isBuyer,
      'is_supplier': isSupplier,
      'first_name_2nd': firstName2Controller.text,
      'last_name_2nd': lastName2Controller.text,
      'relationship_2nd': relationship2Controller.text,
      'email_2nd': email2Controller.text,
      'phone_2nd': phone2Controller.text,
      'notes': notesController.text,
    };

    try {
      final id = widget.person['people_id'];

      if (id == null || id.toString().isEmpty) {
        // 🆕 INSERT
        await supabase.from('people').insert(data);
      } else {
        // ✏️ UPDATE
        await supabase
            .from('people')
            .update(data)
            .eq('people_id', id);
      }

      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Save error: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving person: $e')),
        );
      }
    }
  }

  Widget buildSwitch(String label, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(label),
      value: value,
      onChanged: (v) => setState(() => onChanged(v)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Person'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: save,
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 🔥 BUSINESS + NAME
          TextField(
            controller: businessController,
            decoration: const InputDecoration(labelText: 'Business Name'),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: firstNameController,
            decoration: const InputDecoration(labelText: 'First Name'),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: lastNameController,
            decoration: const InputDecoration(labelText: 'Last Name'),
          ),

          const SizedBox(height: 20),

          // 🔥 CONTACT
          TextField(
            controller: emailController,
            decoration: const InputDecoration(labelText: 'Email'),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: phoneController,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          const SizedBox(height: 24),

    // 🔥 SECOND CONTACT CARD
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Second Contact',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          TextField(
            controller: firstName2Controller,
            decoration: const InputDecoration(labelText: 'First Name'),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: lastName2Controller,
            decoration: const InputDecoration(labelText: 'Last Name'),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: relationship2Controller,
            decoration: const InputDecoration(labelText: 'Relationship'),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: email2Controller,
            decoration: const InputDecoration(labelText: 'Email'),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: phone2Controller,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
        ],
      ),
    ), 
          const SizedBox(height: 12),

    

          const SizedBox(height: 20),

          // 🔥 ADDRESS
          TextField(
            controller: streetController,
            decoration: const InputDecoration(labelText: 'Street'),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: suburbController,
            decoration: const InputDecoration(labelText: 'Suburb'),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: postcodeController,
            decoration: const InputDecoration(labelText: 'Postcode'),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: stateController,
            decoration: const InputDecoration(labelText: 'State'),
          ),

          const SizedBox(height: 20),

          // 🔥 ROLES
          const Text('Roles',
              style: TextStyle(fontWeight: FontWeight.bold)),

          buildSwitch('Breeder', isBreeder, (v) => isBreeder = v),
          buildSwitch('Owner', isOwner, (v) => isOwner = v),
          buildSwitch('Guardian', isGuardian, (v) => isGuardian = v),
          buildSwitch('Prospect', isProspect, (v) => isProspect = v),
          buildSwitch('Buyer', isBuyer, (v) => isBuyer = v),
          buildSwitch('Supplier', isSupplier, (v) => isSupplier = v),

          const SizedBox(height: 30),
///
          const SizedBox(height: 20),

            TextField(
              controller: notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
///


          ElevatedButton.icon(
            onPressed: save,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }
}