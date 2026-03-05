import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> migrateStorage({
  required String dogId,
  required String dogAla,
}) async {

  final client = Supabase.instance.client;

  final oldPath = '$dogId/photo';
  final newPath = '$dogId/$dogAla/photo';

  final files = await client.storage
      .from('dog_files')
      .list(path: oldPath);

  for (final file in files) {

    final oldFilePath = '$oldPath/${file.name}';
    final newFilePath = '$newPath/${file.name}';

    final bytes = await client.storage
        .from('dog_files')
        .download(oldFilePath);

    await client.storage
        .from('dog_files')
        .uploadBinary(newFilePath, bytes);

  }

}