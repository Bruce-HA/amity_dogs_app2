import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../tabs/dog_breeding_tab.dart';
import '../tabs/dog_photos_tab.dart';
import '../tabs/dog_files_tab.dart';
import '../tabs/dog_notes_tab.dart';
import 'people_detail_page.dart';
import '../tabs/dna_tab.dart';

class DogDetailsPage extends StatefulWidget {
  final String dogId;

  const DogDetailsPage({
    super.key,
    required this.dogId,
  });

  @override
  State<DogDetailsPage> createState() => _DogDetailsPageState();
}
//
 
//
class _DogDetailsPageState extends State<DogDetailsPage> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? dog;
  Map<String, dynamic>? breeder;
  Map<String, dynamic>? owner;
  Map<String, dynamic>? guardian;
  Map<String, dynamic>? mother;
  Map<String, dynamic>? father;

  String? heroUrl;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadDog();
  }
  //=========
  Widget buildSpayChip(String? raw) {
    if (raw == null) return const SizedBox();

    final due = DateTime.parse(raw);
    final now = DateTime.now();
    final difference = due.difference(now).inDays;

    Color color;
    if (difference <= 60) {
      color = Colors.red;
    } else if (difference <= 120) {
      color = Colors.orange;
    } else {
      color = Colors.green;
    }

    return Chip(
      label: Text(
        "Spay Due: ${due.day}/${due.month}/${due.year}",
      ),
      backgroundColor: color,
      labelStyle: const TextStyle(color: Colors.white),
    );
  }
  //=========
  Future<void> refreshHeroOnly() async {
    final heroPhoto = await supabase
        .from('dog_photos')
        .select('url')
        .eq('dog_id', widget.dogId)
        .eq('is_hero', true)
        .maybeSingle();

    if (heroPhoto != null && heroPhoto['url'] != null) {
      setState(() {
        heroUrl = supabase.storage
            .from('dog_files')
            .getPublicUrl(
                "${dog!['dog_ala']}/photos/${heroPhoto['url']}");
      });
    }
  }
//
 
//    

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

    // Load hero photo
    final heroPhoto = await supabase
        .from('dog_photos')
        .select('url')
        .eq('dog_id', widget.dogId)
        .eq('is_hero', true)
        .maybeSingle();

    if (heroPhoto != null && heroPhoto['url'] != null) {
      heroUrl = supabase.storage
          .from('dog_files')
          .getPublicUrl(
              "${dogResult['dog_ala']}/photos/${heroPhoto['url']}");
    } else {
      heroUrl = null;
    }

    Map<String, dynamic>? loadedBreeder;
    Map<String, dynamic>? loadedOwner;
    Map<String, dynamic>? loadedGuardian;
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

    if (dogResult['guardian_person_id'] != null) {
      loadedGuardian = await supabase
          .from('people')
          .select()
          .eq('people_id', dogResult['guardian_person_id'])
          .maybeSingle();
    }

    if (dogResult['mother_ala'] != null &&
        dogResult['mother_ala'].toString().isNotEmpty) {
      final motherList = await supabase
          .from('dogs')
          .select('id, dog_name, dog_ala')
          .eq('dog_ala', dogResult['mother_ala']);

      if (motherList.isNotEmpty) {
        loadedMother = motherList.first;
      }
    }

    if (dogResult['father_ala'] != null &&
        dogResult['father_ala'].toString().isNotEmpty) {
      final fatherList = await supabase
          .from('dogs')
          .select('id, dog_name, dog_ala')
          .eq('dog_ala', dogResult['father_ala']);

      if (fatherList.isNotEmpty) {
        loadedFather = fatherList.first;
      }
    }

    setState(() {
      dog = dogResult;
      breeder = loadedBreeder;
      owner = loadedOwner;
      guardian = loadedGuardian;
      mother = loadedMother;
      father = loadedFather;
      loading = false;
    });
  }

  Widget buildPersonRow({
    required String label,
    required IconData icon,
    required Map<String, dynamic>? person,
  }) {
    if (person == null) return const SizedBox.shrink();

    final displayName =
        (person['business_name'] != null &&
                person['business_name'].toString().isNotEmpty)
            ? person['business_name']
            : "${person['first_name_1st'] ?? ''} ${person['last_name_1st'] ?? ''}";

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PeopleDetailPage(personId: person['people_id']),
            ),
          );
        },
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                "$label: $displayName",
                style: const TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildParentRow({
    required String label,
    required Map<String, dynamic>? parent,
  }) {
    if (parent == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DogDetailsPage(dogId: parent['id']),
            ),
        
          );
        },
        child: Row(
          children: [
            const Icon(Icons.pets, size: 18, color: Colors.grey),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                "$label: ${parent['dog_name']} (${parent['dog_ala']})",
                style: const TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading || dog == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(dog!['dog_name'] ?? ''),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                   // HERO IMAGE (smaller, centered, maintains aspect ratio)
            if (heroUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 140, // ~50% of previous 240
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        heroUrl!,
                        fit: BoxFit.contain, // maintain aspect ratio
                      ),
                    ),
                  ),
                ),
              ),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("ALA: ${dog?['dog_ala'] ?? ''}"),
                          const SizedBox(height: 8),
                          Text("Microchip: ${dog?['microchip'] ?? ''}"),
                            const SizedBox(height: 10),

                            buildSpayChip(dog?['spay_due']),

                            const SizedBox(height: 20),

                            if (mother != null)
                              buildParentRow(label: "Mother", parent: mother),

                          if (father != null)
                            buildParentRow(label: "Father", parent: father),

                          const SizedBox(height: 20),

                          buildPersonRow(
                            label: "Breeder",
                            icon: Icons.emoji_events,
                            person: breeder,
                          ),
                          buildPersonRow(
                            label: "Owner",
                            icon: Icons.person,
                            person: owner,
                          ),
                          buildPersonRow(
                            label: "Guardian",
                            icon: Icons.shield,
                            person: guardian,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const TabBar(
              labelColor: Colors.teal,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.teal,
              tabs: [
                Tab(text: "Photos"),
                Tab(text: "Files"),
                Tab(text: "Notes"),
                Tab(text: 'DNA'),
                Tab(text: "Breeding"),
              ],
            ),

            Expanded(
              child: TabBarView(
                children: [
                  DogPhotosTab(
                    dogId: dog!['id'],
                    dogAla: dog!['dog_ala'] ?? '',
                    onHeroChanged: () async {
                      await refreshHeroOnly();
                    },
                  ),
                  DogFilesTab(
                    dogId: dog!['id'],
                    dogAla: dog!['dog_ala'],
                  ),
                  DogNotesTab(dogId: dog!['id']),
                  DnaTab(dogId: dog!['id']),
                  DogBreedingTab(dogId: dog!['id']),
                  
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}