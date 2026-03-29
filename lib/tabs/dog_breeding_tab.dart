import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

    // 🔥 ONLY fetch relevant pups (this was the issue)
    final pups = await supabase
        .from('dogs')
        .select('dog_ala, sex')
        .or('mother_ala.eq.$dogAla,father_ala.eq.$dogAla');

    final data = pups as List;

    final Set<String> litterSet = {};
    int m = 0;
    int f = 0;

    for (var pup in data) {
      final ala = pup['dog_ala']?.toString();
      final sexRaw = pup['sex']?.toString().toLowerCase();

      if (sexRaw != null) {
        if (sexRaw.startsWith('m')) m++;
        if (sexRaw.startsWith('f')) f++;
      }

      if (ala != null) {
        final parts = ala.split('-'); // 🔥 match your DB format
        if (parts.length >= 2) {
          litterSet.add('${parts[0]}-${parts[1]}');
        }
      }
    }

    setState(() {
      litterCount = litterSet.length;
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

    return Padding(
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
        ],
      ),
    );
  }
}