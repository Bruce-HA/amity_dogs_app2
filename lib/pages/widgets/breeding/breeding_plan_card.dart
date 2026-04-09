import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/app_dog_image.dart';

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

    return GestureDetector(
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
              // 🧬 BREEDING CODE
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
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const SizedBox(height: 10),
              const SizedBox(height: 8),

              // 🐶 HEADER
              _buildHeader(female, male),

              // 🔽 EXPANDABLE CONTENT
              if (_expanded) ...[
                const SizedBox(height: 12),

                _buildSummary(female, male, plan),

                const SizedBox(height: 12),

                _buildDNAIndicators(female, male),

                const SizedBox(height: 12),
                _buildDNASummary(female, male),
                
                const SizedBox(height: 12),
                _buildColourPrediction(female, male), // 👈 IMPORTANT

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
    final femaleHasDNA = female['has_dna_summary'] == true;
    final maleHasDNA = male['has_dna_summary'] == true;

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () async {
              if (femaleHasDNA) {
                await _ensureDNAParsed(female['id']);
                setState(() {});
              } else {
                // your existing upload logic here
              }
            },
            child: _dnaBadge("Female", femaleHasDNA),
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: GestureDetector(
            onTap: () async {
              if (maleHasDNA) {
                await _ensureDNAParsed(male['id']);
                setState(() {});
              } else {
                // your existing upload logic here
              }
            },
            child: _dnaBadge("Male", maleHasDNA),
          ),
        ),
      ],
    );
  }
//...
  Widget _buildDNASummary(
    Map<String, dynamic> female,
    Map<String, dynamic> male,
  ) {
    return FutureBuilder(
      future: Future.wait([
        _getDNA(female['id']),
        _getDNA(male['id']),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final femaleDNA = snapshot.data![0] as List<Map<String, dynamic>>;
        final maleDNA = snapshot.data![1] as List<Map<String, dynamic>>;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "DNA Summary",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "♀ ${female['pet_name'] ?? female['dog_name']}",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  femaleDNA.isEmpty ? 'No DNA' : _dnaToString(femaleDNA),
                ),

                const SizedBox(height: 6),

                Text(
                  "♂ ${male['pet_name'] ?? male['dog_name']}",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  maleDNA.isEmpty ? 'No DNA' : _dnaToString(maleDNA),
                ),
              ],
            )
          ],
        );
      },
    );
  }
//...
  Widget _dnaBadge(String label, bool hasDNA) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: hasDNA
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasDNA ? Icons.check_circle : Icons.warning,
            size: 16,
            color: hasDNA ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 6),
          Text(
            "$label DNA",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: hasDNA ? Colors.green : Colors.red,
            ),
          ),
        ],
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
        _row("Colour", female['colour'], male['colour']),
        // 👇 NEW LINE
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
  Future<void> _ensureDNAParsed(String dogId) async {
    final supabase = Supabase.instance.client;

    final existing = await supabase
        .from('dna_bank')
        .select()
        .eq('dog_id', dogId);

    if (existing.isNotEmpty) return;

    final report = await supabase
        .from('dna_reports')
        .select()
        .eq('dog_id', dogId)
        .eq('is_active', true)
        .maybeSingle();

    if (report == null) return;

    final url = report['report_url'];

    // 🔥 TEMP: fetch text (you will replace with real PDF parser later)
    //final text = await _fetchPdfText(url);
    final text = '''
      E Locus - e/e
      Brown - B/b
      D Locus - D/D
      K Locus - KB/ky
      A Locus - ay/at
      ''';

    final loci = _parseOrivet(text);

    await supabase.from('dna_bank').delete().eq('dog_id', dogId);

    for (final entry in loci.entries) {
      final parts = entry.value.split('/');

      await supabase.from('dna_bank').insert({
        'dog_id': dogId,
        'dog_name': 'AUTO',
        'locus': entry.key,
        'allele_1': parts[0],
        'allele_2': parts.length > 1 ? parts[1] : parts[0],
      });
    }
  }
///>
  Future<List<Map<String, dynamic>>> _getDNA(String dogId) async {
    final res = await Supabase.instance.client
        .from('dna_bank')
        .select()
        .eq('dog_id', dogId);

    return List<Map<String, dynamic>>.from(res);
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

  Map<String, int> _predictColours(String femaleDNA, String maleDNA) {
    final f = _parseDNA(femaleDNA);
    final m = _parseDNA(maleDNA);

    final results = <String, int>{};

    final fE = f['E'] ?? '';
    final mE = m['E'] ?? '';

    // Cream (e/e)
    if (fE.contains('E') == false && mE.contains('E') == false) {
      results['Cream'] = 100;
      return results;
    }

    // Carrier
    if (fE.contains('E') == false || mE.contains('E') == false) {
      results['Cream'] = 50;
    }

    final fB = f['B'] ?? '';
    final mB = m['B'] ?? '';

    if (fB.contains('B') == false && mB.contains('B') == false) {
      results['Chocolate'] = 50;
      results['Black'] = 50;
    } else {
      results['Black'] = 100 - (results['Cream'] ?? 0);
    }

    return results;
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
        if (!snapshot.hasData) return const SizedBox();

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
  //lll
  Map<String, int> _predictColoursFromMap(
    Map<String, String> f,
    Map<String, String> m,
  ) {
    final results = <String, int>{};

    final fE = f['E'] ?? '';
    final mE = m['E'] ?? '';

    final fB = f['B'] ?? '';
    final mB = m['B'] ?? '';

    // 🧬 Cream (e/e)
    if (fE == 'e/e' && mE == 'e/e') {
      results['Cream'] = 100;
      return results;
    }

    // 🧬 Carrier
    if (fE.contains('e') || mE.contains('e')) {
      results['Cream'] = 50;
    }

    // 🧬 Chocolate
    if (fB.contains('b') && mB.contains('b')) {
      results['Chocolate'] = 50;
      results['Black'] = 50;
    } else {
      results['Black'] = 100 - (results['Cream'] ?? 0);
    }

    return results;
  }
  //ll
  //''
  Map<String, String> _parseOrivet(String text) {
    final result = <String, String>{};

    String? extract(String pattern) {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(text);
      return match?.group(1);
    }

    // ✅ MUCH SIMPLER + ROBUST MATCHING

    result['E'] = extract(r'E.*?([Ee]/[Ee])') ?? '';
    result['B'] = extract(r'B.*?([Bb]/[Bb])') ?? '';
    result['D'] = extract(r'D.*?([Dd]/[Dd])') ?? '';
    result['K'] = extract(r'K.*?(KB/ky|ky/ky|KB/KB)') ?? '';
    result['A'] = extract(r'A.*?([a-z]{1,2}/[a-z]{1,2})') ?? '';

    return result;
  }
  //''
}