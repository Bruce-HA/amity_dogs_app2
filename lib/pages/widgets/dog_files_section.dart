import 'dart:io';

import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:file_picker/file_picker.dart';

import 'package:path/path.dart' as path;

import 'photo_viewer_page.dart';

class DogFilesSection extends StatefulWidget {
  final String dogId;

  const DogFilesSection({super.key, required this.dogId});

  @override
  State<DogFilesSection> createState() => _DogFilesSectionState();
}

class _DogFilesSectionState extends State<DogFilesSection> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> files = [];

  String? _lastDirectory;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadFiles();
  }

  Future<void> loadFiles() async {
    final result = await supabase
        .from('dog_files')
        .select()
        .eq('dog_id', widget.dogId)
        .order('sort_order');

    setState(() {
      files = List<Map<String, dynamic>>.from(result);

      loading = false;
    });
  }

  Future<void> setPrimaryPhoto(Map<String, dynamic> file) async {
    // remove existing primary

    await supabase
        .from('dog_files')
        .update({'is_primary': false})
        .eq('dog_id', widget.dogId);

    // set new primary

    await supabase
        .from('dog_files')
        .update({'is_primary': true})
        .eq('id', file['id']);

    // update dogs table profile photo

    await supabase
        .from('dogs')
        .update({'dog_photo': file['file_url']})
        .eq('id', widget.dogId);

    loadFiles();
  }

  Future<void> pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      initialDirectory: _lastDirectory,
    );

    if (result == null) return;

    final selectedPath = result.files.single.path!;

    // Save folder path for next time
    _lastDirectory = File(selectedPath).parent.path;

    final file = File(selectedPath);

    await uploadSelectedFile(file);
  }

  // add line here
  Future<void> deleteFile(Map<String, dynamic> file) async {
    final confirm = await showDialog<bool>(
      context: context,

      builder: (_) {
        return AlertDialog(
          title: const Text("Delete File"),

          content: const Text("Are you sure you want to delete this file?"),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),

              child: const Text("Cancel"),
            ),

            TextButton(
              onPressed: () => Navigator.pop(context, true),

              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      // Remove from storage
      final fileUrl = file['file_url'].toString();

      final uri = Uri.parse(fileUrl);

      final pathSegments = uri.pathSegments;

      final filePath = pathSegments.skip(1).join('/');

      await supabase.storage.from('dog_files').remove([filePath]);

      // If primary photo → clear dogs table
      if (file['is_primary'] == true) {
        await supabase
            .from('dogs')
            .update({'dog_photo': null})
            .eq('id', widget.dogId);
      }

      // Remove DB record
      await supabase.from('dog_files').delete().eq('id', file['id']);

      await loadFiles();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Delete failed: $e")));
    }
  }

  // add lines above
  Future<void> uploadSelectedFile(File file) async {
    final ext = path.extension(file.path);

    final type = ['.jpg', '.jpeg', '.png'].contains(ext.toLowerCase())
        ? 'photo'
        : 'document';

    final fileName =
        "${widget.dogId}/"
        "$type/"
        "${DateTime.now().millisecondsSinceEpoch}"
        "$ext";

    final bytes = await file.readAsBytes();

    await supabase.storage
        .from('dog_files')
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    final url = supabase.storage.from('dog_files').getPublicUrl(fileName);

    // 🔎 Check if a primary photo already exists
    bool makePrimary = false;

    if (type == 'photo') {
      final existingPrimary = await supabase
          .from('dog_files')
          .select()
          .eq('dog_id', widget.dogId)
          .eq('is_primary', true)
          .maybeSingle();

      if (existingPrimary == null) {
        makePrimary = true;
      }
    }

    // Insert file record
    final inserted = await supabase
        .from('dog_files')
        .insert({
          'dog_id': widget.dogId,
          'file_name': path.basename(file.path),
          'file_url': url,
          'file_type': type,
          'is_primary': makePrimary,
        })
        .select()
        .single();

    // If this is the first photo → update dogs table
    if (makePrimary) {
      await supabase
          .from('dogs')
          .update({'dog_photo': url})
          .eq('id', widget.dogId);
    }

    await loadFiles();
  }

  Future<void> editDescription(Map<String, dynamic> file) async {
    final controller = TextEditingController(text: file['description']);

    await showDialog(
      context: context,

      builder: (_) {
        return AlertDialog(
          title: const Text("Description"),

          content: TextField(controller: controller),

          actions: [
            TextButton(
              onPressed: () async {
                await supabase
                    .from('dog_files')
                    .update({'description': controller.text})
                    .eq('id', file['id']);

                Navigator.pop(context);

                loadFiles();
              },

              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final photos = files.where((f) => f['file_type'] == 'photo').toList();

    final documents = files.where((f) => f['file_type'] == 'document').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: [
            const Text(
              "Photos & Files",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            IconButton(
              icon: const Icon(Icons.add),
              onPressed: pickAndUploadFile,
            ),
          ],
        ),

        // REORDERABLE PHOTO LIST
        ReorderableListView.builder(
          shrinkWrap: true,

          physics: const NeverScrollableScrollPhysics(),

          itemCount: photos.length,

          onReorder: (oldIndex, newIndex) async {
            if (newIndex > oldIndex) {
              newIndex--;
            }

            final item = photos.removeAt(oldIndex);

            photos.insert(newIndex, item);

            for (int i = 0; i < photos.length; i++) {
              await supabase
                  .from('dog_files')
                  .update({'sort_order': i})
                  .eq('id', photos[i]['id']);
            }

            setState(() {});
          },

          itemBuilder: (_, index) {
            final file = photos[index];

            return ListTile(
              key: ValueKey(file['id']),

              leading: GestureDetector(
                onTap: () {
                  final photoUrls = photos
                      .map((p) => p['file_url'].toString())
                      .toList();

                  Navigator.push(
                    context,

                    MaterialPageRoute(
                      builder: (_) => PhotoViewerPage(
                        photos: photoUrls,
                        initialIndex: index,
                      ),
                    ),
                  );
                },

                onLongPress: () => deleteFile(file),

                child: Padding(
                  padding: const EdgeInsets.all(6),

                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),

                    child: Stack(
                      children: [
                        Image.network(
                          file['file_url'],
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),

                        if (file['is_primary'] == true)
                          const Positioned(
                            right: 6,
                            top: 6,

                            child: Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              title: Text(file['description'] ?? ""),

              trailing: IconButton(
                icon: const Icon(Icons.star),

                onPressed: () => setPrimaryPhoto(file),
              ),
            );
          },
        ),

        const SizedBox(height: 20),

        // DOCUMENT LIST
        ...documents.map(
          (file) => ListTile(
            leading: const Icon(Icons.description),

            title: Text(file['file_name']),

            subtitle: Text(file['description'] ?? ""),

            onTap: () => editDescription(file),
          ),
        ),
      ],
    );
  }
}
