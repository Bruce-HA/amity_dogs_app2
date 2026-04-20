import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pages/breeding/litters_page.dart';
import '../utils/date_utils.dart';
import '../pages/select_male_page.dart';
import '../pages/select_female_page.dart';
import '../pages/widgets/breeding/breeding_plan_card.dart';
import 'package:amity_dogs_app/pages/dna/dna_input_page.dart';
import '../../tabs/dna_tab.dart';
import '../pages/dna/dna_display_page.dart';

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

  List<Map<String, dynamic>> plans = [];
  bool loadingPlans = true;

  int litterCount = 0;
  int maleCount = 0;
  int femaleCount = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
    loadPlans();
  }
///DD
   Future<double?> _calculateIBC(String femaleAla, String maleAla) async {
    try {
      print("IBC CALL → female: $femaleAla | male: $maleAla");

      final femalePedigree = await supabase.rpc(
        'get_simple_pedigree',
        params: {
          'start_ala': femaleAla,
          'max_generations': 5,
        },
      );

      final malePedigree = await supabase.rpc(
        'get_simple_pedigree',
        params: {
          'start_ala': maleAla,
          'max_generations': 5,
        },
      );

      print("Female pedigree count: ${femalePedigree?.length}");
      print("Male pedigree count: ${malePedigree?.length}");

      if (femalePedigree == null || malePedigree == null) return null;

      final femaleSet = {
        for (var d in femalePedigree) d['dog_ala']
      };

      final maleSet = {
        for (var d in malePedigree) d['dog_ala']
      };

      final shared = femaleSet.intersection(maleSet);

      print("Shared ancestors: ${shared.length}");

      if (shared.isEmpty) return 0.0;

      final score = shared.length / 100;

      return score;
    } catch (e) {
      print("IBC ERROR: $e");
      return null;
    }
  }

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
            hintText: "e.g. 0.12",
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

    setState(() {});
  }
///
///eee
///DD
  Future<void> loadData() async {
    final dogResult = await supabase
        .from('dogs')
        .select('dog_ala, sex')
        .eq('id', widget.dogId)
        .single();


print("SEX VALUE → '${dogResult['sex']}'"); // 👈 ADD THIS LINE

    if (dogResult == null) return;

    final dogAla = dogResult['dog_ala'];
    final currentAla = dogResult['dog_ala'];
    final sex = dogResult['sex'];
    final damLitters = await supabase
        .from('litters')
        .select('male_count, female_count')
        .eq('dam_ala', dogAla);

    final sireLitters = await supabase
        .from('litters')
        .select('male_count, female_count')
        .eq('sire_ala', dogAla);

    final List data = [...damLitters as List, ...sireLitters as List];

    int m = 0;
    int f = 0;

    for (var litter in data) {
      m += (litter['male_count'] ?? 0) as int;
      f += (litter['female_count'] ?? 0) as int;
    }

    setState(() {
      litterCount = data.length;
      maleCount = m;
      femaleCount = f;
      loading = false;
    });
  }
///dd

///dd
  Future<void> loadPlans() async {
    final dogResult = await supabase
        .from('dogs')
        .select('dog_ala, sex')
        .eq('id', widget.dogId)
        .single();

    final dogAla = dogResult['dog_ala'];
    final sexRaw = dogResult['sex']?.toString().toLowerCase().trim();

    List response = [];

    if (sexRaw == 'female') {
      // ✅ Female owns plans
      response = await supabase
          .from('breeding_plans')
          .select()
          .eq('female_dog_ala', dogAla)
          .order('created_at', ascending: false);
    } else {
      // ✅ Male sees plans
      response = await supabase
          .from('breeding_plans')
          .select()
          .eq('male_dog_ala', dogAla)
          .order('created_at', ascending: false);
    }

    setState(() {
      plans = List<Map<String, dynamic>>.from(response);
      loadingPlans = false;
    });
  }
