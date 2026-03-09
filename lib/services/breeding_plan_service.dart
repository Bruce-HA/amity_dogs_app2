import 'package:supabase_flutter/supabase_flutter.dart';

class BreedingPlanService {
  final _client = Supabase.instance.client;

  // 1️⃣ Fetch Breeding Plans by Female
  Future<List<Map<String, dynamic>>> fetchPlansByFemale(String femaleAla) async {
    final response = await _client
        .from('breeding_plans')
        .select()
        .eq('female_dog_ala', femaleAla)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // 2️⃣ Count Total Puppies for Female
  Future<int> getFemalePuppyCount(String femaleAla) async {
    final response = await _client
        .from('dogs')
        .select('dog_ala')
        .eq('mother_ala', femaleAla)
        .eq('is_ghost', false);

    return (response as List).length;
  }

  // 3️⃣ Count Total Litters (via ALA prefix parsing)
  Future<int> getFemaleLitterCount(String femaleAla) async {
    final response = await _client
        .from('dogs')
        .select('dog_ala')
        .eq('mother_ala', femaleAla)
        .eq('is_ghost', false);

    final dogs = List<Map<String, dynamic>>.from(response);

    final litterPrefixes = dogs.map((dog) {
      final ala = dog['dog_ala'] as String;
      return ala.substring(0, 8); // 0174-020
    }).toSet();

    return litterPrefixes.length;
  }

  // 4️⃣ Count Active Plans
  Future<int> getActivePlanCount(String femaleAla) async {
    final response = await _client
        .from('breeding_plans')
        .select('breeding_plan_code')
        .eq('female_dog_ala', femaleAla)
        .eq('status', 'active');

    return (response as List).length;
  }

  // 5️⃣ Generate Next Breeding Plan Code
  Future<String> generateNextPlanCode(String femaleAla) async {
    final response = await _client
        .from('breeding_plans')
        .select('breeding_plan_code')
        .eq('female_dog_ala', femaleAla);

    final plans = List<Map<String, dynamic>>.from(response);

    int maxNumber = 0;

    for (var plan in plans) {
      final code = plan['breeding_plan_code'] as String;
      final match = RegExp(r'B(\d+)$').firstMatch(code);
      if (match != null) {
        final number = int.parse(match.group(1)!);
        if (number > maxNumber) maxNumber = number;
      }
    }

    final nextNumber = (maxNumber + 1).toString().padLeft(2, '0');
    return '$femaleAla-B$nextNumber';
  }

  // 6️⃣ Create Breeding Plan
  Future<void> createBreedingPlan({
    required String femaleAla,
    required String maleAla,
    double? inbreedingCoefficient,
    String? expectedSize,
    String? expectedColour,
    String? notes,
  }) async {
    final planCode = await generateNextPlanCode(femaleAla);

    await _client.from('breeding_plans').insert({
      'breeding_plan_code': planCode,
      'female_dog_ala': femaleAla,
      'male_dog_ala': maleAla,
      'inbreeding_coefficient': inbreedingCoefficient,
      'expected_size': expectedSize,
      'expected_colour': expectedColour,
      'status': 'active',
      'notes': notes,
    });
  }

  // 7️⃣ Archive Plan
  Future<void> archivePlan(String planCode) async {
    await _client
        .from('breeding_plans')
        .update({'status': 'archived'})
        .eq('breeding_plan_code', planCode);
  }
}