import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../pages/dog_details_page.dart';

class LitterDetailPage extends StatefulWidget {
  final Map litter;

  const LitterDetailPage({
    super.key,
    required this.litter,
  });

  @override
  State<LitterDetailPage> createState() => _LitterDetailPageState();
}

class _LitterDetailPageState extends State<LitterDetailPage> {
  final supabase = Supabase.instance.client;

  List puppies = [];
  bool loading = true;
  Map? litter;

  @override
  void initState() {
    super.initState();
    loadPuppies();
  }

  Future<void> loadPuppies() async {
    // 🔥 Load litter info
    final litterData = await supabase
        .from('litters')
        .select(
            'litter_name, whelp_date, male_count, female_count, dam_ala, sire_ala')
        .eq('id', widget.litter['id'])
        .maybeSingle();

    // 🔥 Load puppies
    final puppyData = await supabase
        .from('dogs')
        .select(
            'id, dog_name, dog_ala, sex, colour, collar_colour, birth_weight, birth_time')
        .eq('litter_id', widget.litter['id']);

    setState(() {
      litter = litterData;
      puppies = puppyData as List;
      loading = false;
    });
  }

  Widget _buildHeader() {
    final litter = widget.litter;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            litter['ala_litter_number'] ?? '',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            litter['litter_full_code'] ?? '',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "${litter['dam_ala']} × ${litter['sire_ala']}",
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Puppies'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : puppies.isEmpty
              ? const Center(child: Text('No puppies found'))
              : Column(
                  children: [
                 // _buildHeader(),   // temporarily removed

                    const SizedBox(height: 8),

                    Expanded(
                      child: ListView.builder(
                        itemCount: puppies.length,
                        itemBuilder: (context, index) {
                          final pup = puppies[index];

                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DogDetailsPage(
                                    dogId: pup['id'],
                                  ),
                                ),
                              );
                            },
                            child: Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              elevation: 3,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor:
                                          pup['sex'] == 'Male' ? Colors.blue : Colors.pink,
                                      child: Text(
                                        pup['sex'] == 'Male' ? '♂' : '♀',
                                        style: const TextStyle(color: Colors.white, fontSize: 18),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pup['dog_name'] ?? 'Unnamed Puppy',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${pup['colour'] ?? ''} • ${pup['collar_colour'] ?? ''}',
                                            style: TextStyle(color: Colors.grey.shade700),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${pup['birth_weight'] ?? '-'}g • ${pup['birth_time'] ?? ''}',
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
          ),
    );
  }
}
