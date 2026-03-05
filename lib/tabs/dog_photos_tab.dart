import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'photo_viewer_page.dart';

class DogPhotosTab extends StatefulWidget {
  final String dogId;
  final String dogAla;
  final VoidCallback? onHeroChanged;

  const DogPhotosTab({
    super.key,
    required this.dogId,
    required this.dogAla,
    this.onHeroChanged,
  });

  @override
  State<DogPhotosTab> createState() => _DogPhotosTabState();
}

class _DogPhotosTabState extends State<DogPhotosTab> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> photos = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadPhotos();
  }

  /*
  =====================================================
  LOAD PHOTOS
  =====================================================
  */

  Future<void> loadPhotos() async {
    setState(() => loading = true);

    final response = await supabase
        .from('dog_photos')
        .select()
        .eq('dog_id', widget.dogId)
        .order('display_order', ascending: true);

    photos = List<Map<String, dynamic>>.from(response);

    setState(() => loading = false);
  }

  /*
  =====================================================
  STORAGE HELPERS
  =====================================================
  */

  String buildStoragePath(String fileName) {
    return "${widget.dogAla}/photos/$fileName";
  }

  String getFullUrl(String fileName) {
    return supabase.storage
        .from('dog_files')
        .getPublicUrl("${widget.dogAla}/photos/$fileName");
  }

  /*
  =====================================================
  SET HERO
  =====================================================
  */

  Future<void> setHero(Map<String, dynamic> photo) async {
    final photoId = photo['id'];
    final fileName = photo['url'];

    if (photoId == null || fileName == null) return;

    // Reset all hero flags
    await supabase
        .from('dog_photos')
        .update({'is_hero': false})
        .eq('dog_id', widget.dogId);

    // Set selected photo as hero
    await supabase
        .from('dog_photos')
        .update({'is_hero': true})
        .eq('id', photoId);

    // Copy file to hero.jpg
    final originalPath = buildStoragePath(fileName);
    final heroPath = buildStoragePath("hero.jpg");

    final bytes =
        await supabase.storage.from('dog_files').download(originalPath);

    await supabase.storage.from('dog_files').uploadBinary(
          heroPath,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    await loadPhotos();
    widget.onHeroChanged?.call();
  }

  /*
  =====================================================
  UPLOAD PHOTO
  =====================================================
  */

  Future<void> uploadPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);

    final extension = file.path.split('.').last.toLowerCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = "$timestamp.$extension";

    final storagePath = buildStoragePath(fileName);

    await supabase.storage
        .from('dog_files')
        .upload(
          storagePath,
          file,
        );

    await supabase.from('dog_photos').insert({
      'dog_id': widget.dogId,
      'url': fileName,
      'description': '',
      'is_hero': false,
    });

    await loadPhotos();
  }

  /*
  =====================================================
  PHOTO CARD
  =====================================================
  */

  Widget buildPhotoCard(Map<String, dynamic> photo) {
    final fileName = photo['url'] ?? "";
    final description = photo['description'] ?? "";

    final fullUrl = getFullUrl(fileName);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoViewerPage(
              imageUrl: fullUrl,
              photo: photo,
              dogId: widget.dogId,
              dogAla: widget.dogAla,
            ),
          ),
        );

        // Always refresh photos when returning
        await loadPhotos();
        widget.onHeroChanged?.call();
      },
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // IMAGE
            Expanded(
              child: Stack(
                children: [

                  // IMAGE
                  Positioned.fill(
                    child: Image.network(
                      fullUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),

                  // HERO STAR
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white70,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        icon: Icon(
                          photo['is_hero'] == true
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () => setHero(photo),
                      ),
                    ),
                  ),

                ],
              ),
            ),

            // DESCRIPTION BELOW IMAGE
            if (description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /*
  =====================================================
  UI
  =====================================================
  */

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: ElevatedButton.icon(
            onPressed: uploadPhoto,
            icon: const Icon(Icons.add_a_photo),
            label: const Text("Add Photo"),
          ),
        ),
        Expanded(
          child: photos.isEmpty
              ? const Center(child: Text("No photos uploaded"))
              : ReorderableGridView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: photos.length,

                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.75,
                  ),

                  onReorder: (oldIndex, newIndex) async {

                    final item = photos.removeAt(oldIndex);
                    photos.insert(newIndex, item);

                    setState(() {});

                    // Save new order to Supabase
                    for (int i = 0; i < photos.length; i++) {
                      await supabase
                          .from('dog_photos')
                          .update({'display_order': i})
                          .eq('id', photos[i]['id']);
                    }
                  },

                  itemBuilder: (context, index) {
                    return ReorderableDragStartListener(
                      key: ValueKey(photos[index]['id']),
                      index: index,
                      child: buildPhotoCard(photos[index]),
                    );
                  },
                )
        ),
      ],
    );
  }
}