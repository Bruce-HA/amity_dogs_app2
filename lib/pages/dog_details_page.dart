import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/date_utils.dart';
import '../tabs/dog_breeding_tab.dart';
import '../tabs/dog_photos_tab.dart';
import '../tabs/dog_files_tab.dart';
import '../tabs/dog_notes_tab.dart';
import '../tabs/genetics_tab.dart';
import 'dog_edit_page.dart';
import 'people_detail_page.dart';
import 'widgets/dog_card.dart';
import '../ui/spay_due_label.dart';
import '../../dev/dev_info_panel.dart';
import 'dna/dna_input_page.dart';


class DogDetailsPage extends StatefulWidget {
  final String dogId;

  const DogDetailsPage({
    super.key,
    required this.dogId,
  });

  @override
  State<DogDetailsPage> createState() => _DogDetailsPageState();
}

class _DogDetailsPageState extends State<DogDetailsPage> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? dog;
  Map<String, dynamic>? breeder;
  Map<String, dynamic>? owner;
  Map<String, dynamic>? mother;
  Map<String, dynamic>? father;

  String? heroUrl;

  int selectedTab = 0;
  List<String> tabs = [];

  int litterCount = 0;
  int puppyCount = 0;
  int maleCount = 0;
  int femaleCount = 0;

  List<String> getTabs() {
    if (dog == null) return [];

    final status = dog!['status']?.toString();

    final tabs = [
      'Overview',
      'Photos',
      'Genetics', // ⭐ NEW
      'Notes',
      'Files',
    ];

    if (status != 'Pet') {
      tabs.insert(3, 'Breeding');
    }

    return tabs;
  }

  @override
  void initState() {
    super.initState();
    loadDog();
  }

  Future<void> loadDog() async {
    final dogResult = await supabase
        .from('dogs_with_hero')
        .select()
        .eq('id', widget.dogId)
        .maybeSingle();

    if (dogResult == null) return;
    print("DOG RESULT:");
    print(dogResult);


    String? newHeroUrl = dogResult['hero']?.toString();

    // 🔥 FALLBACK TO dog_photos (IMPORTANT)
    if (newHeroUrl == null) {
      final photos = await supabase
          .from('dog_photos')
          .select('url, is_hero')
          .eq('dog_id', widget.dogId);

      if (photos.isNotEmpty) {
        final hero = photos.firstWhere(
          (p) => p['is_hero'] == true,
          orElse: () => photos.first,
        );
        newHeroUrl = hero['url'];
      }
    }
    // 🔥 LOAD PEOPLE
    if (dogResult['breeder_person_id'] != null) {
      breeder = await supabase
          .from('people')
          .select()
          .eq('people_id', dogResult['breeder_person_id'])
          .maybeSingle();
    }

    if (dogResult['owner_person_id'] != null) {
      owner = await supabase
          .from('people')
          .select()
          .eq('people_id', dogResult['owner_person_id'])
          .maybeSingle();
    }

    // 🔥 LOAD PARENTS
   if (dogResult['mother_ala'] != null) {
    final motherRes = await supabase
        .from('dogs_with_hero')
        .select()
        .eq('dog_ala', dogResult['mother_ala']);

    if (motherRes.isNotEmpty) mother = motherRes.first;
  }

    /// == father

    if (dogResult['father_ala'] != null) {
      final fatherRes = await supabase
          .from('dogs_with_hero')
          .select()
          .eq('dog_ala', dogResult['father_ala']);

      if (fatherRes.isNotEmpty) father = fatherRes.first;
    }

    final isPet =
        (dogResult['status'] ?? '').toString().toLowerCase() == 'pet';

    setState(() {
      dog = dogResult;
      heroUrl = newHeroUrl;
    });

    await loadLitters();
  }
