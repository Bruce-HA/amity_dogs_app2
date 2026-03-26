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

  String? heroUrl;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadDog();
  }

  // =========================
  // LOAD DATA
  // =========================

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

    // HERO
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

      final fileName = hero['url'];

      newHeroUrl = supabase.storage
          .from('dog_files')
          .getPublicUrl("${dogResult['dog_ala']}/photos/$fileName");
    }

    // PEOPLE
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

    // 🔥 PARENTS WITH HERO IMAGE
    if (dogResult['mother_ala'] != null) {
      final res = await supabase
          .from('dogs_list_view')
          .select('id, dog_name, dog_ala, status, hero_image_url')
          .eq('dog_ala', dogResult['mother_ala']);

      if (res.isNotEmpty) loadedMother = res.first;
    }

    if (dogResult['father_ala'] != null) {
      final res = await supabase
          .from('dogs_list_view')
          .select('id, dog_name, dog_ala, status, hero_image_url')
          .eq('dog_ala', dogResult['father_ala']);

      if (res.isNotEmpty) loadedFather = res.first;
    }

    setState(() {
      dog = dogResult;
      breeder = loadedBreeder;
      owner = loadedOwner;
      mother = loadedMother;
      father = loadedFather;
      heroUrl = newHeroUrl;
      loading = false;
    });
  }

  // =========================
  // UI
  // =========================

  Widget buildParentCard(Map<String, dynamic>? parent, String label) {
    if (parent == null) return const SizedBox();

    final imageUrl = parent['hero_image_url'];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DogDetailsPage(dogId: parent['id']),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),

            const SizedBox(height: 6),

            // 🐶 IMAGE THUMBNAIL
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: (imageUrl != null && imageUrl.toString().isNotEmpty)
                  ? Image.network(
                      imageUrl,
                      height: 80,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),

            const SizedBox(height: 6),

            Text(
              parent['dog_name'] ?? '',
              textAlign: TextAlign.center,
            ),

            Text(
              parent['dog_ala'] ?? '',
              style: const TextStyle(fontSize: 12),
            ),

            Text(
              parent['status'] ?? '',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      height: 80,
      color: Colors.grey.shade300,
      child: const Icon(Icons.pets),
    );
  }

  Widget buildParents() {
    return Row(
      children: [
        Expanded(child: buildParentCard(mother, "Mother")),
        const SizedBox(width: 10),
        Expanded(child: buildParentCard(father, "Father")),
      ],
    );
  }

  Widget buildBasicInfo() {
    final age = calculateDogAge(dog?['dob']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dog?['dog_name'] ?? '',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),

        Text("Status: ${dog?['status'] ?? ''}"),

        if (age.isNotEmpty)
          Text("Age: $age")
        else
          const Text("Age: Unknown"),
      ],
    );
  }

  Widget buildPeople() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (breeder != null)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PeopleDetailPage(personId: breeder!['people_id']),
                ),
              );
            },
            child: Text(
              "Breeder: ${breeder!['first_name_1st']} ${breeder!['last_name_1st']}",
            ),
          ),
        const SizedBox(height: 8),
        if (owner != null)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PeopleDetailPage(personId: owner!['people_id']),
                ),
              );
            },
            child: Text(
              "Owner: ${owner!['first_name_1st']} ${owner!['last_name_1st']} (${owner!['phone_1st']})",
            ),
          ),
      ],
    );
  }

  // =========================
  // BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
    if (loading || dog == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isPet = dog!['status'] == 'Pet';

    return Scaffold(
     appBar: AppBar(
      title: Text(dog!['dog_name'] ?? ''),
      centerTitle: true,
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (heroUrl != null)
              Image.network(
                heroUrl!,
                height: 300,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
//
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  buildBasicInfo(),
                  const SizedBox(height: 20),
                  buildParents(),
                  const SizedBox(height: 20),
                  buildPeople(),

                  if (!isPet) ...[
                    const SizedBox(height: 20),
                    const Text("Breeding info coming soon"),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}