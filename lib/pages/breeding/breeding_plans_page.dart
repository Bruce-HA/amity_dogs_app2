import 'package:flutter/material.dart';
import '../../tabs/dna_tab.dart'; // adjust path if needed

class BreedingPlansPage extends StatelessWidget {
  final String dogId;

  const BreedingPlansPage({
    super.key,
    required this.dogId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Breeding Plans'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Breeding Plans',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            // 🔥 Placeholder for plans (we build this next)
            const Text('No plans yet'),

            const SizedBox(height: 32),

            // 🧬 DNA SECTION (THIS is the key part)
            const Text(
              'DNA',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 500,
              child: DnaTab(dogId: dogId),
            ),
          ],
        ),
      ),
    );
  }
}