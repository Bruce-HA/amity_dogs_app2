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

  final String baseUrl =
      'https://phkwizyrpfzoecugpshb.supabase.co/storage/v1/object/public/dog_files';

  @override
  void initState() {
    super.initState();
    loadDogs();
  }

  Future<void> loadDogs() async {
    setState(() => loading = true);

    final response =
        await supabase.from('dogs').select().order('dob', ascending: false);

    allDogs = List<Map<String, dynamic>>.from(response);

    applyFilters();

    setState(() => loading = false);
  }

    void applyFilters() {
    filteredDogs = allDogs.where((dog) {
      final name = (dog['dog_name'] ?? '').toString().toLowerCase();
      final phone = (dog['phone_1st'] ?? '').toString().toLowerCase();
      final microchip = (dog['microchip'] ?? '').toString().toLowerCase();
      final ala = (dog['dog_ala'] ?? '').toString().toLowerCase();

      final matchesSearch =
          name.contains(searchText) ||
          phone.contains(searchText) ||
          microchip.contains(searchText) ||
          ala.contains(searchText);

      bool matchesFilter = true;

      if (selectedFilter == 'Spay Scheduled') {
        matchesFilter = dog['spay_due'] != null &&
            DateTime.tryParse(dog['spay_due'] ?? '') != null;
      } else if (selectedFilter == 'Spay Due Soon') {
        final due = DateTime.tryParse(dog['spay_due'] ?? '');
        if (due == null) {
          matchesFilter = false;
        } else {
          final days = due.difference(DateTime.now()).inDays;
          matchesFilter = days >= 0 && days <= 30;
        }
      } else if (selectedFilter == 'Spay Overdue') {
        final due = DateTime.tryParse(dog['spay_due'] ?? '');
        if (due == null) {
          matchesFilter = false;
        } else {
          final days = due.difference(DateTime.now()).inDays;
          matchesFilter = days < 0;
        }
      } else if (selectedFilter != 'All') {
        final type =
            (dog['dog_type'] ?? '').toString().trim().toLowerCase();
        final filter =
            selectedFilter.trim().toLowerCase();

        matchesFilter = type == filter;
      }

      return matchesSearch && matchesFilter;
    }).toList();

    filteredDogs.sort((a, b) {
      final aDue = DateTime.tryParse(a['spay_due'] ?? '');
      final bDue = DateTime.tryParse(b['spay_due'] ?? '');

      if (aDue == null && bDue == null) return 0;
      if (aDue == null) return 1;
      if (bDue == null) return -1;

      return aDue.compareTo(bDue);
    });
  }

  String calculateAge(String? dobStr) {
    if (dobStr == null || dobStr.isEmpty) return '';

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
    if (dobStr == null || dobStr.isEmpty) return Colors.black;

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

  void openDog(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DogDetailsPage(dogId: id),
      ),
    );
  }

  Widget buildHeroImage(Map<String, dynamic> dog) {
    final ala = dog['dog_ala'];

    if (ala == null || ala.toString().isEmpty) {
      return Image.asset(
        'assets/images/no_photo.png',
        width: 72,
        height: 72,
        fit: BoxFit.cover,
      );
    }

    final url = '$baseUrl/$ala/photos/hero.jpg';

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Image.asset(
            'assets/images/no_photo.png',
            width: 72,
            height: 72,
            fit: BoxFit.cover,
          );
        },
      ),
    );
  }

  Widget buildDogTile(Map<String, dynamic> dog) {
    final age = calculateAge(dog['dob']);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: buildHeroImage(dog),
        title: Text(
          dog['dog_name'] ?? '',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ALA: ${dog['dog_ala'] ?? ''}'),
            Text(dog['dog_type'] ?? ''),
            Text('Microchip: ${dog['microchip'] ?? ''}'),
            Text('Sex: ${dog['sex'] ?? ''}'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dogs'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
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
                      value: selectedFilter,
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
              ),
            ),
    );
  }
}