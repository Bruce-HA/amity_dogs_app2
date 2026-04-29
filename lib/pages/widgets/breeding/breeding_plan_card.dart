import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/app_dog_image.dart';
import 'package:amity_dogs_app/pages/dna/dna_input_page.dart';
import '../../dog_details_page.dart';
import 'dart:math';
import 'package:amity_dogs_app/pages/breeding/trial_mating_page.dart';
import '../../mating/mating_page.dart';
import '../../../utils/display_helpers.dart';
import '../../../services/genetics_service.dart';
import '../../breeding/breeding_summary.dart';
import '../../../services/breeding_report.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/breeding_report_v2.dart';
import '../../flow/start_flow_page.dart';
import '../../flow/flow_detail_page.dart';
import '../../dna/breeding_pair_dna_page.dart';


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
  Map<String, dynamic>? activeFlow;
  bool checkingActiveFlow = true;

  @override
  void initState() {
    super.initState();
    _loadActiveFlow();
  }

  Future<void> _loadActiveFlow() async {
    try {
      final data = await Supabase.instance.client
          .from('breeding_flows')
          .select('id, breeding_plan_id, current_stage, status, archived')
          .eq('breeding_plan_id', widget.plan['id'])
          .eq('archived', false)
          .not('status', 'in', '(completed,archived,cancelled,whelped)')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        activeFlow = data;
        checkingActiveFlow = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        activeFlow = null;
        checkingActiveFlow = false;
      });
    }
  }
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

    return AppDogImage(
      dogId: dogId,
      dogAla: dogAla,
      size: 56,
      radius: 12,
    );
  }

///
///
///
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
// ==== ALA Grading====
  String _calculatePuppyAlaGrade(
    String femaleGrade,
    String maleGrade,
  ) {
    final grades = [
      femaleGrade.toUpperCase(),
      maleGrade.toUpperCase(),
    ];

    // AL + AL = AL
    if (grades.every((g) => g == 'AL')) {
      return 'AL';
    }

    // ALF3 + ALF3 or AL = AL
    if (
      grades.contains('ALF3') &&
      (grades.contains('ALF3') || grades.contains('AL'))
    ) {
      return 'AL';
    }

    // ALF2 progression
    if (
      grades.contains('ALF2') &&
      (grades.contains('ALF2') ||
          grades.contains('ALF3') ||
          grades.contains('AL'))
    ) {
      return 'ALF3';
    }

    // ALF1 progression
    if (
      grades.contains('ALF1') &&
      (grades.contains('ALF1') ||
          grades.contains('ALF2') ||
          grades.contains('ALF3') ||
          grades.contains('AL'))
    ) {
      return 'ALF2';
    }

    // LO / parent breed resets
    if (
      grades.any((g) =>
          g.startsWith('LO') ||
          g.contains('POODLE') ||
          g.contains('COCKER') ||
          g.contains('LABRADOR') ||
          g.contains('SPOODLE'))
    ) {
      return 'ALF1';
    }

    return 'Review Required';
  }
//====================
 
//====

