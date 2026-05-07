import 'package:supabase_flutter/supabase_flutter.dart';

class PedigreeService {
  final supabase = Supabase.instance.client;

  /*
  =============================
  PUBLIC ENTRY
  =============================
  */

  Future<Map<String, dynamic>> getPedigreeTree({
    required String dogId,
    int generations = 3,
  }) async {
    final dog = await _getDogById(dogId);

    if (dog == null) {
      throw Exception("Dog not found");
    }

    return _buildTree(dog, generations);
  }

  /*
  =============================
  CORE TREE BUILDER
  =============================
  */

  Future<Map<String, dynamic>> _buildTree(
    Map<String, dynamic> dog,
    int generations,
  ) async {
    if (generations <= 0) {
      return _formatDog(dog);
    }

    final mother = await _findParent(
      parentId: dog['mother_id'],
      parentAla: dog['mother_ala'],
    );

    final father = await _findParent(
      parentId: dog['father_id'],
      parentAla: dog['father_ala'],
    );

    return {
      ..._formatDog(dog),
      'mother': mother == null
          ? null
          : await _buildTree(
              mother,
              generations - 1,
            ),
      'father': father == null
          ? null
          : await _buildTree(
              father,
              generations - 1,
            ),
    };
  }

  /*
  =============================
  FIND PARENT
  =============================
  */

  Future<Map<String, dynamic>?> _findParent({
    required dynamic parentId,
    required dynamic parentAla,
  }) async {
    if (parentId != null && parentId.toString().isNotEmpty) {
      final byId = await _getDogById(parentId.toString());

      if (byId != null) return byId;
    }

    if (parentAla != null && parentAla.toString().trim().isNotEmpty) {
      final byAla = await _getDogByAla(parentAla.toString().trim());

      if (byAla != null) return byAla;
    }

    return null;
  }

  /*
  =============================
  FETCH DOG BY ID
  =============================
  */

  Future<Map<String, dynamic>?> _getDogById(String dogId) async {
    final res = await supabase
        .from('dogs')
        .select(_dogSelect)
        .eq('id', dogId)
        .maybeSingle();

    if (res == null) return null;

    final dogAla = (res['dog_ala'] ?? '').toString();
    final hero = await _getHeroImage(
      dogId: res['id'].toString(),
      dogAla: dogAla,
    );

    return {
      ...res,
      'hero': hero,
    };
  }

  /*
  =============================
  FETCH DOG BY ALA
  =============================
  */

  Future<Map<String, dynamic>?> _getDogByAla(String dogAla) async {
    final res = await supabase
        .from('dogs')
        .select(_dogSelect)
        .eq('dog_ala', dogAla)
        .maybeSingle();

    if (res == null) return null;

    final hero = await _getHeroImage(
      dogId: res['id'].toString(),
      dogAla: dogAla,
    );

    return {
      ...res,
      'hero': hero,
    };
  }

  /*
  =============================
  DOG SELECT
  =============================
  */

  String get _dogSelect => '''
    id,
    dog_name,
    dog_ala,
    dob,
    sex,
    colour,
    coat_type,
    microchip,
    mother_id,
    father_id,
    mother_ala,
    father_ala
  ''';

  /*
  =============================
  HERO IMAGE
  =============================
  */

  Future<String?> _getHeroImage({
    required String dogId,
    required String dogAla,
  }) async {
    if (dogAla.isEmpty) return null;

    final res = await supabase
        .from('dog_photos')
        .select('url')
        .eq('dog_id', dogId)
        .eq('is_hero', true)
        .maybeSingle();

    if (res == null || res['url'] == null) return null;

    return supabase.storage
        .from('dog_files')
        .getPublicUrl('$dogAla/photos/${res['url']}');
  }

  /*
  =============================
  FORMAT DOG
  =============================
  */

  Map<String, dynamic> _formatDog(Map<String, dynamic> dog) {
    return {
      'id': dog['id'],
      'name': dog['dog_name'],
      'ala': dog['dog_ala'],
      'dob': dog['dob'],
      'sex': dog['sex'],
      'colour': dog['colour'],
      'coat': dog['coat_type'],
      'microchip': dog['microchip'],
      'hero': dog['hero'],
      'mother_ala': dog['mother_ala'],
      'father_ala': dog['father_ala'],
    };
  }
}