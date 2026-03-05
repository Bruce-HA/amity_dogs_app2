import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class DogStorageService {
  static final supabase = Supabase.instance.client;

  static const String bucket = "dog_files";

  /// Base public URL
  static const String baseUrl =
      "https://phkwizyrpfzoecugpshb.supabase.co/storage/v1/object/public/$bucket";

  /// Build full public URL
  static String getPublicUrl({
    required String dogId,
    required String dogAla,
    required String folder,
    required String fileName,
  }) {
    return "$baseUrl/$dogId/$dogAla/$folder/$fileName";
  }

  /// Upload file
  static Future<String> uploadFile({
    required File file,
    required String dogId,
    required String dogAla,
    required String folder, // photo, documents, etc
  }) async {
    final fileName = path.basename(file.path);

    final storagePath = "$dogId/$dogAla/$folder/$fileName";

    await supabase.storage.from(bucket).upload(
          storagePath,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    return fileName;
  }

  /// Upload photo and register in dog_photos table
  static Future<void> uploadDogPhoto({
    required File file,
    required String dogId,
    required String dogAla,
    String description = "",
  }) async {
    final fileName = await uploadFile(
      file: file,
      dogId: dogId,
      dogAla: dogAla,
      folder: "photo",
    );

    await supabase.from("dog_photos").insert({
      "dog_id": dogId,
      "url": fileName,
      "description": description,
    });
  }

  /// Get hero image URL
  static Future<String?> getHeroImageUrl({
    required String dogId,
    required String dogAla,
  }) async {
    final result = await supabase
        .from("dog_photos")
        .select()
        .eq("dog_id", dogId)
        .order("created_at", ascending: false)
        .limit(1);

    if (result.isEmpty) return null;

    final fileName = result.first["url"];

    return getPublicUrl(
      dogId: dogId,
      dogAla: dogAla,
      folder: "photo",
      fileName: fileName,
    );
  }

  /// Get all photo URLs
  static Future<List<String>> getPhotoUrls({
    required String dogId,
    required String dogAla,
  }) async {
    final result = await supabase
        .from("dog_photos")
        .select()
        .eq("dog_id", dogId)
        .order("created_at", ascending: false);

    return result.map<String>((photo) {
      return getPublicUrl(
        dogId: dogId,
        dogAla: dogAla,
        folder: "photo",
        fileName: photo["url"],
      );
    }).toList();
  }

  /// Delete file
  static Future<void> deleteFile({
    required String dogId,
    required String dogAla,
    required String folder,
    required String fileName,
  }) async {
    final storagePath = "$dogId/$dogAla/$folder/$fileName";

    await supabase.storage.from(bucket).remove([storagePath]);
  }

  /// Download file locally
  static Future<File> downloadFile({
    required String dogId,
    required String dogAla,
    required String folder,
    required String fileName,
    required String localPath,
  }) async {
    final storagePath = "$dogId/$dogAla/$folder/$fileName";

    final bytes =
        await supabase.storage.from(bucket).download(storagePath);

    final file = File(localPath);

    await file.writeAsBytes(bytes);

    return file;
  }
}