/// Shared Fields Male and Female
  Widget _sharedFields(Map plan) {
    final female = plan['female'];
    final male = plan['male'];
    print("IBC DEBUG → female: ${female['dog_ala']} | male: ${male['dog_ala']}");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),

        const Text(
          'Shared Fields',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        /// 🧬 IBC
        
        FutureBuilder<double?>(
          future: _calculateIBC(
            female['dog_ala'],
            male['dog_ala'],
          ), // 👈 THIS COMMA WAS MISSING
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Text('🧬 IBC: ...');
            }

            final value = snapshot.data;

            return Text(
              value != null
                  ? '🧬 IBC: ${(value * 100).toStringAsFixed(1)}%'
                  : '🧬 IBC: --',
            );
          },
        ),

        const SizedBox(height: 8),

        /// 📊 ALA IBC
        Row(
          children: [
            const Text('📊 ALA IBC: '),
            Text(plan['ala_ibc']?.toString() ?? '--'),
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
/// 
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

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Breeding Plans',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              ElevatedButton(
                onPressed: () async {
                  late String femaleAla;
                  late String maleAla;

                  final dogResult = await supabase
                      .from('dogs')
                      .select('dog_ala, sex')
                      .eq('id', widget.dogId)
                      .single();

                  final String currentAla = dogResult['dog_ala'] as String;
                  final String sex = dogResult['sex'] as String;

                  if (sex.toLowerCase() == 'female') {
                    final String? selectedMale = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SelectMalePage(),
                      ),
                    );

                    if (selectedMale == null) return;

                    femaleAla = currentAla;
                    maleAla = selectedMale;

                  } else {
                    final String? selectedFemale = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SelectFemalePage(),
                      ),
                    );

                    if (selectedFemale == null) return;

                    femaleAla = selectedFemale;
                    maleAla = currentAla;
                  }

                  final existing = await supabase
                      .from('breeding_plans')
                      .select('breeding_plan_code')
                      .eq('female_dog_ala', femaleAla);

                  final int nextNumber = existing.length + 1;

                  final code =
                      '$femaleAla-B${nextNumber.toString().padLeft(2, '0')}';

                  await supabase.from('breeding_plans').insert({
                    'female_dog_ala': femaleAla,
                    'male_dog_ala': maleAla,
                    'breeding_plan_code': code,
                    'status': 'planned',
                    'is_active': true,
                  });

                  await loadPlans();
                },
                child: const Text('+ Create Breeding Plan'),
              )
            ],
          ),
          const SizedBox(height: 12),

          if (loadingPlans)
            const Center(child: CircularProgressIndicator())
          else if (plans.isEmpty)
            const Text('No breeding plans yet')
          else
            Column(
              children: plans.map(_buildPlanCard).toList(),
            ),

          const SizedBox(height: 16),

          _actionButton(
            context,
            label: 'Matings',
            icon: Icons.favorite,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Matings coming next')),
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
                  builder: (_) => LittersPage(dogId: widget.dogId),
                ),
              );
            },
          ),
//...
          ElevatedButton(
            child: Text("View DNA Report"),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DnaDisplayPage(
                    dogId: widget.dogId,
                    dogName: "DNA Report",
                  ),
                ),
              );
            },
          ),
//;;;
          const SizedBox(height: 12),

          _actionButton(
            context,
            label: 'Record Whelping',
            icon: Icons.child_care,
            isPrimary: true,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Whelping coming next')),
              );
            },
          ),
        ],
      ),
    );
  }
////. ..  ogPreviewFull
  // 👇 ONLY showing the FIXED parts (your top half is fine)

