import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/breeding_plan_service.dart';
import '../pages/add_breeding_plan_page.dart';

class DogBreedingTab extends StatefulWidget {
  final String dogId;

  const DogBreedingTab({Key? key, required this.dogId}) : super(key: key);

  @override
  State<DogBreedingTab> createState() => _DogBreedingTabState();
}

class _DogBreedingTabState extends State<DogBreedingTab> {
  final _client = Supabase.instance.client;
  final _service = BreedingPlanService();

  Map<String, dynamic>? _dog;
  bool _loadingDog = true;

  late Future<int> _puppyCount;
  late Future<int> _litterCount;
  late Future<int> _activePlanCount;
  late Future<List<Map<String, dynamic>>> _plansFuture;

  @override
  void initState() {
    super.initState();
    _loadDog();
  }

  Future<void> _loadDog() async {
    final response = await _client
        .from('dogs')
        .select()
        .eq('id', widget.dogId)
        .single();

    _dog = response;

    _loadBreedingData();

    setState(() {
      _loadingDog = false;
    });
  }

  void _loadBreedingData() {
    final dogAla = _dog!['dog_ala'];

    _puppyCount = _service.getFemalePuppyCount(dogAla);
    _litterCount = _service.getFemaleLitterCount(dogAla);
    _activePlanCount = _service.getActivePlanCount(dogAla);
    _plansFuture = _service.fetchPlansByFemale(dogAla);
  }

  bool get _canAddPlan {
    final sex = (_dog?['sex'] ?? '').toString().toLowerCase();
    final status = (_dog?['dog_status'] ?? '').toString().toLowerCase();

    return sex == 'female' &&
        status != 'pet' &&
        status != 'deceased';
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingDog) {
      return const Center(child: CircularProgressIndicator());
    }

    final sex = (_dog?['sex'] ?? '').toString().toLowerCase();

    // Male view placeholder (we'll build this next)
    if (sex != 'female') {
      return const Center(
        child: Text('Stud view coming next stage'),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadDog();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummarySection(),
            const SizedBox(height: 24),
            _buildBreedingPlansSection(),
          ],
        ),
      ),
    );
  }

  // ---------------- SUMMARY ----------------

  Widget _buildSummarySection() {
    return Row(
      children: [
        Expanded(child: _buildSummaryCard('Litters', _litterCount)),
        const SizedBox(width: 12),
        Expanded(child: _buildSummaryCard('Puppies', _puppyCount)),
        const SizedBox(width: 12),
        Expanded(child: _buildSummaryCard('Active Plans', _activePlanCount)),
      ],
    );
  }

  Widget _buildSummaryCard(String title, Future<int> futureValue) {
    return FutureBuilder<int>(
      future: futureValue,
      builder: (context, snapshot) {
        final value = snapshot.data ?? 0;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------- BREEDING PLANS ----------------

  Widget _buildBreedingPlansSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Breeding Plans',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (_canAddPlan)
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddBreedingPlanPage(
                        femaleAla: _dog!['dog_ala'],
                      ),
                    ),
                  );

                  if (result == true) {
                    await _loadDog();
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _plansFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final plans = snapshot.data ?? [];

            if (plans.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No breeding plans created yet.'),
              );
            }

            return Column(
              children: plans.map((plan) {
                return _buildPlanTile(plan);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPlanTile(Map<String, dynamic> plan) {
    final status = plan['status'] ?? 'active';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          plan['breeding_plan_code'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Male: ${plan['male_dog_ala'] ?? ''}'),
            if (plan['inbreeding_coefficient'] != null)
              Text('IC: ${plan['inbreeding_coefficient']}'),
          ],
        ),
        trailing: Chip(
          label: Text(
            status.toUpperCase(),
            style: const TextStyle(fontSize: 12),
          ),
          backgroundColor:
              status == 'active'
                  ? Colors.green.shade100
                  : Colors.grey.shade300,
        ),
      ),
    );
  }
}