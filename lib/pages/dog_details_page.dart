import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../tabs/dog_photos_tab.dart';
import '../tabs/dog_files_tab.dart';
import '../tabs/dog_notes_tab.dart';
import '../tabs/dog_correspondence_tab.dart';

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
  bool loading = true;
  bool editMode = false;
  final nameController = TextEditingController();
  final alaController = TextEditingController();
  final microchipController = TextEditingController();

  String calculateAge(String? dobString) {
  if (dobString == null) return "";

  final dob = DateTime.tryParse(dobString);
  if (dob == null) return "";

  final now = DateTime.now();

  int years = now.year - dob.year;
  int months = now.month - dob.month;

  if (months < 0) {
    years--;
    months += 12;
  }

  return "$years y $months m";
}

  @override
  void initState() {
    super.initState();
    loadDog();
  }
  Future<void> saveChanges() async {
    await supabase.from('dogs').update({
      'dog_name': nameController.text,
      'dog_ala': alaController.text,
      'microchip': microchipController.text,
    }).eq('id', dog!['id']);

    await loadDog();
  }
/// spay chip 
  Widget buildSpayChip() {
    final spayDueString = dog?['spay_due'];

    if (spayDueString == null) return const SizedBox.shrink();

    final spayDate = DateTime.tryParse(spayDueString);
    if (spayDate == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final days = spayDate.difference(now).inDays;

    Color chipColor = Colors.green;

    if (days <= 60) {
      chipColor = Colors.red;
    } else if (days <= 90) {
      chipColor = Colors.orange;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Chip(
        label: Text(
          "Spay Due: ${spayDate.day}/${spayDate.month}/${spayDate.year}",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: chipColor,
      ),
    );
  }/// 
/// 
/// 
/// Spay chip above 
  Future<void> loadDog() async {
    setState(() => loading = true);

    final result = await supabase
        .from('dogs')
        .select()
        .eq('id', widget.dogId)
        .maybeSingle();

    if (result == null) {
      setState(() {
        loading = false;
        dog = null;
      });
      return;
    }

    dog = result;

    nameController.text = dog?['dog_name'] ?? '';
    alaController.text = dog?['dog_ala'] ?? '';
    microchipController.text = dog?['microchip'] ?? '';

    setState(() => loading = false);
  }

  Future<Map<String, dynamic>?> _getHeroPhoto() async {
    return await supabase
        .from('dog_photos')
        .select()
        .eq('dog_id', widget.dogId)
        .eq('is_hero', true)
        .maybeSingle();
  }

  Future<Map<String, dynamic>?> getDogById(String? id) async {
    if (id == null) return null;

    return await supabase
        .from('dogs')
        .select('id, dog_name, dog_ala')
        .eq('id', id)
        .maybeSingle();
  }
  Widget buildHeroBanner() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _getHeroPhoto(),
      builder: (context, snapshot) {

        final screenWidth = MediaQuery.of(context).size.width;
        final heroWidth = screenWidth * 0.4;
        final heroHeight = heroWidth * 1.1;    // portrait feel

        String? imageUrl;

        if (snapshot.hasData && snapshot.data != null) {
          final hero = snapshot.data!;
          final ala = dog!['dog_ala'];
          imageUrl = supabase.storage
              .from('dog_files')
              .getPublicUrl('$ala/photos/${hero['url']}');
        }

        return Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: heroWidth,
                height: heroHeight,
                color: Colors.grey.shade300,
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.pets, size: 50),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildInfoCard() {
    final age = calculateAge(dog?['dob']);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

        
// spay chip
          Text(
            "Age: $age",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),

          buildSpayChip(),

          const SizedBox(height: 8),
// spay chip above 
          const SizedBox(height: 8),

          Text("ALA: ${dog?['dog_ala'] ?? ''}"),
          const SizedBox(height: 8),
          editMode
          ? TextField(controller: microchipController)
          : Text("Microchip: ${dog?['microchip'] ?? ''}"),

          const SizedBox(height: 20),

          // MOTHER
          FutureBuilder<Map<String, dynamic>?>(
            future: getDogById(dog?['mother_id']),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data == null) {
                return const Text("Mother: -");
              }

              final mother = snapshot.data!;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DogDetailsPage(dogId: mother['id']),
                    ),
                  );
                },
                child: Text(
                  "Mother: ${mother['dog_name']} (${mother['dog_ala']})",
                  style: const TextStyle(
                    color: Colors.teal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // FATHER
          FutureBuilder<Map<String, dynamic>?>(
            future: getDogById(dog?['father_id']),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data == null) {
                return const Text("Father: -");
              }

              final father = snapshot.data!;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DogDetailsPage(dogId: father['id']),
                    ),
                  );
                },
                child: Text(
                  "Father: ${father['dog_name']} (${father['dog_ala']})",
                  style: const TextStyle(
                    color: Colors.teal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
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
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(dog!['dog_name'] ?? ''),
          centerTitle: true,
          actions: [
            if (editMode)
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: () async {
                  await saveChanges();
                  setState(() => editMode = false);
                },
              ),
            IconButton(
              icon: Icon(editMode ? Icons.close : Icons.edit),
              onPressed: () {
                setState(() {
                  editMode = !editMode;
                });
              },
            ),
          ],
        ),
        body: Column(
          children: [

            // TOP HALF (scrollable)
            Expanded(
              flex: 1, // 50%
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    buildHeroBanner(),
                    const SizedBox(height: 12),
                    buildInfoCard(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // BOTTOM HALF (tabs + content)
            Expanded(
              flex: 1, // 50%
              child: Column(
                children: [

                  const TabBar(
                    labelColor: Colors.teal,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.teal,
                    tabs: [
                      Tab(text: "Photos"),
                      Tab(text: "Files"),
                      Tab(text: "Notes"),
                      Tab(text: "Correspondence"),
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
                        DogCorrespondenceTab(dogId: dog!['id']),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}