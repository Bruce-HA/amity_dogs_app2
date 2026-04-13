import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DnaDisplayPage extends StatelessWidget {
  final String dogId;
  final String? dogName;

  const DnaDisplayPage({
    super.key,
    required this.dogId,
    this.dogName,
  });

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return Scaffold(
      appBar: AppBar(
        title: Text(dogName ?? "DNA Report"),
      ),
      body: FutureBuilder(
        future: supabase
            .from('dna_results')
            .select()
            .eq('dog_id', dogId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = List<Map<String, dynamic>>.from(snapshot.data as List);

          if (data.isEmpty) {
            return const Center(child: Text("No DNA data uploaded"));
          }

          // 🧠 GROUP DATA
          final coat = data.where((d) => d['category'] == 'coat').toList();
          final colour = data.where((d) => d['category'] == 'colour').toList();
          final health = data.where((d) => d['category'] == 'health').toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [

              _section("🎨 Coat & Colour", [...colour, ...coat]),
              _section("🧬 Health", health),

            ],
          );
        },
      ),
    );
  }

  Widget _section(String title, List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),

        const SizedBox(height: 8),

        ...items.map((d) {
          final name = d['test_name'] ?? '-';
          final genotype = d['genotype'] ?? '';
          final result = d['result'] ?? '';
          final interpretation = d['interpretation'] ?? '';

          return Card(
            child: ListTile(
              title: Text(name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (genotype.isNotEmpty) Text("Genotype: $genotype"),
                  if (result.isNotEmpty) Text("Result: $result"),
                  if (interpretation.isNotEmpty)
                    Text(interpretation,
                        style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 8),
      ],
    );
  }
}