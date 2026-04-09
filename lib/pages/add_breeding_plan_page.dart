import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/breeding_plan_service.dart';

class AddBreedingPlanPage extends StatefulWidget {
  final String femaleAla;

  const AddBreedingPlanPage({
    Key? key,
    required this.femaleAla,
  }) : super(key: key);

  @override
  State<AddBreedingPlanPage> createState() => _AddBreedingPlanPageState();
}

class _AddBreedingPlanPageState extends State<AddBreedingPlanPage> {
  final SupabaseClient _client = Supabase.instance.client;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _dogs = [];
  Map<String, dynamic>? _selectedDog;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    print("🔥 ADD BREEDING PAGE LOADED 🔥");
    _fetchDogs();
  }

  // 🔍 SEARCH HANDLER
  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchDogs();
    });
  }

  // 📡 FETCH DOGS (same as DogsPage)
  Future<void> _fetchDogs() async {
    final response = await _client
        .from('dogs_list_view_with_hero')
        .select('dog_name, dog_ala')
        .order('dog_name');

    print("TOTAL DOGS: ${response.length}");

    final turkish = response.where(
      (d) => (d['dog_name'] ?? '').toString().contains('Turkish'),
    );

    print("TURKISH FOUND: $turkish");

    setState(() {
      _dogs = List<Map<String, dynamic>>.from(response);
    });
  }

  // 🧬 CREATE PLAN
  Future<void> _createPlan() async {
    if (_selectedDog == null) return;

    final maleAla = _selectedDog?['dog_ala'] as String?;

    if (maleAla == null) return;

    setState(() => _loading = true);

    await BreedingPlanService.createBreedingPlan(
      femaleDogAla: widget.femaleAla,
      maleDogAla: maleAla,
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

  // 🧱 UI
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TEST PAGE')),
      body: const Center(
        child: Text(
          '🔥 IF YOU SEE THIS, THIS PAGE IS RUNNING 🔥',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
}
}