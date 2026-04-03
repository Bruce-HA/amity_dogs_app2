import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'litter_log_page.dart';

final supabase = Supabase.instance.client;

class DailiesPage extends StatefulWidget {
  const DailiesPage({super.key});

  @override
  State<DailiesPage> createState() => _DailiesPageState();
}

class _DailiesPageState extends State<DailiesPage> {
  List litters = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadLitters();
  }

  Future<void> loadLitters() async {
    final res = await supabase
        .from('litters')
        .select()
        .not('litter_full_code', 'is', null)
        .order('created_at', ascending: false)
        .limit(20);

    List updated = [];

    for (var litter in res) {
      String? hero;

      final dogRes = await supabase
          .from('dogs_list_view_with_hero')
          .select('hero, dog_ala')
          .eq('dog_ala', litter['dam_ala'])
          .limit(1);

      if (dogRes.isNotEmpty) {
        final dog = dogRes.first;
        final heroList = dog['hero'] as List?;

        if (heroList != null && heroList.isNotEmpty) {
          final heroItem = heroList.first;
          final fileName = heroItem['url'];
          final dogAla = dog['dog_ala'];

          if (fileName != null && dogAla != null) {
            hero = supabase.storage
                .from('dog_files')
                .getPublicUrl('$dogAla/photos/$fileName');
          }
        }
      }

      litter['heroImage'] = hero;
      updated.add(litter);
    }

    setState(() {
      litters = updated;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: litters.length,
              itemBuilder: (context, index) {
                final litter = litters[index];

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),

                    leading: litter['heroImage'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              litter['heroImage'],
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey.shade300,
                          ),

                    title: Text(
                      litter['short_litter_name'] ??
                          litter['litter_full_code'] ??
                          'Unnamed Litter',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    subtitle: Text(
                      "${litter['dam_ala']} × ${litter['sire_ala']}",
                    ),

                    trailing: const Icon(Icons.chevron_right),

                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LitterLogPage(litter: litter),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}