/// 🐶 DOG PREVIEW
Widget _dogPreviewFull(String dogAla) {
    return FutureBuilder(
      future: supabase
          .from('dogs')
          .select('dog_name, pet_name, dob, id, colour, second_colour, nose_colour')
          .eq('dog_ala', dogAla)
          .maybeSingle(),
      builder: (context, snapshot) {
        final data = snapshot.data as Map<String, dynamic>?;

        final name = data?['name'] ?? '-';
        final pet = data?['pet_name'] ?? '-';
        final dob = data?['dob'];
        final dogId = data?['id'];

        final age = dob != null
            ? calculateDogAge(dob.toString())
            : '-';

        return SizedBox(
          width: 140,
          child: Column(
            children: [
              _dogHeroImage(dogId, dogAla),

              const SizedBox(height: 8),

              Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),

              Text(
                pet,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 4),

              Text(age, style: const TextStyle(fontSize: 12)),

              const SizedBox(height: 4),

              Text(
                dogAla,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 🐶 HERO IMAGE (FIXED PROPERLY)
  Widget _dogHeroImage(String? dogId, String dogAla) {
    // 🟡 fallback (no dog id yet)
    if (dogId == null) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const AspectRatio(
          aspectRatio: 4 / 3,
          child: Center(child: Icon(Icons.pets)),
        ),
      );
    }

    return FutureBuilder(
      future: supabase
          .from('dog_photos')
          .select('url, is_hero')
          .eq('dog_id', dogId),
      builder: (context, snapshot) {
        final photos = (snapshot.data as List?)
            ?.cast<Map<String, dynamic>>();

        if (photos == null || photos.isEmpty) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const AspectRatio(
              aspectRatio: 4 / 3,
              child: Center(child: Icon(Icons.pets)),
            ),
          );
        }

        final hero = photos.firstWhere(
          (p) => p['is_hero'] == true,
          orElse: () => photos.first,
        );

        final rawUrl = hero['url'];

        if (rawUrl == null || rawUrl.isEmpty) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const AspectRatio(
              aspectRatio: 4 / 3,
              child: Center(child: Icon(Icons.pets)),
            ),
          );
        }

        // 🔥 BUILD CORRECT URL
        final path = '$dogAla/photos/$rawUrl';

        final finalUrl = supabase.storage
            .from('dog_files')
            .getPublicUrl(path);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(
                finalUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(child: Icon(Icons.pets));
                },
              ),
            ),
          ),
        );
      },
    );
  }
