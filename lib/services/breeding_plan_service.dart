import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class BreedingPlanService {
  /// Create a new breeding plan
  static Future<Map<String, dynamic>?> createBreedingPlan({
    required String femaleDogAla,
    required String maleDogAla,
    required String breedingPlanCode,
    String? coatPrediction,
    String? dnaSummary,
    String? expectedSize,
    String? expectedColour,
    String? notes,
  }) async {
    final response = await supabase
        .from('breeding_plans')
        .insert({
          'female_dog_ala': femaleDogAla,
          'male_dog_ala': maleDogAla,
          'breeding_plan_code': breedingPlanCode,
          'coat_prediction': coatPrediction,
          'dna_summary': dnaSummary,
          'expected_size': expectedSize,
          'expected_colour': expectedColour,
          'notes': notes,
          'status': 'planned',
          'is_active': true,
        })
        .select()
        .single();

    return response;
    
  }

  /// Get all breeding plans
  static Future<List<Map<String, dynamic>>> getBreedingPlans() async {
    final response = await supabase
        .from('breeding_plans')
        .select()
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get breeding plans for a specific female
  static Future<List<Map<String, dynamic>>> getPlansByFemale(
      String femaleDogAla) async {
    final response = await supabase
        .from('breeding_plans')
        .select()
        .eq('female_dog_ala', femaleDogAla)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }
}