///
  Widget _buildDnaStatusBadge() {
    final hasDna = dog?['has_dna_summary'] == true;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        final updated = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DnaInputPage(
              dogId: widget.dogId,
              dogName: dog?['dog_name'],
            ),
          ),
        );

        if (updated == true) {
          await loadDog();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: hasDna
              ? Colors.green.shade100
              : Colors.red.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasDna
                ? Colors.green.shade300
                : Colors.red.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.biotech,
              size: 18,
              color: hasDna
                  ? Colors.green.shade700
                  : Colors.red.shade700,
            ),
            const SizedBox(width: 6),
            Text(
              hasDna ? 'DNA Uploaded' : 'DNA Missing',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: hasDna
                    ? Colors.green.shade800
                    : Colors.red.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
///
  Future<void> loadLitters() async {
    final dogAla = dog?['dog_ala'];
    if (dogAla == null) return;

    final pups = await supabase
        .from('dogs')
        .select('dog_ala, sex')
        .or('mother_ala.eq.$dogAla,father_ala.eq.$dogAla');

    final data = pups as List;

    int m = 0;
    int f = 0;
    final Set<String> litterSet = {};

    for (var pup in data) {
      final ala = pup['dog_ala']?.toString();
      final sexRaw = pup['sex']?.toString().toLowerCase();

      if (sexRaw != null) {
        if (sexRaw.startsWith('m')) m++;
        if (sexRaw.startsWith('f')) f++;
      }

      if (ala != null) {
        final parts = ala.split('-');
        if (parts.length >= 2) {
          litterSet.add('${parts[0]}-${parts[1]}');
        }
      }
    }

    setState(() {
      litterCount = litterSet.length;
      maleCount = m;
      femaleCount = f;
      puppyCount = m + f;
    });
  }

  // 🔥 HERO IMAGE FIX
  Widget _buildHeroImage() {
    final url = heroUrl;
    final dogAla = dog?['dog_ala'];

    if (url == null || url.isEmpty || dogAla == null) {
      return _placeholderHero();
    }

    String finalUrl;

      if (url.startsWith('http')) {
        // already full URL
        finalUrl = url;
      } else {
        finalUrl = supabase.storage
            .from('dog_files')
            .getPublicUrl('$dogAla/photos/$url');
      }

    return SizedBox(
      height: 160,
      width: 300,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(0),
        child: Image.network(
          finalUrl,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.6),
          errorBuilder: (_, __, ___) => _placeholderHero(),
        ),
      )
    );
  }
