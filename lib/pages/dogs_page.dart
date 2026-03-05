import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dog_details_page.dart';
import 'widgets/dog_status_chips.dart';

class DogsPage extends StatefulWidget {
  const DogsPage({super.key});

  @override
  State<DogsPage> createState() => _DogsPageState();
}

class _DogsPageState extends State<DogsPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> allDogs = [];
  List<Map<String, dynamic>> filteredDogs = [];
  Map<String, String> heroMap = {};

  bool loading = true;

  String selectedFilter = 'All';
  String searchText = '';

  final filters = [
    'All',
    'Breeding',
    'Guardian',
    'Pet',
    'Retired',
    'Spay Scheduled',
    'Spay Due Soon',
    'Spay Overdue',
  ];

  @override
  void initState() {
    super.initState();
    loadDogs();
  }

  // =========================
  // AGE HELPERS
  // =========================

  String calculateAge(String? dobStr) {
    if (dobStr == null) return '';

    final dob = DateTime.tryParse(dobStr);
    if (dob == null) return '';

    final now = DateTime.now();

    int years = now.year - dob.year;
    int months = now.month - dob.month;

    if (months < 0) {
      years--;
      months += 12;
    }

    return '$years y $months m';
  }

  Color getAgeColor(String? dobStr) {
    if (dobStr == null) return Colors.black;

    final dob = DateTime.tryParse(dobStr);
    if (dob == null) return Colors.black;

    final now = DateTime.now();
    final totalMonths =
        (now.year - dob.year) * 12 + (now.month - dob.month);

    final years = totalMonths / 12.0;

    if (years < 1) return Colors.orange;
    if (years < 5) return Colors.green;

    return Colors.red;
  }

  // =========================
  // LOAD DATA
  // =========================

  Future<void> loadDogs() async {
    setState(() => loading = true);

    final dogsResponse = await supabase
        .from('dogs')
        .select()
        .order('dob', ascending: false);

    allDogs = List<Map<String, dynamic>>.from(dogsResponse);

    final heroResponse = await supabase
        .from('dog_photos')
        .select('dog_id, url')
        .eq('is_hero', true);

    heroMap.clear();
    for (var hero in heroResponse) {
      heroMap[hero['dog_id']] = hero['url'];
    }

    applyFilters();

    setState(() => loading = false);
  }

  void applyFilters() {
    filteredDogs = allDogs.where((dog) {
      final name = (dog['dog_name'] ?? '').toString().toLowerCase();
      final microchip =
          (dog['microchip'] ?? '').toString().toLowerCase();
      final ala = (dog['dog_ala'] ?? '').toString().toLowerCase();

      final matchesSearch =
          name.contains(searchText) ||
          microchip.contains(searchText) ||
          ala.contains(searchText);

      bool matchesFilter = true;

      if (selectedFilter == 'Spay Scheduled') {
        matchesFilter = dog['spay_due'] != null;
      } else if (selectedFilter == 'Spay Due Soon') {
        final dueStr = dog['spay_due'];
        if (dueStr == null) {
          matchesFilter = false;
        } else {
          final due = DateTime.parse(dueStr);
          final days =
              due.difference(DateTime.now()).inDays;
          matchesFilter = days >= 0 && days <= 30;
        }
      } else if (selectedFilter == 'Spay Overdue') {
        final dueStr = dog['spay_due'];
        if (dueStr == null) {
          matchesFilter = false;
        } else {
          final due = DateTime.parse(dueStr);
          final days =
              due.difference(DateTime.now()).inDays;
          matchesFilter = days < 0;
        }
      } else if (selectedFilter != 'All') {
        matchesFilter =
            dog['dog_type'] == selectedFilter;
      }

      return matchesSearch && matchesFilter;
    }).toList();
  }

  void openDog(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DogDetailsPage(dogId: id),
      ),
    );
  }

  // =========================
  // DOG TILE
  // =========================

  Widget buildDogTile(Map<String, dynamic> dog) {
    final age = calculateAge(dog['dob']);
    final heroFile = heroMap[dog['id']];
    final ala = dog['dog_ala'];
    
    final sex = dog['sex'];
    final isFemale = sex == 'Female';
    final isMale = sex == 'Male';

    Widget leadingWidget;

    if (heroFile == null || ala == null) {
      leadingWidget = const CircleAvatar(
        radius: 28,
        child: Icon(Icons.pets),
      );
    } else {
      final imageUrl = supabase.storage
          .from('dog_files')
          .getPublicUrl('$ala/photos/$heroFile');

      leadingWidget = CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(imageUrl),
      );
    }

    return Card(
      margin:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: leadingWidget,
        title: Row(
          children: [

            Expanded(
              child: Text(
                dog['dog_name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            if (isFemale) ...[
              const SizedBox(width: 6),
              const Icon(Icons.female, color: Colors.pink, size: 17),
            ],

            if (isMale) ...[
              const SizedBox(width: 6),
              const Icon(Icons.male, color: Colors.blue, size: 17),
            ],

          ],
        ),
        subtitle: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text('ALA: ${dog['dog_ala'] ?? ''}'),
            Text(dog['dog_type'] ?? ''),
            Text(
              'Age: $age',
              style: TextStyle(
                color: getAgeColor(dog['dob']),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            DogStatusChips(dog: dog),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => openDog(dog['id']),
      ),
    );
  }

  // =========================
  // BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search Name, ALA, Microchip',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              searchText = value.toLowerCase();
              applyFilters();
              setState(() {});
            },
          ),
        ),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonFormField(
            initialValue: selectedFilter,
            items: filters
                .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e),
                    ))
                .toList(),
            onChanged: (value) {
              selectedFilter = value!;
              applyFilters();
              setState(() {});
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredDogs.length,
            itemBuilder: (_, i) =>
                buildDogTile(filteredDogs[i]),

                
          ),
        ),
      ],
    );
  }
}