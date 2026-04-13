import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pages/breeding/litters_page.dart';
import '../utils/date_utils.dart';
import '../pages/select_male_page.dart';
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

  Future<void> loadData() async {
    final dogResult = await supabase
        .from('dogs')
        .select('dog_ala')
        .eq('id', widget.dogId)
        .maybeSingle();

    if (dogResult == null) return;

    final dogAla = dogResult['dog_ala'];

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

  Future<void> loadPlans() async {
    final dogResult = await supabase
        .from('dogs')
        .select('dog_ala')
        .eq('id', widget.dogId)
        .single();

    final dogAla = dogResult['dog_ala'];

    final response = await supabase
        .from('breeding_plans')
        .select()
        .eq('female_dog_ala', dogAla)
        .order('created_at', ascending: false);

    setState(() {
      plans = List<Map<String, dynamic>>.from(response);
      loadingPlans = false;
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

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Breeding Plans',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              ElevatedButton(
                onPressed: () async {
                  final selectedMale = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SelectMalePage(),
                    ),
                  );

                  if (selectedMale == null) return;

                  final dogResult = await supabase
                      .from('dogs')
                      .select('dog_ala')
                      .eq('id', widget.dogId)
                      .single();

                  final femaleAla = dogResult['dog_ala'];

                  final existing = await supabase
                      .from('breeding_plans')
                      .select('breeding_plan_code')
                      .eq('female_dog_ala', femaleAla);

                  int nextNumber = existing.length + 1;

                  final code =
                      '$femaleAla-B${nextNumber.toString().padLeft(2, '0')}';

                  await supabase.from('breeding_plans').insert({
                    'female_dog_ala': femaleAla,
                    'male_dog_ala': selectedMale,
                    'breeding_plan_code': code,
                    'status': 'planned',
                    'is_active': true,
                  });

                  await loadPlans();
                },
                child: const Text('+ Create'),
              ),
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
              coat,
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
              coat,
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
                  _sharedFieldsBlock(),

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
          .select('id, dog_name, pet_name, dob, size, colour, has_dna_summary, hip_score, pennhip, ala_grade')
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
 ///. Shared Field Block
  Widget _sharedFieldsBlock() {
    return Column(
      children: const [
        Divider(),
        SizedBox(height: 8),

        Text('Shared Fields',
            style: TextStyle(fontWeight: FontWeight.bold)),

        SizedBox(height: 12),

        Text('🧬 IBC: --'),
        Text('📊 ALA IBC: --'),

        SizedBox(height: 12),

        Text('Expected',
            style: TextStyle(fontWeight: FontWeight.w600)),

        SizedBox(height: 4),

        Text('🎨 Pup Colours'),
        Text('30% Chocolate'),
        Text('50% Cream'),
        Text('20% Black'),
      ],
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
