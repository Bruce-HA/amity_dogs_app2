import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../tabs/dog_breeding_tab.dart';
import '../tabs/dog_photos_tab.dart';
import '../tabs/dog_files_tab.dart';
import '../tabs/dog_notes_tab.dart';
import '../pages/people_detail_page.dart';

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
  Map<String, dynamic>? guardian;
  Map<String, dynamic>? mother;
  Map<String, dynamic>? father;

  bool loading = true;
  bool editMode = false;

  final nameController = TextEditingController();
  final alaController = TextEditingController();
  final microchipController = TextEditingController();

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
        loading = false;
        dog = null;
      });
      return;
    }

    // Temporary holders
    Map<String, dynamic>? loadedBreeder;
    Map<String, dynamic>? loadedOwner;
    Map<String, dynamic>? loadedGuardian;
    Map<String, dynamic>? loadedMother;
    Map<String, dynamic>? loadedFather;

    // Load breeder
    if (dogResult['breeder_person_id'] != null) {
      loadedBreeder = await supabase
          .from('people')
          .select()
          .eq('people_id', dogResult['breeder_person_id'])
          .maybeSingle();
    }

    // Load owner
    if (dogResult['owner_person_id'] != null) {
      loadedOwner = await supabase
          .from('people')
          .select()
          .eq('people_id', dogResult['owner_person_id'])
          .maybeSingle();
    }

    // Load guardian
    if (dogResult['guardian_person_id'] != null) {
      loadedGuardian = await supabase
          .from('people')
          .select()
          .eq('people_id', dogResult['guardian_person_id'])
          .maybeSingle();
    }

    // Load mother
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

    // Load father
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

    // FINAL STATE UPDATE
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

    final ala =
        person['zooeasy_breeder_id'] ??
        person['zooeasy_owner_id'] ??
        '';

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
                "$label: $displayName ${ala != '' ? '($ala)' : ''}",
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
//=======
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

//====
  @override
  Widget build(BuildContext context) {
    if (loading || dog == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(dog!['dog_name'] ?? ''),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("ALA: ${dog?['dog_ala'] ?? ''}"),
                    const SizedBox(height: 8),
                    Text("Microchip: ${dog?['microchip'] ?? ''}"),
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
            ),

            const TabBar(
              labelColor: Colors.teal,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.teal,
              tabs: [
                Tab(text: "Photos"),
                Tab(text: "Files"),
                Tab(text: "Notes"),
                Tab(text: "Breeding"),
              ],
            ),

            Expanded(
              child: TabBarView(
                children: [
                  DogPhotosTab(
                    dogId: dog!['id'].toString(),
                    dogAla: dog!['dog_ala'] ?? '',
                    onHeroChanged: () => setState(() {}),
                  ),
                  DogFilesTab(
                    dogId: dog!['id'],
                    dogAla: dog!['dog_ala'],
                  ),
                  DogNotesTab(dogId: dog!['id']),
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