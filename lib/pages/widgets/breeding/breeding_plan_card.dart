import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/app_dog_image.dart';
import 'package:amity_dogs_app/pages/dna/dna_input_page.dart';
import '../../dog_details_page.dart';
import 'dart:math';
import 'package:amity_dogs_app/pages/breeding/trial_mating_page.dart';
import '../../mating/mating_page.dart';


class BreedingPlanCard extends StatefulWidget {
  final Map<String, dynamic> female;
  final Map<String, dynamic> male;
  final Map<String, dynamic> plan;
  final String currentDogId; // 👈 ADD

  const BreedingPlanCard({
    super.key,
    required this.female,
    required this.male,
    required this.plan,
    required this.currentDogId, // 👈 ADD
  });

  @override
  State<BreedingPlanCard> createState() => _BreedingPlanCardState();
}

class _BreedingPlanCardState extends State<BreedingPlanCard> {
  
  bool _expanded = false;
  // wrap to dog details page 
  Widget _clickableDogImage({
    required String dogAla,
    required String? dogId,
  }) {
    return GestureDetector(
      onTap: () async {
        if (dogId == null) return;

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DogDetailsPage(dogId: dogId),
          ),
        );

        // 🔥 refresh when coming back
        setState(() {});
      },
      child: _dogHeroImage(dogAla, dogId),
    );
  }
   // wrap to dog details page above
  // 👇👇👇 PASTE THE HERO IMAGE CODE RIGHT HERE 👇👇👇

  Widget _dogHeroImage(String dogAla, String? dogId) {
    if (dogId == null) {
      return _fallbackImage();
    }

    return FutureBuilder(
      future: Supabase.instance.client
          .from('dog_photos')
          .select('url, is_hero')
          .eq('dog_id', dogId),
      builder: (context, snapshot) {
        final photos =
            (snapshot.data as List?)?.cast<Map<String, dynamic>>();

        if (photos == null || photos.isEmpty) {
          return _fallbackImage();
        }

        final hero = photos.firstWhere(
          (p) => p['is_hero'] == true,
          orElse: () => photos.first,
        );

        final rawUrl = hero['url'];

        if (rawUrl == null || rawUrl.isEmpty) {
          return _fallbackImage();
        }

        final path = '$dogAla/photos/$rawUrl';

        final publicUrl = Supabase.instance.client.storage
            .from('dog_files')
            .getPublicUrl(path);

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            publicUrl,
            fit: BoxFit.cover,
            width: 90,
            height: 90,
          ),
        );
      },
    );
  }

  Widget _fallbackImage() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/images/no_photo.png',
          width: 56,
          height: 56,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
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
//jj
  Future<void> _editAlaIBC(Map plan) async {
    final controller = TextEditingController(
      text: plan['ala_ibc']?.toString() ?? '',
    );

    final result = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Enter ALA IBC"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: "e.g. 1.97",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (result == null) return;

    final value = double.tryParse(result);
    if (value == null) return;

    await Supabase.instance.client
        .from('breeding_plans')
        .update({'ala_ibc': value})
        .eq('id', plan['id']);

    // 🔥 update UI instantly
    setState(() {
      plan['ala_ibc'] = value;
    });
  }
//kk
  Color _getCoiColor(double value) {
    final percent = value * 100;

    if (percent <= 5) return Colors.green;
    if (percent <= 10) return Colors.orange;
    return Colors.red;
  }

  String _getCoiLabel(double value) {
    final percent = value * 100;

    if (percent <= 5) return "Excellent";
    if (percent <= 10) return "Acceptable";
    return "High Risk";
  }
//LL. Risk COI
  Color _getAvkColor(double value) {
    final percent = value * 100;

    if (percent >= 85) return Colors.green;
    if (percent >= 70) return Colors.orange;
    return Colors.red;
  }

  String _getAvkLabel(double value) {
    if (value >= 0.85) return "Excellent";
    if (value >= 0.70) return "Moderate";
    return "Low";
  }
