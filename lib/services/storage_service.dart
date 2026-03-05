iimport 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class DogStorageService {

  static final _client = Supabase.instance.client;

  static const String bucket = 'dog_files';

  /*
  ============================================================
  PATH BUILDERS
  ============================================================
  */

  static String photoPath({
    required String dogId,
    required String dogAla,
    required String fileName,
  }) {
    return '$dogId/$dogAla/photo/$fileName';
  }

  static String documentPath({
    required String dogId,
    required String dogAla,
    required String fileName,
  }) {
    return '$dogId/$dogAla/documents/$fileName';
  }

  static String heroPath({
    required String dogId,
    required String dogAla,
  }) {
    return '$dogId/$dogAla/photo/hero.jpg';
  }

  /*
  ============================================================
  UPLOAD PHOTO
  ============================================================
  */

  static Future<void> uploadPhoto({
    required String dogId,
    required String dogAla,
    required File file,
  }) async {

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}.jpg';

    final path = photoPath(
      dogId: dogId,
      dogAla: dogAla,
      fileName: fileName,
    );

    await _client.storage
        .from(bucket)
        .upload(path, file);
  }

  /*
  ============================================================
  UPLOAD HERO IMAGE
  ============================================================
  */

  static Future<void> uploadHeroImage({
    required String dogId,
    required String dogAla,
    required File file,
  }) async {

    final path = heroPath(
      dogId: dogId,
      dogAla: dogAla,
    );

    await _client.storage
        .from(bucket)
        .upload(
          path,
          file,
          fileOptions:
              const FileOptions(upsert: true),
        );
  }

  /*
  ============================================================
  LIST PHOTOS
  Supports NEW structure + OLD fallback
  ============================================================
  */

  static Future<List<String>> listPhotos({
    required String dogId,
    required String dogAla,
  }) async {

    final List<String> urls = [];

    // NEW STRUCTURE
    final newPath = '$dogId/$dogAla/photo';

    try {

      final files = await _client.storage
          .from(bucket)
          .list(path: newPath);

      for (final file in files) {

        final url = _client.storage
            .from(bucket)
            .getPublicUrl('$newPath/${file.name}');

        urls.add(url);
      }

      if (urls.isNotEmpty) {
        return urls;
      }

    } catch (_) {}

    // FALLBACK OLD STRUCTURE

    final oldPath = '$dogId/photo';

    try {

      final files = await _client.storage
          .from(bucket)
          .list(path: oldPath);

      for (final file in files) {

        final url = _client.storage
            .from(bucket)
            .getPublicUrl('$oldPath/${file.name}');

        urls.add(url);
      }

    } catch (_) {}

    return urls;
  }

  /*
  ============================================================
  LIST DOCUMENTS
  ============================================================
  */

  static Future<List<String>> listDocuments({
    required String dogId,
    required String dogAla,
  }) async {

    final path = '$dogId/$dogAla/documents';

    final files = await _client.storage
        .from(bucket)
        .list(path: path);

    return files.map((file) {

      return _client.storage
          .from(bucket)
          .getPublicUrl('$path/${file.name}');

    }).toList();
  }

  /*
  ============================================================
  GET HERO IMAGE
  ============================================================
  */

  static Future<String?> getHeroImage({
    required String dogId,
    required String dogAla,
  }) async {

    final path = heroPath(
      dogId: dogId,
      dogAla: dogAla,
    );

    try {

      final url = _client.storage
          .from(bucket)
          .getPublicUrl(path);

      return url;

    } catch (_) {

      return null;

    }
  }

  /*
  ============================================================
  UPLOAD DOCUMENT
  ============================================================
  */

  static Future<void> uploadDocument({
    required String dogId,
    required String dogAla,
    required File file,
  }) async {

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}.jpg';

    final path = documentPath(
      dogId: dogId,
      dogAla: dogAla,
      fileName: fileName,
    );

    await _client.storage
        .from(bucket)
        .upload(path, file);
  }

}