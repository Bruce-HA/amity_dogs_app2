import 'package:flutter/material.dart';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class TrialMatingPage extends StatefulWidget {
  const TrialMatingPage({super.key});

  @override
  State<TrialMatingPage> createState() => _TrialMatingPageState();
}

class _TrialMatingPageState extends State<TrialMatingPage> {

  Map<String, dynamic>? female;
  Map<String, dynamic>? male;
//jj
  Future<double?> _calculateIBC(String femaleAla, String maleAla) async {
    try {
      final femalePedigree = await Supabase.instance.client.rpc(
        'get_simple_pedigree',
        params: {
          'start_ala': femaleAla,
          'max_generations': 7
          ,
        },
      );

      final malePedigree = await Supabase.instance.client.rpc(
        'get_simple_pedigree',
        params: {
          'start_ala': maleAla,
          'max_generations': 5,
        },
      );

      if (femalePedigree == null || malePedigree == null) return null;

      double ibc = 0.0;

      // 🔥 group by ancestor
      final femaleByAncestor = <String, List<Map>>{};
      final maleByAncestor = <String, List<Map>>{};

      for (var d in femalePedigree) {
        if ((d['generation'] ?? 0) > 0) {
          femaleByAncestor.putIfAbsent(d['dog_ala'], () => []).add(d);
        }
      }

      for (var d in malePedigree) {
        if ((d['generation'] ?? 0) > 0) {
          maleByAncestor.putIfAbsent(d['dog_ala'], () => []).add(d);
        }
      }

      // 🔥 Wright’s formula
      for (var ancestor in femaleByAncestor.keys) {
        if (!maleByAncestor.containsKey(ancestor)) continue;

        final femalePaths = femaleByAncestor[ancestor]!;
        final malePaths = maleByAncestor[ancestor]!;

        for (var f in femalePaths) {
          for (var m in malePaths) {
            final n1 = f['generation'];
            final n2 = m['generation'];

            // assume Fa = 0 for now
            final contribution = 1 / (pow(2, (n1 + n2 + 1)));

            ibc += contribution;
          }
        }
      }

      return ibc;
    } catch (e) {
      print("IBC ERROR: $e");
      return null;
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🐶 Trial Mating")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _selector(
              title: "Select Female",
              dog: female,
              onTap: () async {
                final result = await _pickDog(context);
                if (result != null) {
                  setState(() => female = result);
                }
                
              },
            ),

            const SizedBox(height: 12),

            _selector(
              title: "Select Male",
              dog: male,
              onTap: () async {
                final result = await _pickDog(context);
                if (result != null) {
                  setState(() => male = result);
                }
              },
            ),
            const SizedBox(height: 20),

              if (female != null && male != null)
                Column(
                  children: [
                    FutureBuilder<double?>(
                      future: _calculateIBC(
                        female!['dog_ala'],
                        male!['dog_ala'],
                      ),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Text("Calculating...");
                        }

                        final coi = snapshot.data!;
                        final percent = (coi * 100).toStringAsFixed(2);

                        return Text(
                          "🧬 COI: $percent%",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        );
                      },
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }

  /// ✅ SELECTOR (ENDS PROPERLY)
  Widget _selector({
    required String title,
    required Map<String, dynamic>? dog,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Text(dog?['dog_name'] ?? title),
      ),
    );
  }

  /// ✅ MOVE THIS OUTSIDE
  Future<Map<String, dynamic>?> _pickDog(BuildContext context) async {
    return {
      'dog_name': 'Test Dog',
      'dog_ala': 'ALA123',
    };
  }
}