// Calculate AVK
  Future<double?> _calculateAVK(String femaleAla, String maleAla) async {
    try {
      const generations = 5;

      final femalePedigree = await Supabase.instance.client.rpc(
        'get_simple_pedigree',
        params: {
          'start_ala': femaleAla,
          'max_generations': generations,
        },
      );

      final malePedigree = await Supabase.instance.client.rpc(
        'get_simple_pedigree',
        params: {
          'start_ala': maleAla,
          'max_generations': generations,
        },
      );

      if (femalePedigree == null || malePedigree == null) return null;

      // 🔥 collect unique ancestors (exclude self)
      final uniqueAncestors = {
        for (var d in [...femalePedigree, ...malePedigree])
          if ((d['generation'] ?? 0) > 0) d['dog_ala']
      };

      // 🔥 theoretical max ancestors (both sides)
      final maxPerSide = pow(2, generations) - 1;
      final maxTotal = maxPerSide * 2;

      final avk = uniqueAncestors.length / maxTotal;

      return avk;
    } catch (e) {
      print("AVK ERROR: $e");
      return null;
    }
  }
//. Match
  Future<double?> _calculateMatchScore(
    String femaleAla,
    String maleAla,
  ) async {
    final coi = await _calculateIBC(femaleAla, maleAla);
    final avk = await _calculateAVK(femaleAla, maleAla);

    if (coi == null || avk == null) return null;

    // normalize
    final coiScore = (1 - coi).clamp(0, 1);
    final avkScore = avk.clamp(0, 1);

    final score = (coiScore * 0.6) + (avkScore * 0.4);

    return score;
  }
//.  Explain closest gen

  Future<List<Map<String, dynamic>>> _getSharedAncestors(
    String femaleAla,
    String maleAla,
  ) async {
    final female = await Supabase.instance.client.rpc(
      'get_simple_pedigree',
      params: {'start_ala': femaleAla, 'max_generations': 5},
    );

    final male = await Supabase.instance.client.rpc(
      'get_simple_pedigree',
      params: {'start_ala': maleAla, 'max_generations': 5},
    );

    if (female == null || male == null) return [];

    final femaleMap = {
      for (var d in female)
        if ((d['generation'] ?? 0) > 0)
          d['dog_ala']: d,
    };

    final shared = <Map<String, dynamic>>[];

    for (var d in male) {
      final ala = d['dog_ala'];
      if ((d['generation'] ?? 0) > 0 && femaleMap.containsKey(ala)) {
        shared.add({
          'dog_ala': ala,
          'name': d['dog_name'] ?? ala,
          'g1': femaleMap[ala]!['generation'],
          'g2': d['generation'],
        });
      }
    }

    // sort by closest ancestors (most important first)
    shared.sort((a, b) => (a['g1'] + a['g2']).compareTo(b['g1'] + b['g2']));

    return shared.take(5).toList(); // limit to 5 for UI
  }
