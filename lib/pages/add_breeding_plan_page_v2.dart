import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/breeding_plan_service.dart';

class AddBreedingPlanPageV2 extends StatefulWidget {
  final String femaleAla;

  const AddBreedingPlanPageV2({
    Key? key,
    required this.femaleAla,
  }) : super(key: key);

  @override
  State<AddBreedingPlanPageV2> createState() =>
      _AddBreedingPlanPageV2State();
}

class _AddBreedingPlanPageV2State
    extends State<AddBreedingPlanPageV2> {
  final SupabaseClient _client = Supabase.instance.client;

  final TextEditingController _searchController =
      TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _allDogs = [];
  List<Map<String, dynamic>> _filteredDogs = [];

  Map<String, dynamic>? _selectedDog;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    print("🔥 V2 PAGE LOADED 🔥");
    _loadDogs();
  }

  Future<void> _loadDogs() async {
    final response = await _client
        .from('dogs_list_view_with_hero')
        .select('dog_name, dog_ala, sex')
        .order('dog_name');

    _allDogs = List<Map<String, dynamic>>.from(response);

    _applySearch();

    setState(() {
      _loading = false;
    });
  }

  void _applySearch() {
    final search = _searchController.text.toLowerCase().trim();

    _filteredDogs = _allDogs.where((dog) {
      if (search.isEmpty) return true;

      final name =
          (dog['dog_name'] ?? '').toString().toLowerCase();
      final ala =
          (dog['dog_ala'] ?? '').toString().toLowerCase();

      return name.contains(search) || ala.contains(search);
    }).toList();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 200), () {
      setState(() {
        _applySearch();
      });
    });
  }

  Future<void> _createPlan() async {
    if (_selectedDog == null) return;

    setState(() => _loading = true);

    await BreedingPlanService.createBreedingPlan(
      femaleDogAla: widget.femaleAla,
      maleDogAla: _selectedDog!['dog_ala'],
      breedingPlanCode: 'TEMP-B01',
    );

    setState(() => _loading = false);

    if (mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Male (V2)'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search dogs...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filteredDogs.length,
                    itemBuilder: (context, index) {
                      final dog = _filteredDogs[index];
                      final isSelected =
                          _selectedDog?['dog_ala'] ==
                              dog['dog_ala'];

                      return ListTile(
                        title: Text(dog['dog_name'] ?? ''),
                        subtitle: Text(
                            "${dog['dog_ala']} • ${dog['sex']}"),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle,
                                color: Colors.green)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedDog = dog;
                          });
                        },
                      );
                    },
                  ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _selectedDog == null || _loading
                        ? null
                        : _createPlan,
                child: const Text('Create Breeding Plan'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}