///. dogHeroImage

  // 🧬 PLAN CARD
  Widget _buildPlanCard(Map<String, dynamic> plan) {
    return FutureBuilder(
      future: Future.wait([
        // 👇 FEMALE
        supabase
            .from('dogs')
            .select('''
              id,
              dog_name,
              pet_name,
              dog_ala,
              size,
              colour,
              second_colour,
              nose_colour,
              coat_type,
              hip_score,
              pennhip,
              ala_grade,
              dna_summary,
              has_dna_summary
            ''')
            .eq('dog_ala', plan['female_dog_ala'])
            .maybeSingle(),

        // 👇 MALE
        supabase
            .from('dogs')
            .select('''
              id,
              dog_name,
              pet_name,
              dog_ala,
              size,
              colour,
              second_colour,
              nose_colour,
              coat_type,
              hip_score,
              pennhip,
              ala_grade,
              dna_summary,
              has_dna_summary
            ''')
            .eq('dog_ala', plan['male_dog_ala'])
            .maybeSingle(),
      ]),
      builder: (context, snapshot) {
        // 🔴 ERROR HANDLING (CRITICAL)
        if (snapshot.hasError) {
          print("PLAN CARD ERROR: ${snapshot.error}");
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text("Error loading breeding plan"),
          );
        }

        // 🟡 LOADING
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final female = snapshot.data![0] as Map<String, dynamic>?;
        final male   = snapshot.data![1] as Map<String, dynamic>?;

        // 🔴 NULL SAFETY
        if (female == null || male == null) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text("Missing dog data"),
          );
        }

        return BreedingPlanCard(
          female: female,
          male: male,
          plan: plan,
          currentDogId: widget.dogId, // 👈 ADD THIS
        );
      },
    );
  }

  // 📄 DETAIL MODAL
  void _openPlanDetail(Map<String, dynamic> plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.85,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // 🧬 PLAN CODE
                  Text(
                    plan['breeding_plan_code'] ?? '',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),

                  const SizedBox(height: 16),

                  // 🐶 PAIR
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _dogDetailBlock(plan['female_dog_ala']),
                      const Text('×'),
                      _dogDetailBlock(plan['male_dog_ala']),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 🧬 SHARED FIELDS
                  _sharedFields(plan),

                  const SizedBox(height: 24),

                  // ⚖️ COMPARISON
                  _comparisonBlock(
                    plan['female_dog_ala'],
                    plan['male_dog_ala'],
                  ),

                  const SizedBox(height: 24),

                  // 🔘 ACTIONS
                  _actionButton(
                    context,
                    label: '❤️ Start Mating',
                    icon: Icons.favorite,
                    isPrimary: true,
                    onTap: () {},
                  ),

                  _actionButton(
                    context,
                    label: '🧬 DNA Pair Report',
                    icon: Icons.science,
                    onTap: () {},
                  ),

                  _actionButton(
                    context,
                    label: '✏️ Edit Plan',
                    icon: Icons.edit,
                    onTap: () {},
                  ),

                  _actionButton(
                    context,
                    label: '📤 Print / Share Plan',
                    icon: Icons.share,
                    onTap: () {},
                  ),

                  const SizedBox(height: 8),

                  // 🗑 ADMIN DELETE
                  TextButton(
                    onPressed: () async {
                      await supabase
                          .from('breeding_plans')
                          .delete()
                          .eq('id', plan['id']);

                      Navigator.pop(context);
                      loadPlans();
                    },
                    child: const Text(
                      '🗑 Delete Plan',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
 ///... Dog Details Block
  Widget _dogDetailBlock(String dogAla) {
    
    return FutureBuilder(
      future: supabase
          .from('dogs')
          .select('id, dog_name, pet_name, dob, size, coat_type, colour, has_dna_summary, hip_score, pennhip, ala_grade')
          .eq('dog_ala', dogAla)
          .maybeSingle(),
      builder: (context, snapshot) {
        final data = snapshot.data as Map<String, dynamic>?;

        final name = data?['name'] ?? '-';
        final pet = data?['pet_name'] ?? '-';
        final age = calculateDogAge(data?['dob']?.toString());
        final size = data?['size'] ?? '-';

        return SizedBox(
          width: 140,
          child: Column(
            children: [
              _dogHeroImage(data?['id'], dogAla),

              const SizedBox(height: 8),

              Text(name, textAlign: TextAlign.center),
              //....
              const SizedBox(height: 4),

                Text(
                  "${data?['colour'] ?? '-'}"
                  "${data?['second_colour'] != null ? ' / ${data?['second_colour']}' : ''}",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),

                Text(
                  "Nose: ${data?['nose_colour'] ?? '-'}",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              //....
              Text(pet, style: const TextStyle(color: Colors.grey)),

              const SizedBox(height: 4),

              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DnaInputPage(
                        dogId: data?['id'],
                        dogName: data?['dog_name'],
                      ),
                    ),
                  );

                  if (result == true) {
                    await loadPlans();   // 🔥 wait for fresh data
                    setState(() {});
                  }
                },
                child: Text(
                  data?['has_dna_summary'] == true
                      ? '🧬 DNA ✅'
                      : '🧬 DNA ❌ ⬆️ Upload',
                  style: TextStyle(
                    fontSize: 12,
                    color: data?['has_dna_summary'] == true
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ),

              const SizedBox(height: 4),

              Text(dogAla,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        );
      },
    );
  }

 ///
 ///-----Comparision Block
  Widget _comparisonBlock(String femaleAla, String maleAla) {
    return FutureBuilder(
      future: Future.wait([
        supabase.from('dogs').select().eq('dog_ala', femaleAla).maybeSingle(),
        supabase.from('dogs').select().eq('dog_ala', maleAla).maybeSingle(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final female =
            snapshot.data![0] as Map<String, dynamic>?;
        final male =
            snapshot.data![1] as Map<String, dynamic>?;

        // 🛑 safety check
        if (female == null || male == null) {
          return const SizedBox();
        }

        Widget row(String label, dynamic f, dynamic m) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(width: 100, child: Text('$f')),
                Expanded(child: Center(child: Text(label))),
                SizedBox(width: 100, child: Text('$m', textAlign: TextAlign.end)),
              ],
            ),
          );
        }

        return Column(
          children: [
            const Divider(),
            const SizedBox(height: 8),

            const Text('Comparison',
                style: TextStyle(fontWeight: FontWeight.bold)),

            const SizedBox(height: 12),

            row('Size', female['size'] ?? '-', male['size'] ?? '-'),
            row(
              'Colour',
              "${female['colour'] ?? '-'}"
              "${(female['second_colour'] ?? '').toString().isNotEmpty ? ' / ${female['second_colour']}' : ''}",
              "${male['colour'] ?? '-'}"
              "${(male['second_colour'] ?? '').toString().isNotEmpty ? ' / ${male['second_colour']}' : ''}" , 
            ),

            row(
              'Nose',
              female['nose_colour'] ?? '-',
              male['nose_colour'] ?? '-',
            ),
            row(
              'DNA',
              female['has_dna_summary'] == true ? '🧬 ✅' : '🧬 ❌',
              male['has_dna_summary'] == true ? '🧬 ✅' : '🧬 ❌',
            ),
            row('Hips', female['hip_score'] ?? '-', male['hip_score'] ?? '-'),

          row('🩻 PennHIP', female['pennhip'] ?? '-', male['pennhip'] ?? '-'),

          row('ALA', female['ala_grade'] ?? '-', male['ala_grade'] ?? '-'),
          ],
        );
      },
    );
  }
 ///  Action Button
  Widget _actionButton(
  BuildContext context, {
  required String label,
  required IconData icon,
  required VoidCallback onTap,
  bool isPrimary = false,
}) {
  final theme = Theme.of(context);

  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isPrimary
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isPrimary
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isPrimary
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isPrimary
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    ),
  );
}
////
  Future<String?> _selectMaleDialog() async {
    final response = await supabase
        .from('dogs_list_view_with_hero')
        .select('dog_ala, dog_name, sex, hero')
        .order('dog_name');

    final allDogs = (response as List)
        .cast<Map<String, dynamic>>();

    // 🔥 DEBUG — show EXACT raw names
    for (var d in allDogs.take(20)) {
      //... Delete me ..print("DOG RAW: ${d['dog_name']}");
    }

    List<Map<String, dynamic>> filtered = List.from(allDogs);

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Column(
              children: [
                // 🔍 SEARCH
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search dog...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      final query = value
                          .toLowerCase()
                          .replaceAll('\u00A0', ' ')
                          .trim();

                      setModalState(() {
                        if (query.isEmpty) {
                          filtered = List.from(allDogs);
                          return;
                        }

                        filtered = allDogs.where((dog) {
                          final rawName =
                              (dog['dog_name'] ?? '').toString();

                          final cleanName = rawName
                              .toLowerCase()
                              .replaceAll('\u00A0', ' ')
                              .trim();

                          final ala = (dog['dog_ala'] ?? '')
                              .toString()
                              .toLowerCase()
                              .trim();

                          return cleanName.contains(query) ||
                              ala.contains(query);
                        }).toList();
                      });
                    },
                  ),
                ),

                // 📋 LIST WITH HERO
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final dog = filtered[index];

                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: dog['hero'] != null
                              ? Image.network(
                                  dog['hero'],
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.pets),
                                ),
                        ),
                        title: Text(dog['dog_name'] ?? '-'),
                        subtitle: Text(
                            "${dog['dog_ala']} • ${dog['sex']}"),
                        onTap: () {
                          Navigator.pop(context, dog['dog_ala']);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
