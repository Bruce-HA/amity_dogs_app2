import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dog_model.dart';

class DogService {
  final _client = Supabase.instance.client;

  Future<List<Dog>> fetchDogs({
    String search = '',
    String selectedType = 'All',
  }) async {
    var query = _client.from('dogs').select();

    // Search across multiple fields
    if (search.isNotEmpty) {
      query = query.or(
        'dog_name.ilike.%$search%,'
        'pet_name.ilike.%$search%,'
        'microchip.ilike.%$search%',
      );
    }

    // Filter by dog_type
    if (selectedType != 'All') {
      query = query.eq('dog_type', selectedType);
    }

    final response = await query.order('dog_name', ascending: true);

    return (response as List).map((dog) => Dog.fromMap(dog)).toList();
  }
}
