import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:amity_dogs_app/tabs/photo_viewer_page.dart';
import 'package:image/image.dart' as img;

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

  static const int maxUploadWidth = 1600;
  static const int jpgQuality = 85;

  @override
  void initState() {
    super.initState();
    loadPhotos();
    debugPrint("DOG ALA: ${widget.dogAla}");
  }

  /*
  =============================
  LOAD PHOTOS
  =============================
  */

  Future<void> loadPhotos() async {
    setState(() => loading = true);

    final response = await supabase
        .from('dog_photos')
        .select()
        .eq('dog_id', widget.dogId)
        .order('is_hero', ascending: false)
        .order('display_order', ascending: true)
        .order('created_at', ascending: false);

    photos = List<Map<String, dynamic>>.from(response)
      .where((p) => p['photo_exists_on_zooeasy'] != false)
      .toList();

    if (!mounted) return;
    setState(() => loading = false);
  }

  /*
  =============================
  STORAGE HELPERS
  =============================
  */

  String buildStoragePath(String fileName) {
    return "${widget.dogAla}/photos/$fileName";
  }

  String getFullUrl(String fileName) {
    return supabase.storage
        .from('dog_files')
        .getPublicUrl(buildStoragePath(fileName));
  }

  String getDisplayUrl(String fileName) {
    return supabase.storage.from('dog_files').getPublicUrl(
          buildStoragePath(fileName),
          transform: const TransformOptions(
            width: 600,
            height: 800,
            resize: ResizeMode.cover,
            quality: 70,
          ),
        );
  }

  /*
  =============================
  IMAGE PROCESSING
  =============================
  */

  Uint8List? processImageBytes({
    required Uint8List originalBytes,
    required String extension,
  }) {
    final decodedImage = img.decodeImage(originalBytes);

    if (decodedImage == null) {
      return null;
    }

    final resized = decodedImage.width > maxUploadWidth
        ? img.copyResize(
            decodedImage,
            width: maxUploadWidth,
          )
        : decodedImage;

    final ext = extension.toLowerCase();

    // Keep PNG as PNG because it may contain transparency.
    if (ext == 'png') {
      return Uint8List.fromList(img.encodePng(resized));
    }

    // For jpg/jpeg/heic/webp inputs, store as JPG.
    // This keeps the app reliable because Dart image encoding support
    // for HEIC/WebP output can be inconsistent.
    return Uint8List.fromList(
      img.encodeJpg(
        resized,
        quality: jpgQuality,
      ),
    );
  }

  String cleanExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length < 2) return 'jpg';

    final ext = parts.last.toLowerCase().trim();

    if (ext == 'jpeg') return 'jpg';
    if (ext == 'png') return 'png';
    if (ext == 'jpg') return 'jpg';

    // HEIC and WEBP are decoded, resized, then stored as JPG.
    if (ext == 'heic') return 'jpg';
    if (ext == 'webp') return 'jpg';

    return 'jpg';
  }

  /*
  =============================
  SET HERO
  =============================
  */

  Future<void> setHero(Map<String, dynamic> photo) async {
    final photoId = photo['id'];

    if (photoId == null) return;

    await supabase
        .from('dog_photos')
        .update({'is_hero': false})
        .eq('dog_id', widget.dogId);

    await supabase
        .from('dog_photos')
        .update({'is_hero': true})
        .eq('id', photoId);

    // IMPORTANT:
    // We do NOT create hero.jpg anymore.
    // Hero image is controlled only by dog_photos.is_hero.

    await loadPhotos();
    widget.onHeroChanged?.call();
  }

  /*
  =============================
  UPLOAD PHOTO
  =============================
  */

  Future<void> uploadPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'heic', 'webp'],
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) return;

    final pickedFile = result.files.single;
    final originalBytes = pickedFile.bytes!;

    final extension = cleanExtension(pickedFile.name);

    final processedBytes = processImageBytes(
      originalBytes: originalBytes,
      extension: extension,
    );

    if (processedBytes == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Could not process image"),
        ),
      );

      return;
    }

    final fileName =
        "${DateTime.now().millisecondsSinceEpoch}.$extension";

    final storagePath = buildStoragePath(fileName);

    await supabase.storage.from('dog_files').uploadBinary(
          storagePath,
          processedBytes,
          fileOptions: const FileOptions(
            upsert: true,
          ),
        );

    await supabase.from('dog_photos').insert({
      'dog_id': widget.dogId,
      'dog_ala': widget.dogAla,
      'file_name': fileName,
      'url': fileName,
      'thumb_url': fileName,
      'description': '',
      'is_hero': photos.isEmpty,
      'display_order': photos.length,
      'rotation': 0,
      'photo_exists_on_zooeasy': false,
    });

    await loadPhotos();
    widget.onHeroChanged?.call();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Photo uploaded"),
      ),
    );
  }

  /*
  =============================
  PHOTO CARD
  =============================
  */

  Widget buildPhotoCard(Map<String, dynamic> photo) {
    final fileName = photo['url'] ?? "";
    final description = photo['description'] ?? "";
    final displayUrl = getDisplayUrl(fileName);
    final fullUrl = getFullUrl(fileName);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoViewerPage(
              dogAla: widget.dogAla,
              dogId: widget.dogId,
              imageUrl: fullUrl,
              photo: photo,
            ),
          ),
        );

        await loadPhotos();
        widget.onHeroChanged?.call();
      },
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Transform.rotate(
                      angle: ((photo['rotation'] ?? 0) as num).toDouble() *
                          3.1415926535 /
                          180,
                      child: Image.network(
                        displayUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            color: Colors.grey.shade300,
                            child: const Center(
                              child: Icon(Icons.pets),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  Positioned(
                    top: 4,
                    right: 4,
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
                ],
              ),
            ),

            if (description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /*
  =============================
  UI
  =============================
  */

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
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
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.75,
                  ),
                  onReorder: (oldIndex, newIndex) async {
                    final item = photos.removeAt(oldIndex);
                    photos.insert(newIndex, item);

                    setState(() {});

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
                ),
        ),
      ],
    );
  }
}