///. hold this   errorBuilder: (_, __, ___) => _placeholderHero(),
 Widget _placeholderHero() {
  return ClipRRect(
    borderRadius: BorderRadius.zero,
    child: Image.asset(
      'assets/images/no_photo.png',
      height: 220,
      width: double.infinity,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.6), // 👈 MAGIC NUMBER
    ),
  );
}

  Widget _buildOverviewContent() {
    final d = dog;

    if (d == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final age = d['dob'] != null
        ? calculateDogAge(d['dob'].toString())
        : '';

    final isPet =
        (d['status'] ?? '').toString().toLowerCase() == 'pet';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// HEADER
          Text(
            d['dog_name'] ?? '',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(d['dog_ala'] ?? ''),
          Text("Status: ${d['status'] ?? ''}"),
          
          const SizedBox(height: 8),

            _buildDnaStatusBadge(),

          const SizedBox(height: 8),

          if (d['spay_due'] != null)
            SpayDueLabel(spayDue: d['spay_due']),

          const SizedBox(height: 16),

          /// OWNER + BREEDER
          Row(
            children: [
              Expanded(
                child: (breeder != null || d['breeder_name'] != null)
                ? _PersonCard(
                    title: "Breeder",
                    primary: breeder != null
                        ? "${breeder!['first_name_1st'] ?? ''} ${breeder!['last_name_1st'] ?? ''}"
                        : (d['breeder_name'] ?? ''),
                    secondary: breeder != null
                        ? (breeder!['phone_1st'] ?? '')
                        : (d['breeder_kennel'] ?? ''),
                    icon: Icons.pets,
                    onTap: () async {
                      if (breeder != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PeopleDetailPage(personId: breeder!['people_id']),
                          ),
                        );
                      } else if (d['breeder_name'] != null) {
                        final res = await supabase
                            .from('people')
                            .select()
                            .ilike('last_name_1st', '%${d['breeder_name']}%')
                            .limit(1)
                            .maybeSingle();

                        if (res != null && context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PeopleDetailPage(personId: res['people_id']),
                            ),
                          );
                        }
                      }
                    },
                  )
                : const SizedBox(),  // 👈 THIS is where it goes
              ),

              const SizedBox(width: 8),

              Expanded(
                child: (owner != null || d['owner_name'] != null)
                ? _PersonCard(
                    title: "Owner",
                    primary: owner != null
                        ? "${owner!['first_name_1st'] ?? ''} ${owner!['last_name_1st'] ?? ''}"
                        : (d['owner_name'] ?? ''),
                    secondary: owner != null
                        ? (owner!['phone_1st'] ?? '')
                        : (d['owner_kennel'] ?? ''),
                    icon: Icons.person,
                    onTap: () async {
                      if (owner != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PeopleDetailPage(personId: owner!['people_id']),
                          ),
                        );
                      } else if (d['owner_name'] != null) {
                        final res = await supabase
                            .from('people')
                            .select()
                            .ilike('last_name_1st', '%${d['owner_name']}%')
                            .limit(1)
                            .maybeSingle();

                        if (res != null && context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PeopleDetailPage(personId: res['people_id']),
                            ),
                          );
                        }
                      }
                    },
                  )
                : const SizedBox(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          /// STATS
          Row(
            children: [
              _Stat("Litters", litterCount),
              const SizedBox(width: 16),
              _Stat("Pups", puppyCount),
            ],
          ),

          const SizedBox(height: 16),

          /// BREEDING
          if (!isPet) ...[
            _buildBreedingOverviewSection(d),
            _buildGeneticsSection(d),
            _buildIdentificationSection(d),
          ],

          const SizedBox(height: 16),

         
        /// PARENTS
        if (mother != null || father != null) ...[
          const Text(
            "👨‍👩‍👧 Parents",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: mother != null
                    ? DogCard(
                        dog: mother!,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DogDetailsPage(dogId: mother!['id']),
                            ),
                          );
                        },
                      )
                    : const SizedBox(),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: father != null
                    ? DogCard(
                        dog: father!,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DogDetailsPage(dogId: father!['id']),
                            ),
                          );
                        },
                      )
                    : const SizedBox(),
              ),
            ],
          ),
        ],
        ],
      ),
    );
  }


  Widget buildTabContent() {
    final tabs = getTabs();

    if (tabs.isEmpty || selectedTab >= tabs.length) {
      return const SizedBox();
    }

    final tab = tabs[selectedTab];

    switch (tab) {
      case 'Overview':
        return _buildOverviewContent();

      case 'Photos':
        return DogPhotosTab(
          dogId: widget.dogId,
          dogAla: dog!['dog_ala'],
          onHeroChanged: () async {
            await loadDog();
          },
        );

      case 'Genetics':
        return GeneticsTab(
          dogId: widget.dogId,
        );

      case 'Breeding':
        return DogBreedingTab(dogId: widget.dogId);

      case 'Notes':
        return DogNotesTab(dogId: widget.dogId);

      case 'Files':
        return DogFilesTab(
          dogId: widget.dogId,
          dogAla: dog!['dog_ala'],
        );

      default:
        return const SizedBox();
    }
  }

    IconData getTabIcon(String tab) {
      switch (tab) {
        case 'Overview':
          return Icons.dashboard;
        case 'Photos':
          return Icons.photo;
        case 'Breeding':
          return Icons.pets;
        case 'Genetics':
          return Icons.biotech;
        case 'Notes':
          return Icons.note;
        case 'Files':
          return Icons.folder;
        default:
          return Icons.circle;
      }
    }
  Widget buildTabs() {
    final tabs = getTabs();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: tabs.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemBuilder: (context, index) {
          final isSelected = selectedTab == index;

          return GestureDetector(
            onTap: () => setState(() => selectedTab = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.green.shade400
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    getTabIcon(tabs[index]),
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tabs[index],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (dog == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(dog!['dog_name'] ?? ''),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DogEditPage(dog: dog!),
                ),
              );

              if (updated == true) {
                await loadDog();
                Navigator.pop(context, true); // 🔥 bubble up
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [

          DevInfoPanel(
            page: 'Dog Details',
            filePath: 'lib/pages/dog_details_page.dart',
            purpose: 'Displays full dog profile including overview, breeding, photos, notes, files, and lineage',
            dataSources: [
              'dogs_with_hero',
              'dogs',
              'dog_photos',
              'people',
              'dna_bank',
              'supabase storage',
            ],
            notes: 'Hero image fallback logic. Dynamic tabs based on status. Parent lookup via dog_ala. Heavy relational page.',
          ),

          _buildHeroImage(),
          buildTabs(),

          Expanded(
            child: buildTabContent(),
          ),
        ],
      ),
    );
  }
////
  Widget _buildBreedingOverviewSection(Map<String, dynamic> dog) {
    final raw = dog['zooeasy_raw'] ?? {};

    String getVal(String key) {
      final v = raw[key];
      if (v == null || v.toString().trim().isEmpty) return '-';
      return v.toString();
    }

    return _buildSectionCard(
      title: '🧬 Breeding Overview',
      child: Column(
        children: [
          _infoRow('Breed %', getVal('breed_percentage')),
          _infoRow('Inbreeding', getVal('inbreeding_coefficient')),
          _infoRow('Generations', getVal('complete_generations')),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

}
class _PersonCard extends StatelessWidget {
  final String title;
  final String primary;
  final String secondary;
  final IconData icon;
  final VoidCallback onTap;

  const _PersonCard({
    required this.title,
    required this.primary,
    required this.secondary,
    required this.icon,
    required this.onTap,
  });
  //A
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
//S
//S
            const SizedBox(height: 8),

            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withOpacity(0.1),
                  child: Icon(
                    icon,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        primary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (secondary.isNotEmpty)
                        Text(
                          secondary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;

  const _Stat(this.label, this.value);
//
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

Widget _buildGeneticsSection(Map dog) {
  final raw = dog['zooeasy_raw'] ?? {};

  return _sectionCard(
    title: "🧪 Genetics & Health",
    children: [
      _infoRow("ECG", raw['ecg']),
      _infoRow("Coat", raw['coat']),
      _infoRow("Size", raw['size']),
      _infoRow("Grading", raw['grading']),
      _infoRow("2nd Colour", raw['second_colour']),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _badge("PennHip", raw['pennhip']),
          _badge("AVA", raw['ava']),
          _badge("Hips", raw['hips']),
          _badge("Elbows", raw['elbows']),
          _badge("DNA", raw['dna']),
        ],
      ),
    ],
  );
}

Widget _buildIdentificationSection(Map dog) {
  return _sectionCard(
    title: "📋 Identification",
    children: [
      _infoRow("Microchip", dog['microchip']),
      _infoRow("Pedigree", dog['pedigree_number']),
    ],
  );
}


Widget _infoRow(String label, dynamic value) {
  if (value == null || value.toString().isEmpty) {
    return const SizedBox();
  }

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LABEL
        SizedBox(
          width: 120, // 👈 fixed width for alignment
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),

        // VALUE (flexible)
        Expanded(
          child: Text(
            value.toString(),
            style: const TextStyle(fontWeight: FontWeight.w500),
            softWrap: true,
          ),
        ),
      ],
    ),
  );
}

Widget _badge(String label, dynamic value) {
  if (value == null || value.toString().isEmpty) return const SizedBox();

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      "$label: $value",
      style: const TextStyle(fontSize: 12),
    ),
  );
}

///
Widget _buildBreedingInfoSection(Map<String, dynamic> dog) {
  final raw = dog['zooeasy_raw'] ?? {};

  String getVal(String key) {
    final v = raw[key];
    if (v == null || v.toString().trim().isEmpty) return '-';
    return v.toString();
  }

  return Card(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    elevation: 1,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Breeding Info',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          _infoRow('Breed %', getVal('breed_percentage')),
          _infoRow('Inbreeding', getVal('inbreeding_coefficient')),
          _infoRow('Generations', getVal('complete_generations')),
          _infoRow('ECG', getVal('ecg')),
        ],
      ),
    ),
  );
}

Widget _sectionCard({
  required String title,
  required List<Widget> children,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  );
}