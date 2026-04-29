import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PuppyCreatePage extends StatefulWidget {
  final Map<String, dynamic> litter;

  const PuppyCreatePage({
    super.key,
    required this.litter,
  });

  @override
  State<PuppyCreatePage> createState() => _PuppyCreatePageState();
}

class _PuppyCreatePageState extends State<PuppyCreatePage> {
  final supabase = Supabase.instance.client;

  final colourController = TextEditingController();
  final collarController = TextEditingController();
  final birthTimeController = TextEditingController();
  final birthWeightController = TextEditingController();
  final puppyNameController = TextEditingController();

  String? sex;
  String? size = 'Medium';
  String? coatType = 'Fleece';

  bool saving = false;

  final sexOptions = ['Male', 'Female'];
  final sizeOptions = ['Miniature', 'Medium', 'Standard'];
  final coatOptions = ['Fleece', 'Wool', 'Hair'];

  String dateOnly(DateTime d) => d.toIso8601String().split('T').first;

  Future<int> nextPuppyNumber() async {
    final pups = await supabase
        .from('dogs')
        .select('id')
        .eq('litter_id', widget.litter['id']);

    return (pups as List).length + 1;
  }

  Future<void> savePuppy() async {
    if (sex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select sex')),
      );
      return;
    }

    final alaLitter =
        widget.litter['ala_litter_number']?.toString().trim() ?? '';

    if (alaLitter.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ALA litter number missing')),
      );
      return;
    }

    setState(() => saving = true);

    final pupNumber = await nextPuppyNumber();
    final dogAla = '$alaLitter-${pupNumber.toString().padLeft(2, '0')}';

    final dobRaw = widget.litter['whelp_date'];
    final dob = dobRaw?.toString() ?? dateOnly(DateTime.now());

    final spayDue = DateTime.parse(dob)
        .add(const Duration(days: 335))
        .toIso8601String()
        .split('T')
        .first;

    await supabase.from('dogs').insert({
      'dog_name': puppyNameController.text.trim().isEmpty
      ? dogAla
      : puppyNameController.text.trim(),
      'pet_name': collarController.text.trim(),
      'dog_ala': dogAla,
      'litter_id': widget.litter['id'],
      'litter_name': widget.litter['short_litter_name'] ??
          widget.litter['litter_name'],
      'dob': dob,
      'sex': sex,
      'colour': colourController.text.trim(),
      'collar_colour': collarController.text.trim(),
      'size': size,
      'coat_type': coatType,
      'birth_time': birthTimeController.text.trim(),
      'birth_weight': int.tryParse(birthWeightController.text.trim()),

      'desexed': 'Pending',
      'spay_status': 'Pending',
      'spay_due': spayDue,
      'mother_id': widget.litter['dam_id'],
      'mother_ala': widget.litter['dam_ala'],
      'father_id': widget.litter['sire_id'],
      'father_ala': widget.litter['sire_ala'],
      'sale_status': 'For Sale',
      'sale_price': 3850.00,
      'breeding_stock': false,
      'breed': 'Australian Labradoodle',
      'my_dogs': true,
      'breeding_eligible': false,
      'is_ghost': false,
      'has_dna_summary': false,
      'status': 'Pending',
    });

    await updateLitterCounts();

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> updateLitterCounts() async {
    final pups = await supabase
        .from('dogs')
        .select('id, sex')
        .eq('litter_id', widget.litter['id']);

    final list = List<Map<String, dynamic>>.from(pups as List);

    final maleCount = list.where((p) => p['sex'] == 'Male').length;
    final femaleCount = list.where((p) => p['sex'] == 'Female').length;
    final total = list.length;

    await supabase.from('litters').update({
      'total_puppies': total,
      'male_count': maleCount,
      'female_count': femaleCount,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', widget.litter['id']);

    for (final pup in list) {
      final isMale = pup['sex'] == 'Male';

      await supabase.from('dogs').update({
        'brother_count': isMale ? maleCount - 1 : maleCount,
        'sister_count': isMale ? femaleCount : femaleCount - 1,
        'litter_count': total,
      }).eq('id', pup['id']);
    }
  }

  Widget _input(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alaLitter = widget.litter['ala_litter_number'] ?? 'ALA missing';

    return Scaffold(
      appBar: AppBar(
        title: Text('Add Puppy $alaLitter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: saving ? null : savePuppy,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: sex,
            decoration: const InputDecoration(
              labelText: 'Sex',
              border: OutlineInputBorder(),
            ),
            items: sexOptions
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) => setState(() => sex = v),
          ),
          const SizedBox(height: 14),

          _input('Puppy Name', puppyNameController),
          _input('Collar Colour', collarController),
          _input('Colour', colourController),
          _input('Birth Time', birthTimeController),
          _input('Birth Weight (g)', birthWeightController),

          DropdownButtonFormField<String>(
            value: size,
            decoration: const InputDecoration(
              labelText: 'Size',
              border: OutlineInputBorder(),
            ),
            items: sizeOptions
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) => setState(() => size = v),
          ),
          const SizedBox(height: 14),

          DropdownButtonFormField<String>(
            value: coatType,
            decoration: const InputDecoration(
              labelText: 'Coat Type',
              border: OutlineInputBorder(),
            ),
            items: coatOptions
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) => setState(() => coatType = v),
          ),

          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: saving ? null : savePuppy,
            icon: const Icon(Icons.pets),
            label: Text(saving ? 'Saving...' : 'Save Puppy'),
          ),
        ],
      ),
    );
  }
}