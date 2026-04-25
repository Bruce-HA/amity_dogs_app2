import 'package:flutter/material.dart';
import '../../tabs/genetics_tab.dart'; 
import '/services/breeding_plan_service.dart'; //djust path if needed

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

            // test button
            ElevatedButton(
              onPressed: () async {
                final result = await BreedingPlanService.createBreedingPlan(
                  femaleDogAla: '0174-024-04', // real female
                  maleDogAla: '0174-013-06',   // real male
                  breedingPlanCode: 'TEST-B01',
                );

                print('Breeding Plan Created: $result');
              },
              child: const Text('Test Breeding Plan'),
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
  Widget colourBadge(String label) {
    Color bg;

    switch (label) {
      case 'Chocolate':
        bg = Colors.brown;
        break;
      case 'Caramel':
        bg = Colors.orange;
        break;
      case 'Black':
        bg = Colors.black;
        break;
      case 'Phantom':
        bg = Colors.purple;
        break;
      default:
        bg = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}