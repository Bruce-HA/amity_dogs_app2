import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pages/breeding/breeding_plans_page.dart';
import '../pages/breeding/litters_page.dart';

class DogBreedingTab extends StatefulWidget {
  final String dogId;

  const DogBreedingTab({
    super.key,
    required this.dogId,
  });

  @override
  State<DogBreedingTab> createState() => _DogBreedingTabState();
}

class _DogBreedingTabState extends State<DogBreedingTab> {
  final supabase = Supabase.instance.client;

  int litterCount = 0;
  int maleCount = 0;
  int femaleCount = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final dogResult = await supabase
        .from('dogs')
        .select('dog_ala')
        .eq('id', widget.dogId)
        .maybeSingle();

    if (dogResult == null) return;

    final dogAla = dogResult['dog_ala'];
    print('DOG ALA: $dogAla');

    // 🔥 ONLY fetch relevant pups (this was the issue)
    final damLitters = await supabase
        .from('litters')
        .select('id, male_count, female_count, dam_ala, sire_ala')
        .eq('dam_ala', dogAla);

    final sireLitters = await supabase
        .from('litters')
        .select('id, male_count, female_count, dam_ala, sire_ala')
        .eq('sire_ala', dogAla);

    final List data = [
      ...damLitters as List,
      ...sireLitters as List,
    ];

    int totalLitters = data.length;
    int m = 0;
    int f = 0;

    for (var litter in data) {
      m += (litter['male_count'] ?? 0) as int;
      f += (litter['female_count'] ?? 0) as int;
    }

    setState(() {
      litterCount = totalLitters;
      maleCount = m;
      femaleCount = f;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Breeding Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Text('Litters: $litterCount'),
          const SizedBox(height: 8),
          Text('🔵♂ $maleCount'),
          Text('🩷♀ $femaleCount'),

          const SizedBox(height: 24),

          const Text(
            'Actions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _actionButton(
            context,
            label: 'Breeding Plans',
            icon: Icons.account_tree,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BreedingPlansPage(
                    dogId: widget.dogId,
                  ),
                ),
              );
            },
          ),

          _actionButton(
            context,
            label: 'Matings',
            icon: Icons.favorite,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Matings page coming next')),
              );
            },
          ),

          _actionButton(
            context,
            label: 'Litters',
            icon: Icons.pets,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LittersPage(
                    dogId: widget.dogId,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          _actionButton(
            context,
            label: 'Record Whelping',
            icon: Icons.child_care,
            isPrimary: true,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Whelping page coming next')),
              );
            },
          ),
        ],
      ),
    );
  }
}
Widget _actionButton(
  BuildContext context, {
  required String label,
  required IconData icon,
  required VoidCallback onTap,
  bool isPrimary = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isPrimary ? Colors.blue : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: isPrimary ? Colors.white : Colors.black87),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isPrimary ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                color: isPrimary ? Colors.white : Colors.black54),
          ],
        ),
      ),
    ),
  );
}