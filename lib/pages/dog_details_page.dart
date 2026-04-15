import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/date_utils.dart';
import '../tabs/dog_breeding_tab.dart';
import '../tabs/dog_photos_tab.dart';
import '../tabs/dog_files_tab.dart';
import '../tabs/dog_notes_tab.dart';
import '../tabs/dna_tab.dart';
import 'dog_edit_page.dart';
import 'people_detail_page.dart';
import 'widgets/dog_card.dart';
import '../ui/spay_due_label.dart';
import 'widgets/app_dog_image.dart';


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
      'Notes',
      'Files',
    ];

    if (status != 'Pet') {
      tabs.insert(2, 'Breeding');
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
        .from('dogs')
        .select()
        .eq('id', widget.dogId)
        .maybeSingle();

    if (dogResult == null) return;

    final photos = await supabase
        .from('dog_photos')
        .select('url, is_hero')
        .eq('dog_id', widget.dogId);

    String? newHeroUrl;

    if (photos.isNotEmpty) {
      final hero = photos.firstWhere(
        (p) => p['is_hero'] == true,
        orElse: () => photos.first,
      );
      newHeroUrl = hero['url'];
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
    final motherRes = await supabase
        .from('dogs_list_view')
        .select('''
          *,
          hero:dog_photos!dog_photos_dog_id_fkey (
            url,
            is_hero
          )
        ''')
        .eq('dog_ala', dogResult['mother_ala'])
        .eq('dog_photos.is_hero', true);

    if (motherRes.isNotEmpty) mother = motherRes.first;

    /// == father

    final fatherRes = await supabase
        .from('dogs_list_view')
        .select('''
          *,
          hero:dog_photos!dog_photos_dog_id_fkey (
            url,
            is_hero
          )
        ''')
        .eq('dog_ala', dogResult['father_ala'])
        .eq('dog_photos.is_hero', true);

    if (fatherRes.isNotEmpty) father = fatherRes.first;

    final isPet =
        (dogResult['status'] ?? '').toString().toLowerCase() == 'pet';

    setState(() {
      dog = dogResult;
      heroUrl = newHeroUrl;
    });

    await loadLitters();
  }

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

    if (url == null || url.isEmpty) return _placeholderHero();

    String finalUrl;

    if (url.startsWith('http')) {
      finalUrl = url;
    } else {
      final dogAla = dog?['dog_ala'];
      finalUrl = supabase.storage
          .from('dog_files')
          .getPublicUrl('$dogAla/photos/$url');
    }

          return SizedBox(
        height: 260,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 🐶 YOUR EXISTING IMAGE (UNCHANGED LOGIC)
            Image.network(
              finalUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholderHero(),
            ),

            // 🌑 GRADIENT (safe overlay)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.5),
                  ],
                ),
              ),
            ),

            // 🏷 DOG NAME (safe, uses existing data)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Text(
                dog?['dog_name'] ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      blurRadius: 6,
                      color: Colors.black,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
  }

 Widget _placeholderHero() {
  return ClipRRect(
    borderRadius: BorderRadius.zero,
    child: Image.asset(
      'assets/images/no_photo.png',
      height: 220,
      width: double.infinity,
      fit: BoxFit.cover,
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
          if (age.isNotEmpty) Text("Age: $age"),

          const SizedBox(height: 8),

          if (d['spay_due'] != null)
            SpayDueLabel(spayDue: d['spay_due']),

          const SizedBox(height: 16),

          /// OWNER + BREEDER
          Row(
            children: [
              Expanded(
                child: breeder != null
                    ? _PersonCard(
                        title: "Breeder",
                        primary:
                            "${breeder!['first_name_1st'] ?? ''} ${breeder!['last_name_1st'] ?? ''}",
                        secondary: breeder!['phone_1st'] ?? '',
                        icon: Icons.pets,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PeopleDetailPage(personId: breeder!['people_id']),
                            ),
                          );
                        },
                      )
                    : const SizedBox(),  // 👈 THIS is where it goes
              ),

              const SizedBox(width: 8),

              Expanded(
                child: owner != null
                    ? _PersonCard(
                        title: "Owner",
                        primary:
                            "${owner!['first_name_1st'] ?? ''} ${owner!['last_name_1st'] ?? ''}",
                        secondary: owner!['phone_1st'] ?? '',
                        icon: Icons.person,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PeopleDetailPage(personId: owner!['people_id']),
                            ),
                          );
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
              children: [
                Expanded(
                  child: mother != null
                      ? GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DogDetailsPage(dogId: mother!['id']),
                              ),
                            );
                          },
                          child: DogCard(dog: mother!),
                        )
                      : const SizedBox(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: father != null
                      ? GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DogDetailsPage(dogId: father!['id']),
                              ),
                            );
                          },
                          child: DogCard(dog: father!),
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
        case 'DNA':
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
          _buildHeroImage(),
          buildTabs(),
          Expanded(child: buildTabContent()),
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