import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/app_dog_image.dart';
import 'package:amity_dogs_app/pages/dna/dna_input_page.dart';

class BreedingPlanCard extends StatefulWidget {
  final Map<String, dynamic> female;
  final Map<String, dynamic> male;
  final Map<String, dynamic> plan;

  const BreedingPlanCard({
    super.key,
    required this.female,
    required this.male,
    required this.plan,
  });

  @override
  State<BreedingPlanCard> createState() => _BreedingPlanCardState();
}

class _BreedingPlanCardState extends State<BreedingPlanCard> {
  
  bool _expanded = false;

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
        ),
        elevation: 3,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
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
                _buildSummary(female, male, plan),
                const SizedBox(height: 12),
                _buildDNAIndicators(female, male),
                const SizedBox(height: 12),
                _buildDNASummary(female, male),
                const SizedBox(height: 12),
                _buildColourPrediction(female, male),
                const SizedBox(height: 12),
                _buildComparison(female, male),
                const SizedBox(height: 12),
                _buildActions(plan),
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
                onTap: () {
                  print("Start mating ${plan['breeding_plan_code']}");
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
                onTap: () {
                  print("Edit ${plan['breeding_plan_code']}");
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _actionButton(
                icon: Icons.share,
                label: "Share",
                color: Colors.green,
                onTap: () {
                  print("Share ${plan['breeding_plan_code']}");
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
//..
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
    final dogAla = dog['dog_ala'];
    final dogId = dog['id'];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppDogImage(
          dogId: dogId,
          dogAla: dogAla,
          size: 84,       // 🔥 50% larger
          radius: 16,     // 🔥 softer look
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
        
        Row(
          children: [
            Expanded(child: _stat("IBC", plan['ibc'] ?? "--", "")),
            Expanded(child: _stat("ALA IBC", plan['ala_ibc'] ?? "--", "")),
          ],
        ),
        const SizedBox(height: 8),
      
      ],
    );
  }

  Widget _stat(String label, dynamic femaleVal, dynamic maleVal) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          "$femaleVal${maleVal != "" ? " / $maleVal" : ""}",
          style: const TextStyle(fontWeight: FontWeight.bold),
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
        _row(
          "Nose",
          female['nose_colour'] ?? '-',
          male['nose_colour'] ?? '-',
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