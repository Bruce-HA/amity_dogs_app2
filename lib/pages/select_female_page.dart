import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SelectFemalePage extends StatefulWidget {
  const SelectFemalePage({Key? key}) : super(key: key);

  @override
  State<SelectFemalePage> createState() => _SelectMalePageState();
}

class _SelectMalePageState extends State<SelectFemalePage> {
  final _client = Supabase.instance.client;
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _dogs = [];
  List<Map<String, dynamic>> _filtered = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDogs();
  }

  Future<void> _loadDogs() async {
    List<Map<String, dynamic>> allDogs = [];

    int from = 0;
    const pageSize = 1000;

    while (true) {
      final response = await _client
          .from('dogs')
          .select('dog_ala, dog_name, sex')
          .eq('sex', 'Female')
          .order('dog_name')
          .range(from, from + pageSize - 1);

      final batch = List<Map<String, dynamic>>.from(response);

      allDogs.addAll(batch);

      if (batch.length < pageSize) break;

      from += pageSize;
    }

    setState(() {
      _dogs = allDogs;
      _filtered = allDogs;
      _loading = false;
    });
  }

  void _search(String value) {
    final query = value.toLowerCase().trim();

    setState(() {
      if (query.isEmpty) {
        _filtered = _dogs;
      } else {
        _filtered = _dogs.where((dog) {
          final name = (dog['dog_name'] ?? '')
              .toString()
              .toLowerCase()
              .trim();

          final ala = (dog['dog_ala'] ?? '')
              .toString()
              .toLowerCase();

          return name.contains(query) || ala.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Female'),
      ),
      body: Column(
        children: [
          // 🔍 SEARCH
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: const InputDecoration(
                hintText: 'Search dogs...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),

          // 📋 LIST
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final dog = _filtered[index];

                      // ✅ FIX: move logic OUTSIDE widget
                      String? imageUrl;

                      final heroData = dog['hero'];

                      if (heroData is List && heroData.isNotEmpty) {
                        final heroItem = heroData.firstWhere(
                          (e) => e['is_hero'] == true,
                          orElse: () => heroData.first,
                        );

                        final file = heroItem['url'];

                        if (file != null) {
                          imageUrl =
                              "https://phkwizyrpfzoecugpshb.supabase.co/storage/v1/object/public/dog_files/${dog['dog_ala']}/photos/$file";
                        }
                      }

                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imageUrl != null
                              ? Image.network(
                                  imageUrl,
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
                        title: Text(dog['dog_name'] ?? ''),
                        subtitle: Text("${dog['dog_ala']} • ${dog['sex']}"),
                        onTap: () {
                          Navigator.pop(context, dog['dog_ala']);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}