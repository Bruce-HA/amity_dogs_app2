import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/date_utils.dart';
import '../tabs/dog_breeding_tab.dart';
import '../tabs/dog_photos_tab.dart';
import '../tabs/dog_files_tab.dart';
import '../tabs/dog_notes_tab.dart';
import '../tabs/dna_tab.dart';
import 'people_detail_page.dart';
import 'dog_edit_page.dart';
import 'widgets/dog_card.dart';
import '../services/breeding_plan_service.dart';

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
  final _service = BreedingPlanService();

  Map<String, dynamic>? dog;
  Map<String, dynamic>? breeder;
  Map<String, dynamic>? owner;
  Map<String, dynamic>? mother;
  Map<String, dynamic>? father;

  String? heroUrl;
  bool loading = true;

  int selectedTab = 0;
  List<String> tabs = [];

  int maleCount = 0;
  int femaleCount = 0;

  int litterCount = 0;
  int puppyCount = 0;
  bool isLoadingLitters = true;

  @override
  void initState() {
    super.initState();
    loadDog();
  }

  Future<void> loadDog() async {
    setState(() => loading = true);

    final dogResult = await supabase
        .from('dogs')
        .select()
        .eq('id', widget.dogId)
        .maybeSingle();

    if (dogResult == null) {
      setState(() {
        dog = null;
        loading = false;
      });
      return;
    }

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

      final rawUrl = hero['url'];

      if (rawUrl != null && rawUrl.toString().startsWith('http')) {
        newHeroUrl = rawUrl;
      } else {
        newHeroUrl = supabase.storage
            .from('dog_files')
            .getPublicUrl("${dogResult['dog_ala']}/photos/$rawUrl");
      }
    }

    Map<String, dynamic>? loadedBreeder;
    Map<String, dynamic>? loadedOwner;
    Map<String, dynamic>? loadedMother;
    Map<String, dynamic>? loadedFather;

    if (dogResult['breeder_person_id'] != null) {
      loadedBreeder = await supabase
          .from('people')
          .select()
          .eq('people_id', dogResult['breeder_person_id'])
          .maybeSingle();
    }

    if (dogResult['owner_person_id'] != null) {
      loadedOwner = await supabase
          .from('people')
          .select()
          .eq('people_id', dogResult['owner_person_id'])
          .maybeSingle();
    }

    if (dogResult['mother_ala'] != null) {
      final res = await supabase
          .from('dogs_list_view')
          .select('id, dog_name, dog_ala, status, hero_image_url, dob')
          .eq('dog_ala', dogResult['mother_ala']);
      if (res.isNotEmpty) loadedMother = res.first;
    }

    if (dogResult['father_ala'] != null) {
      final res = await supabase
          .from('dogs_list_view')
          .select('id, dog_name, dog_ala, status, hero_image_url, dob')
          .eq('dog_ala', dogResult['father_ala']);
      if (res.isNotEmpty) loadedFather = res.first;
    }

    final isPet = dogResult['status'] == 'Pet';

    tabs = isPet
        ? ['Overview', 'Photos', 'Notes', 'Files']
        : ['Overview', 'Photos', 'Breeding', 'DNA', 'Notes', 'Files'];

    setState(() {
      dog = dogResult;
      breeder = loadedBreeder;
      owner = loadedOwner;
      mother = loadedMother;
      father = loadedFather;
      heroUrl = newHeroUrl;
      loading = false;
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
      isLoadingLitters = false;
    });
  }

  Widget buildOverview() {
    String age = '';
    final dobRaw = dog?['dob'];

    if (dobRaw != null) {
      age = calculateDogAge(dobRaw.toString());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dog?['dog_name'] ?? '',
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(dog?['dog_ala'] ?? ''),

          Text("Status: ${dog?['status'] ?? ''}"),
          Text(age.isNotEmpty ? "Age: $age" : "Age: Unknown"),
          const SizedBox(height: 20),

          if (dog?['status'] != 'Pet') ...[
            const Text(
              'Litters',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),

            if (isLoadingLitters)
              const Text('Loading...')
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Litters: $litterCount'),
                  Text('Puppies: $puppyCount'),
                  const SizedBox(height: 4),
                  Text('🔵♂ $maleCount'),
                  Text('🩷♀ $femaleCount'),
                                  ],
              ),

            const SizedBox(height: 20),
          ],

          SizedBox(
            height: 180,
            child: Row(
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
          ),

          const SizedBox(height: 20),

          if (breeder != null)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PeopleDetailPage(
                      personId: breeder!['people_id'],
                    ),
                  ),
                );
              },
              child: Text(
                  "Breeder: ${breeder!['first_name_1st']} ${breeder!['last_name_1st']}"),
            ),

          if (owner != null)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PeopleDetailPage(
                      personId: owner!['people_id'],
                    ),
                  ),
                );
              },
              child: Text(
                  "Owner: ${owner!['first_name_1st']} ${owner!['last_name_1st']}"),
            ),
        ],
      ),
    );
  }

  Widget buildTabContent() {
    final tab = tabs[selectedTab];

    switch (tab) {
      case 'Overview':
        return buildOverview();
      case 'Photos':
        return DogPhotosTab(
          dogId: widget.dogId,
          dogAla: dog!['dog_ala'],
          onHeroChanged: loadDog,
        );
      case 'Breeding':
        return DogBreedingTab(dogId: widget.dogId);
      case 'DNA':
        return DnaTab(dogId: widget.dogId);
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

  Widget buildTabs() {
    return Wrap(
      children: List.generate(tabs.length, (index) {
        final isSelected = selectedTab == index;

        return GestureDetector(
          onTap: () {
            setState(() => selectedTab = index);
          },
          child: Container(
            width: MediaQuery.of(context).size.width / 3,
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            color: isSelected
                ? Colors.green.shade100
                : Colors.grey.shade200,
            child: Text(
              tabs[index],
              style: TextStyle(
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading || dog == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(dog!['dog_name'] ?? ''),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DogEditPage(dog: dog!),
                ),
              );
              loadDog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (heroUrl != null)
            Image.network(heroUrl!,
                height: 220, width: double.infinity, fit: BoxFit.cover),
          buildTabs(),
          Expanded(child: buildTabContent()),
        ],
      ),
    );
  }
}