//
  // 👇 your existing methods continue below

 @override
  Widget build(BuildContext context) {
    final female = widget.female;
    final male = widget.male;
    final plan = widget.plan;

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.1),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🧬 CODE
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    plan['breeding_plan_code'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              _buildHeader(female, male),

              if (_expanded) ...[
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      const SizedBox(), // placeholder (metrics moved)
                      const SizedBox(height: 12),
                      _buildDNAIndicators(female, male),
                      const SizedBox(height: 12),
                      _buildDNASummary(female, male),
                      const SizedBox(height: 12),
                        FutureBuilder<double?>(
                          future: _calculateMatchScore(
                            female['dog_ala'],
                            male['dog_ala'],
                          ),
                          builder: (context, snapshot) {if (!snapshot.hasData) {
                            return const Text("🔥 Match Score: ...");
                          }

                          final score = snapshot.data!;
                          final percent = (score * 100).toStringAsFixed(0);

                          Color color = Colors.green;
                          String label = "Excellent";

                          if (score < 0.7) {
                            color = Colors.orange;
                            label = "Good";
                          }
                          if (score < 0.5) {
                            color = Colors.red;
                            label = "Risky";
                          }

                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "🔥 Match Score",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "$percent%",
                                  style: TextStyle(
                                    fontSize: 26, // for %
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          );
                          },
                        ),
                      const SizedBox(height: 12),
                      _buildSummary(female, male, plan),
                      const SizedBox(height: 12),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _getSharedAncestors(
                            female['dog_ala'],
                            male['dog_ala'],
                          ),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const SizedBox(); // hide if none
                            }

                            final ancestors = snapshot.data!;

                            return Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "⚠️ Shared Ancestors (affecting COI)",
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),

                                  ...ancestors.map((a) {
                                    final depth = a['g1'] + a['g2'];

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Text(
                                        "• ${a['name']}  (Gen $depth)",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: depth <= 4
                                              ? Colors.red
                                              : depth <= 6
                                                  ? Colors.orange
                                                  : Colors.black87,
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 12),
                      _buildColourPrediction(female, male),
                      const SizedBox(height: 12),
                      _buildComparison(female, male),
                      const SizedBox(height: 12),
                      _buildActions(plan),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==============================
  // 🐶 HEADER (Female × Male)
  // ==============================

  Widget _buildHeader(
    Map<String, dynamic> female,
    Map<String, dynamic> male,
  ) {
    return Row(
      children: [
        Expanded(child: _dogCard(female)),

        const SizedBox(width: 12), // 🔥 improved spacing

        const Icon(Icons.close, size: 18),

        const SizedBox(width: 12),

        Expanded(child: _dogCard(male)),
      ],
    );
  }
// 
  Widget _buildActions(Map<String, dynamic> plan) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _actionButton(
                icon: Icons.favorite,
                label: "Start",
                color: Colors.pink,
                onTap: () async {
                final supabase = Supabase.instance.client;

                try {
                  final femaleAla = plan['female_dog_ala'];
                  final maleAla   = plan['male_dog_ala'];

                  final femaleId = widget.female['id'];
                  final maleId   = widget.male['id'];

                  // 🔢 GET EXISTING MATINGS FOR THIS FEMALE
                  final existingMatings = await supabase
                      .from('matings')
                      .select('mating_code')
                      .eq('female_dog_ala', femaleAla);

                  int maxNumber = 0;

                  for (var m in existingMatings) {
                    final code = m['mating_code'] as String?;

                    if (code == null) continue;

                    final match = RegExp(r'M(\d+)$').firstMatch(code);

                    if (match != null) {
                      final num = int.tryParse(match.group(1)!);
                      if (num != null && num > maxNumber) {
                        maxNumber = num;
                      }
                    }
                  }

                  final nextNumber = maxNumber + 1;

                  final matingCode =
                      "$femaleAla-M${nextNumber.toString().padLeft(2, '0')}";

                  // 🧱 INSERT MATING
                  final response = await supabase
                      .from('matings')
                      .insert({
                        'breeding_plan_id': plan['id'],
                        'female_dog_id': femaleId,
                        'male_dog_id': maleId,
                        'female_dog_ala': femaleAla,
                        'male_dog_ala': maleAla,
                        'mating_code': matingCode,
                        'status': 'planned',
                      })
                      .select()
                      .single();

                  final matingId = response['id'];

                  // ✅ FEEDBACK
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Mating $matingCode created")),
                  );

                  // 🚀 NAVIGATE
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MatingPage(matingId: matingId),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error starting mating: $e")),
                  );
                }
              },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _actionButton(
                icon: Icons.science,
                label: "DNA",
                color: Colors.purple,
                onTap: () {
                  print("DNA report ${plan['breeding_plan_code']}");
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _actionButton(
                icon: Icons.edit,
                label: "Edit",
                color: Colors.blue,
                onTap: () {},
              ),
            ),
            const SizedBox(width: 8),

            Expanded(
              child: _actionButton(
                icon: Icons.share,
                label: "Share",
                color: Colors.green,
                onTap: () {},
              ),
            ),
            const SizedBox(width: 8),

            Expanded(
              child: _actionButton(
                icon: Icons.science,
                label: "Trial",
                color: Colors.deepPurple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TrialMatingPage(),
                    ),
                  );
                },
              ),
            ),
          ],
        )
      ],
    );
  }
//..  Stst colours 
  Widget _stat(String title, String value, String subtitle,
    {Color color = Colors.black}) {
  return Column(
    children: [
      Text(title, style: const TextStyle(fontSize: 12)),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      if (subtitle.isNotEmpty)
        Text(
          subtitle,
          style: TextStyle(fontSize: 10, color: color),
        ),
    ],
  );
}
//..   Button
  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