//-----------
  Widget _buildColourWheel(
    Map<String, String> female,
    Map<String, String> male,
    String puppyGrade,
    String coatType,
  ) {
    final genotypeMap = GeneticsService.buildGenotypeMap(
      female,
      male,
    );

    final results = GeneticsService.buildPhenotypes(
      genotypeMap,
    );

    final entries = results.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    Color sectionColor(String name) {
    final lower = name.toLowerCase();

    if (lower.contains('caramel')) {
      return const Color(0xFFD8A15B);
    }

    if (lower.contains('chocolate')) {
      return const Color(0xFF6B442D);
    }

    if (lower.contains('phantom')) {
      return const Color(0xFF9C6B3F);
    }

    if (lower.contains('cream')) {
      return const Color(0xFFF2E2C4);
    }

    if (lower.contains('black')) {
      return Colors.black87;
    }

    if (lower.contains('apricot')) {
      return const Color(0xFFE7B56A);
    }

    return Colors.grey;
  }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "🎨 Expected Coat Colour Outcomes",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              child: Column(
                children: [
                  SizedBox(
                    height: 320,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            centerSpaceRadius: 48,
                            sectionsSpace: 3,
                            sections: entries.map((e) {
                              final value = e.value.toDouble();

                              return PieChartSectionData(
                                value: value,
                                color: sectionColor(e.key),
                                title: "${value.toInt()}%",
                                radius: 58,
                                titleStyle: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: e.key.toLowerCase().contains('caramel')
                                      ? Colors.black
                                      : Colors.white,
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              puppyGrade,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              coatType,
                              style: const TextStyle(
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // legend moved BELOW wheel
                  Column(
                    children: [
                      Column(
                        children: entries.map((e) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _legendRow(
                              e.key,
                              "${e.value.toInt()}%",
                              sectionColor(e.key),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
    ///
    Widget _legendRow(
    String title,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
}
///
///
  bool hasTanPoints(String? a) {
    if (a == null) return false;

    return a.contains('at');
  }

  bool allowsAExpression(String? k) {
    if (k == null) return false;

    return k.contains('ky');
  }

  bool phantomPossible(
    String? fA,
    String? mA,
    String? fK,
    String? mK,
  ) {
    final aOk =
        hasTanPoints(fA) || hasTanPoints(mA);

    final kOk =
        allowsAExpression(fK) || allowsAExpression(mK);

    return aOk && kOk;
  }
///
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

    final activeFlow = widget.plan['active_flow'];
    final isActiveFlow = activeFlow != null;

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Card(
      color: isActiveFlow ? const Color(0xFFFFF8EA) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActiveFlow ? const Color(0xFFD4AF37) : Colors.grey.shade200,
          width: isActiveFlow ? 2 : 1,
        ),
      ),
      elevation: isActiveFlow ? 8 : 6,
        shadowColor: Colors.black.withOpacity(0.1),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
            colors: isActiveFlow
                ? [
                    const Color(0xFFFFF8EA),
                    const Color(0xFFFFEBC2),
                  ]
                : [
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
              if (isActiveFlow) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'ACTIVE FLOW',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Stage: ${activeFlow?['current_stage'] ?? 'Active'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
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
                //      const SizedBox(height: 12),
                //      _buildDNAIndicators(female, male),
                //      const SizedBox(height: 12),
                //      _buildDNASummary(female, male),
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
                      _buildComparison(female, male),
                      const SizedBox(height: 12),
                      _buildActions(
                        female,
                        male,
                        plan,
                      ),
                      
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

    // the Paw in between
        FutureBuilder(
          future: Future.wait([
            _getDNA(female['id']),
            _getDNA(male['id']),
          ]),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Icon(Icons.pets, size: 40, color: Colors.grey);
            }

            final femaleDNA = snapshot.data![0] as List;
            final maleDNA   = snapshot.data![1] as List;

            final femaleHasDNA = femaleDNA.isNotEmpty;
            final maleHasDNA   = maleDNA.isNotEmpty;

            final bothHaveDNA = femaleHasDNA && maleHasDNA;

            final hasMissingDNA = !bothHaveDNA;

            return GestureDetector(
              onTap: () {
                if (hasMissingDNA) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("⚠️ Missing DNA"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Icon(
                Icons.pets,
                size: 40,
                color: bothHaveDNA ? Colors.green : Colors.red,
              ),
            );
          },
        ),

        const SizedBox(width: 12),

        Expanded(child: _dogCard(male)),
      ],
    );
  }
//        Get Health Status
  Map<String, String> getHealthStatus(Map<String, dynamic> dogHealth) {
    final result = <String, String>{};

    for (final entry in dogHealth.entries) {
      final test = entry.key;
      final value = entry.value?.toString().toLowerCase();

      if (value == 'clear') result[test] = 'clear';
      if (value == 'carrier') result[test] = 'carrier';
      if (value == 'affected') result[test] = 'affected';
    }

    return result;
  }
//
  Widget _buildActions(
    Map<String, dynamic> female,
    Map<String, dynamic> male,
    Map<String, dynamic> plan,
  )
 {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _actionButton(
                icon: activeFlow != null ? Icons.timeline : Icons.favorite,
                label: activeFlow != null ? "Flow" : "Start",
                color: activeFlow != null ? const Color(0xFFD4AF37) : Colors.pink,
                onTap: () async {
                  if (activeFlow != null) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FlowDetailPage(
                          flowId: activeFlow!['id'],
                        ),
                      ),
                    );

                    await _loadActiveFlow();
                    return;
                  }

                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StartFlowPage(
                        femaleDog: widget.female,
                        breedingPlan: plan,
                        maleDog: widget.male,
                      ),
                    ),
                  );

                  await _loadActiveFlow();
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BreedingPairDnaPage(
                        female: female,
                        male: male,
                        plan: plan,
                      ),
                    ),
                  );
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
                onTap: () async {
                  await BreedingReportServiceV2()
                      .generateAndShareReport(
                    femaleDog: female,
                    maleDog: male,
                    breedingPlan: plan,
                  );
                },
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

        final fDNA = _dnaToMap(femaleDNA);
        final mDNA = _dnaToMap(maleDNA);

        return Column(
          children: [
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
  Widget noseBadge(String? value) {
    final display = displayNose(value);

    Color bgColor;
    Color textColor = Colors.white;

    switch (value?.toLowerCase()) {
      case 'liver':
        bgColor = Colors.brown;
        break;
      case 'black':
        bgColor = Colors.black;
        break;
      default:
        bgColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.4), // 👈 subtle border
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        display.isEmpty ? '-' : display,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  //
  Widget _buildComparison(
    Map<String, dynamic> female,
    Map<String, dynamic> male,
  ) {
    return Column(
      children: [
        _row(
          "Size",
          Text(female['size']?.toString() ?? '-'),
          Text(male['size']?.toString() ?? '-'),
        ),

        _row(
          "Colour",
          Text(
            "${female['colour'] ?? '-'}"
            "${(female['second_colour'] ?? '').toString().isNotEmpty ? ' / ${female['second_colour']}' : ''}",
          ),
          Text(
            "${male['colour'] ?? '-'}"
            "${(male['second_colour'] ?? '').toString().isNotEmpty ? ' / ${male['second_colour']}' : ''}",
          ),
        ),

        _row(
          "Gen",
          Text(female['ala_grade']?.toString() ?? '-'),
          Text(male['ala_grade']?.toString() ?? '-'),
        ),

        _row(
          "Coat",
          Text(female['coat_type']?.toString() ?? '-'),
          Text(male['coat_type']?.toString() ?? '-'),
        ),

        FutureBuilder(
          future: Future.wait([
            _getDNA(female['id']),
            _getDNA(male['id']),
            _getNose(female['id']),
            _getNose(male['id']),
            _getHealth(female['id']),
            _getHealth(male['id']),
          ]),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Text("Loading...");
            }

            final fDNA = _dnaToMap(
              snapshot.data![0] as List<Map<String, dynamic>>,
            );

            final mDNA = _dnaToMap(
              snapshot.data![1] as List<Map<String, dynamic>>,
            );
            final puppyGrade = _calculatePuppyAlaGrade(
              female['ala_grade'] ?? '',
              male['ala_grade'] ?? '',
            );

            final fNose = snapshot.data![2] as String?;
            final mNose = snapshot.data![3] as String?;

            final femaleHealth =
                snapshot.data![4] as Map<String, String>;

            final maleHealth =
                snapshot.data![5] as Map<String, String>;

            final warnings =
                GeneticsService.breedingWarnings(fDNA, mDNA);

            final healthWarnings =
                buildHealthWarnings(
                  femaleHealth,
                  maleHealth,
                );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildColourWheel(
                  fDNA,
                  mDNA,
                  puppyGrade,
                  female['coat_type'] ?? 'Fleece',
                ),

                const SizedBox(height: 16),

       /*
                _buildTraitProgressCard(
                  fDNA,
                  mDNA,
                ),

                const SizedBox(height: 16),
      */
                _row(
                  "Nose",
                  noseBadge(fNose),
                  noseBadge(mNose),
                ),

                const SizedBox(height: 12),
/*
                _row(
                  "A Locus",
                  Text(fDNA['A'] ?? '-'),
                  Text(mDNA['A'] ?? '-'),
                ),

                _row(
                  "B Locus",
                  Text(fDNA['B'] ?? '-'),
                  Text(mDNA['B'] ?? '-'),
                ),

                _row(
                  "E Locus",
                  Text(fDNA['E'] ?? '-'),
                  Text(mDNA['E'] ?? '-'),
                ),

                 _row(
                  "K Locus",
                  Text(fDNA['K'] ?? '-'),
                  Text(mDNA['K'] ?? '-'),
                ),

                _row(
                  "M Locus",
                  Text(fDNA['M'] ?? '-'),
                  Text(mDNA['M'] ?? '-'),
                ),

                _row(
                  "S Locus",
                  Text(fDNA['S'] ?? '-'),
                  Text(mDNA['S'] ?? '-'),
                ),
                const SizedBox(height: 12),
    */

                Center(
                  child: Text(
                    "Expected Puppy Grade: $puppyGrade",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                BreedingSummarySection(
                  femaleDNA: fDNA,
                  maleDNA: mDNA,
                  sharedAncestors: const [],
                  femaleName: female['dog_name'] ?? '',
                  maleName: male['dog_name'] ?? '',
                ),

                const SizedBox(height: 12),

                if (warnings.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: warnings.map((w) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 2,
                          ),
                          child: Text(
                            w,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                if (healthWarnings.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: healthWarnings.map((w) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 2,
                          ),
                          child: Text(
                            w,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            );
          },
        ),
        
        
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

    ////////////////////
    ///.  Get Health ///
    ////////////////////
    Future<Map<String, String>> _getHealth(String dogId) async {
      try {
        final res = await Supabase.instance.client
            .from('dna_health')
            .select()
            .eq('dog_id', dogId);

        final map = <String, String>{};

        for (final row in res) {
          final test = row['test_name'];
          final result = row['result'];

          if (test != null && result != null) {
            map[test] = result.toString().toLowerCase();
          }
        }

        return map;
      } catch (e) {
        print("HEALTH FETCH ERROR: $e");
        return {};
      }
    }
    ///

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

    // =====================================
    // Default assumed values if not supplied
    // =====================================

    if (!map.containsKey('S')) {
      map['S'] = '(S/S) Assumed';
    }

    if (!map.containsKey('M')) {
      map['M'] = '(m/m) Assumed';
    }

    return map;
  }

  String _dnaToString(List<Map<String, dynamic>> dna) {
    return dna.map((d) {
      return "${d['locus']} ${d['allele_1']}/${d['allele_2']}";
    }).join(', ');
  }
//;;
  Widget _row(String label, Widget left, Widget right) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: left),
          Expanded(child: right),
        ],
      ),
    );
  }
  /////////////////////////////////////
  //..     Build Health Warnings.   ///
  /////////////////////////////////////
   List<String> buildHealthWarnings(
      Map<String, String> female,
      Map<String, String> male,
    ) {
      final warnings = <String>[];

      final tests = {...female.keys, ...male.keys};

      for (final test in tests) {
        final f = female[test];
        final m = male[test];

        if (f == 'affected' || m == 'affected') {
          warnings.add("🚨 $test: Affected present — DO NOT BREED");
        } else if (f == 'carrier' && m == 'carrier') {
          warnings.add("⚠ $test: Carrier × Carrier risk");
        }
      }

      return warnings;
    } 
    
  // ==============================
  // 🧬 DNA PARSE + COLOUR ENGINE
  // ==============================

  List<String> _splitAlleles(String genotype) {
    return genotype.split('/');
  }

  Map<String, double> _punnettSquare(String f, String m) {
    final fAlleles = _splitAlleles(f);
    final mAlleles = _splitAlleles(m);

    final results = <String, double>{};

    for (var fa in fAlleles) {
      for (var ma in mAlleles) {
        final combo = [fa, ma]..sort();
        final key = "${combo[0]}/${combo[1]}";

        results[key] = (results[key] ?? 0) + 0.25;
      }
    }

    return results;
  }
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
    if (text.toLowerCase().contains('kb/ky') ||
    text.toLowerCase().contains('kb / ky')) {
      result['K'] = 'kb/ky';
    } else if (text.toLowerCase().contains('ky/ky')) {
      result['K'] = 'ky/ky';
    } else if (text.toLowerCase().contains('kb/kb')) {
      result['K'] = 'kb/kb';
    }
    result['A'] = extract("A Locus", r'(ay/at|at/a|ay/a|a/a)') ?? '';

    result['S'] = extract("Pied", r'(S/S|S/s|s/s)') ?? '';
    result['M'] = extract("Merle", r'(m/m|M/m|M/M)') ?? 'm/m';

    return result;
  }
}