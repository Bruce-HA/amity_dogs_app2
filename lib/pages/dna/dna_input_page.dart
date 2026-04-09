import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DNAInputPage extends StatefulWidget {
  final String dogId;
  final String dogName;

  const DNAInputPage({
    super.key,
    required this.dogId,
    required this.dogName,
  });

  @override
  State<DNAInputPage> createState() => _DNAInputPageState();
}

class _DNAInputPageState extends State<DNAInputPage> {
  final supabase = Supabase.instance.client;

  final TextEditingController eController = TextEditingController();
  final TextEditingController bController = TextEditingController();
  final TextEditingController aController = TextEditingController();

  bool saving = false;

  Future<void> _saveDNA() async {
    setState(() => saving = true);

    final e = eController.text.trim();
    final b = bController.text.trim();
    final a = aController.text.trim();

    // 🧹 Clear existing DNA for this dog
    await supabase
        .from('dna_bank')
        .delete()
        .eq('dog_id', widget.dogId);

    Future<void> insertLocus(String locus, String value) async {
      if (value.isEmpty) return;

      final parts = value.split('/');

      await supabase.from('dna_bank').insert({
        'dog_id': widget.dogId,
        'dog_name': widget.dogName,
        'locus': locus,
        'allele_1': parts[0],
        'allele_2': parts.length > 1 ? parts[1] : parts[0],
      });
    }

    await insertLocus('E', e);
    await insertLocus('B', b);
    await insertLocus('A', a);

    // ✅ KEEP THIS (important for your UI logic)
    await supabase.from('dogs').update({
      'has_dna_summary': true,
    }).eq('id', widget.dogId);

    Navigator.pop(context, true);
  }

  Widget _field(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: "e.g. E/e",
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("DNA Input")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Enter DNA Results",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            _field("E Locus (Extension)", eController),
            const SizedBox(height: 12),

            _field("B Locus (Chocolate)", bController),
            const SizedBox(height: 12),

            _field("A Locus (Agouti)", aController),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: saving ? null : _saveDNA,
              child: saving
                  ? const CircularProgressIndicator()
                  : const Text("Save DNA"),
            ),
          ],
        ),
      ),
    );
  }
}