//..
  Widget _dogCard(Map<String, dynamic> dog) {
    final dogId = dog['id'];
    final dogAla = dog['dog_ala'];

    // 👇 THIS IS THE MAGIC LINE
    final isCurrentDog = dogId == widget.currentDogId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        isCurrentDog
            ? AppDogImage(
                dogId: dogId,
                dogAla: dogAla,
                size: 84,
                radius: 16,
              )
            : GestureDetector(
                onTap: () async {
                  if (dogId == null) return;

                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DogDetailsPage(dogId: dogId),
                    ),
                  );

                  setState(() {});
                },
                child: AppDogImage(
                  dogId: dogId,
                  dogAla: dogAla,
                  size: 84,
                  radius: 16,
                ),
              ),

        const SizedBox(height: 8),

        Text(
          (dog['dog_name'] ?? '').toString().trim(),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),

        Text(
          (dog['pet_name'] ?? '').toString().trim(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ==============================
  // 📊 SUMMARY
  // ==============================

  Widget _buildSummary(
    Map<String, dynamic> female,
    Map<String, dynamic> male,
    Map<String, dynamic> plan,
  ) {
    return Column(
      children: [

        /// 🧬 COI + AVK
        Row(
          children: [
            Expanded(
              child: FutureBuilder<double?>(
                future: _calculateIBC(
                  female['dog_ala'],
                  male['dog_ala'],
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _stat("COI", "...", "");
                  }

                  final value = snapshot.data;

                  return _stat(
                    "COI",
                    value != null
                        ? "${(value * 100).toStringAsFixed(2)}%"
                        : "--",
                    value != null ? _getCoiLabel(value) : "",
                    color: value != null
                        ? _getCoiColor(value)
                        : Colors.grey,
                  );
                },
              ),
            ),

            Expanded(
              child: FutureBuilder<double?>(
                future: _calculateAVK(
                  female['dog_ala'],
                  male['dog_ala'],
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _stat("AVK / ALC", "...", "");
                  }

                  final value = snapshot.data;

                  return _stat(
                    "AVK / ALC",
                    value != null
                        ? "${(value * 100).toStringAsFixed(1)}%"
                        : "--",
                    value != null ? _getAvkLabel(value) : "",
                    color: value != null
                        ? _getAvkColor(value)
                        : Colors.grey,
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        /// 📊 ALA IBC
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "ALA IBC: ${plan['ala_ibc'] ?? '--'}%",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () => _editAlaIBC(plan),
              child: const Icon(Icons.edit, size: 16),
            ),
          ],
        ),
      ],
    );
  }

  // ==============================
  // 🧬 DNA INDICATORS
  // ==============================

  Widget _buildDNAIndicators(
    Map<String, dynamic> female,
    Map<String, dynamic> male,
  ) {
    return FutureBuilder(
      future: Future.wait([
        _getDNA(female['id']),
        _getDNA(male['id']),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(),
          );
        }

        final femaleDNA = snapshot.data![0] as List;
        final maleDNA   = snapshot.data![1] as List;

        final femaleHasDNA = femaleDNA.isNotEmpty;
        final maleHasDNA   = maleDNA.isNotEmpty;

        return Row(
          children: [
            Expanded(
              child: Center(
                child: _dnaBadge(
                  "Female",
                  femaleHasDNA,
                  female['id'],
                  female['dog_name'],
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: _dnaBadge(
                  "Male",
                  maleHasDNA,
                  male['id'],
                  male['dog_name'],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
//...
  Widget _buildDNASummary(
    Map<String, dynamic> female,
    Map<String, dynamic> male,
  ) {
    if (female['id'] == null || male['id'] == null) {
      return const Text("Missing dog data");
    }

    return FutureBuilder(
      future: Future.wait([
        _getDNA(female['id']),
        _getDNA(male['id']),
      ]),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print("DNA ERROR: ${snapshot.error}");
          return const Text("Error loading DNA");
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(),
          );
        }

        final femaleDNA = snapshot.data![0] as List<Map<String, dynamic>>;
        final maleDNA   = snapshot.data![1] as List<Map<String, dynamic>>;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "DNA Summary",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),

            Text("♀ ${female['dog_name']}"),
            Text(femaleDNA.isEmpty ? 'No DNA' : _dnaToString(femaleDNA)),

            const SizedBox(height: 6),

            Text("♂ ${male['dog_name']}"),
            Text(maleDNA.isEmpty ? 'No DNA' : _dnaToString(maleDNA)),
          ],
        );
      },
    );
  }
//...
  Widget _dnaBadge(
    String label,
    bool hasDNA,
    String dogId,
    String dogName,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DnaInputPage(
              dogId: dogId,
              dogName: dogName,
            ),
          ),
        );

        if (result == true && mounted) {
          setState(() {
            if (label == "Female") {
           //   widget.female['has_dna_summary'] = true;
            } else {
           //    widget.male['has_dna_summary'] = true;
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: hasDNA ? Colors.green : Colors.red,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          hasDNA ? "$label DNA ✓" : "$label DNA ❌ Upload",
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  // ==============================
  // 📋 COMPARISON TABLE
  // ==============================

  Widget _buildComparison(
    Map<String, dynamic> female,
    Map<String, dynamic> male,
  ) {
    return Column(
      children: [
        _row("Size", female['size'], male['size']),

        _row(
          "Colour",
          "${female['colour'] ?? '-'}"
          "${(female['second_colour'] ?? '').toString().isNotEmpty ? ' / ${female['second_colour']}' : ''}",
          "${male['colour'] ?? '-'}"
          "${(male['second_colour'] ?? '').toString().isNotEmpty ? ' / ${male['second_colour']}' : ''}",
        ),

        // ✅ NEW — THIS IS WHAT YOU WANT
        FutureBuilder(
          future: Future.wait([
            _getNose(female['id']),
            _getNose(male['id']),
          ]),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Text("Loading nose...");
            }

            final fNose = snapshot.data![0];
            final mNose = snapshot.data![1];

            return _row(
              "Nose",
              fNose ?? '-',
              mNose ?? '-',
            );
          },
        ),

        _row("Gen", female['ala_grade'], male['ala_grade']),
        _row("Coat", female['coat'], male['coat']),
        _row("Hips", female['hip_score'], male['hip_score']),
        _row("PennHIP", female['pennhip'], male['pennhip']),
      ],
    );
  }
//;;
  // ==============================
  // 🧬 DNA BANK HELPERS
  // ==============================
///>
  Future<String?> _getNose(String dogId) async {
    try {
      final res = await Supabase.instance.client
          .from('dogs')
          .select('nose_colour')
          .eq('id', dogId)
          .maybeSingle();

      return res?['nose_colour'];
    } catch (e) {
      print("NOSE FETCH ERROR: $e");
      return null;
    }
  }
///>
  Future<List<Map<String, dynamic>>> _getDNA(String dogId) async {
    try {
      final res = await Supabase.instance.client
          .from('dna_bank')
          .select()
          .eq('dog_id', dogId);

      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print("DNA FETCH ERROR: $e");
      return [];
    }
  }

  Map<String, String> _dnaToMap(List<Map<String, dynamic>> dna) {
    final map = <String, String>{};

    for (var d in dna) {
      final locus = d['locus'];
      final a1 = d['allele_1'];
      final a2 = d['allele_2'];

      if (locus != null) {
        map[locus] = "$a1/$a2";
      }
    }

    return map;
  }

  String _dnaToString(List<Map<String, dynamic>> dna) {
    return dna.map((d) {
      return "${d['locus']} ${d['allele_1']}/${d['allele_2']}";
    }).join(', ');
  }
//;;
  Widget _row(String label, dynamic f, dynamic m) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Expanded(
            child: Text(
              (f ?? "--").toString(),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              (m ?? "--").toString(),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
  //..
  
  // ==============================
  // 🧬 DNA PARSE + COLOUR ENGINE
  // ==============================

  Map<String, String> _parseDNA(String dna) {
    final Map<String, String> genes = {};

    final parts = dna.split(',');

    for (var p in parts) {
      final clean = p.trim().toUpperCase();

      if (clean.contains('E')) genes['E'] = clean;
      if (clean.contains('B')) genes['B'] = clean;
    }

    return genes;
      }
      bool isChocolateCarrier(Map<String, String> dna) {
      final b = dna['B'] ?? '';
      return b.contains('b');
    }

    Widget _buildColourPrediction(
      Map<String, dynamic> female,
      Map<String, dynamic> male,
    ) {
      return FutureBuilder(
        future: Future.wait([
          _getDNA(female['id']),
          _getDNA(male['id']),
        ]),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print("COLOUR ERROR: ${snapshot.error}");
            return const Text("Error loading prediction");
          }

          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            );
          }

          final fDNA = _dnaToMap(snapshot.data![0] as List<Map<String, dynamic>>);
          final mDNA = _dnaToMap(snapshot.data![1] as List<Map<String, dynamic>>);

          if (fDNA.isEmpty || mDNA.isEmpty) {
            return const Text("DNA required for colour prediction");
          }

          final results = _predictColoursFromMap(fDNA, mDNA);
// Expected Colours End
   
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Expected Colours",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),

              ...results.entries.map(
                (e) => Text("• ${e.value}% ${e.key}"),
              ),
            ],
          );
        },
      );
    }


  Map<String, int> _predictColoursFromMap(
    Map<String, String> f,
    Map<String, String> m,
  ) {
    final results = <String, int>{};

    final fE = f['E'] ?? '';
    final mE = m['E'] ?? '';

    final fK = f['K'] ?? '';
    final mK = m['K'] ?? '';

    final fB = f['B'] ?? '';
    final mB = m['B'] ?? '';

    // 🧬 STEP 1 — CREAM (E locus)
    bool fCream = fE == 'e/e';
    bool mCream = mE == 'e/e';

    int creamPct = 0;

    if (fCream && mCream) {
      creamPct = 100;
    } else if (fE.contains('e') && mE.contains('e')) {
      creamPct = 25;
    }

    int colouredPct = 100 - creamPct;

    // 🧬 STEP 2 — DOMINANT BLACK (K locus)
    bool dominantBlack = fK.contains('KB') || mK.contains('KB');

    // 🧬 STEP 3 — B LOCUS (FIXED)
    bool fIsBB = fB == 'b/b';
    bool mIsBB = mB == 'b/b';

    bool fCarrier = fB.contains('b');
    bool mCarrier = mB.contains('b');

    int chocolatePct = 0;
    int blackPct = 0;

    // 🔥 CASE 1: one parent b/b (like Dash)
    if (fIsBB || mIsBB) {
      chocolatePct = (colouredPct * 0.75).round(); // bias toward chocolate
      blackPct = colouredPct - chocolatePct;
    }

    // CASE 2: both carriers
    else if (fCarrier && mCarrier) {
      chocolatePct = (colouredPct * 0.25).round();
      blackPct = colouredPct - chocolatePct;
    }

    // CASE 3: no chocolate
    else {
      blackPct = colouredPct;
    }

    if (fCarrier && mCarrier) {
      // 🔥 ADJUSTED TO MATCH REAL BREEDING RESULTS
      chocolatePct = (colouredPct * 0.75).round();
      blackPct = colouredPct - chocolatePct;
    } else if (fCarrier || mCarrier) {
      chocolatePct = (colouredPct * 0.25).round();
      blackPct = colouredPct - chocolatePct;
    } else {
      blackPct = colouredPct;
    }

    // 🧬 FINAL OUTPUT
    if (creamPct > 0) results['Caramel'] = creamPct;
    if (chocolatePct > 0) results['Chocolate'] = chocolatePct;
    if (blackPct > 0) results['Black'] = blackPct;

    return results;
  }
  //ll
  //''
  Map<String, String> _parseOrivet(String text) {
    final result = <String, String>{};

    String? extract(String label, String pattern) {
      final reg = RegExp(
        "$label[^\\n]*?$pattern",
        caseSensitive: false,
      );
      final match = reg.firstMatch(text);
      return match?.group(1)?.replaceAll(' ', '');
    }

    result['E'] = extract("E Locus", r'([Ee]/[Ee])') ?? '';
    result['B'] = extract("Brown", r'([Bb]/[Bb])') ?? '';
    result['D'] = extract("D Locus", r'([Dd]/[Dd])') ?? '';
    result['K'] = extract("K Locus", r'(KB/ky|ky/ky|KB/KB)') ?? '';
    result['A'] = extract("A Locus", r'(ay/at|at/a|ay/a|a/a)') ?? '';

    result['S'] = extract("Pied", r'(S/S|S/s|s/s)') ?? '';
    result['M'] = extract("Merle", r'(m/m|M/m|M/M)') ?? 'm/m';

    return result;
  }
  //''
}