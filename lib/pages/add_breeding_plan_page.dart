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
  final _client = Supabase.instance.client;
  final _service = BreedingPlanService();

  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _selectedMale;
  bool _loading = false;

  Future<void> _searchMales(String query) async {
    final response = await _client
        .from('dogs')
        .select()
        .eq('sex', 'male')
        .neq('dog_status', 'Pet')
        .neq('dog_status', 'Deceased')
        .or(
          'dog_name.ilike.%$query%,'
          'dog_ala.ilike.%$query%,'
          'microchip.ilike.%$query%',
        )
        .order('dog_name');

    setState(() {
      _results = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> _createPlan() async {
    if (_selectedMale == null) return;

    setState(() => _loading = true);

    await _service.createBreedingPlan(
      femaleAla: widget.femaleAla,
      maleAla: _selectedMale!['dog_ala'],
    );

    setState(() => _loading = false);

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Breeding Plan'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search Male (Name, ALA, Microchip)',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                if (value.length >= 2) {
                  _searchMales(value);
                } else {
                  setState(() => _results = []);
                }
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _results.isEmpty
                  ? const Center(
                      child: Text('Search to find a male.'),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final dog = _results[index];
                        final isSelected =
                            _selectedMale?['dog_ala'] == dog['dog_ala'];

                        return Card(
                          child: ListTile(
                            title: Text(dog['dog_name'] ?? ''),
                            subtitle: Text(dog['dog_ala'] ?? ''),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedMale = dog;
                              });
                            },
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _selectedMale == null || _loading ? null : _createPlan,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Create Breeding Plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}