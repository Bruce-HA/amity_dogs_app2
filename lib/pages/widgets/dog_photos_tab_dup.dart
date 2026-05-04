import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:amity_dogs_app/tabs/photo_viewer_page.dart';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class DogPhotosTab extends StatefulWidget {
  final String dogId;
  final String dogAla; // 👈 MUST EXIST

  const DogPhotosTab({
    super.key,
    required this.dogId,
    required this.dogAla,
  });

  @override
  State<DogPhotosTab> createState() => _DogPhotosTabState();
}

class _DogPhotosTabState extends State<DogPhotosTab> {

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> photos = [];

  bool loading = true;

  final String baseUrl =
      "https://phkwizyrpfzoecugpshb.supabase.co/storage/v1/object/public/dog_files";

  @override
  void initState() {
    super.initState();
    loadPhotos();
  }

  Future<void> uploadPhoto(File originalFile) async {
    final processed = await processImage(originalFile);

    final fileId = DateTime.now().millisecondsSinceEpoch.toString();

    final fullPath = "${widget.dogId}/photos/$fileId.webp";
    final thumbPath = "${widget.dogId}/thumbs/$fileId.webp";

    // Upload full image
    await supabase.storage
        .from('dog_files')
        .upload(fullPath, processed['full']!);

    // Upload thumbnail
    await supabase.storage
        .from('dog_files')
        .upload(thumbPath, processed['thumb']!);

    // Save to DB
    await supabase.from('dog_photos').insert({
      'dog_id': widget.dogId,
      'dog_ala': widget.dogAla,
      'url': fullPath,
      'thumb_url': thumbPath,
      'rotation': 0,
    });
  }
/*
  String getFullUrl(String fileName) {

    fileName = fileName.split("/").last;

    final url =
        "$baseUrl/${widget.dogId}/photo/$fileName";

    print("PHOTO URL: $url");

    return url;
  }
  */
  Future<void> loadPhotos() async {
    setState(() {
      loading = true;
    });

    final response = await supabase
        .from('dog_photos')
        .select()
        .eq('dog_id', widget.dogId)
        .order('created_at', ascending: false);

    setState(() {
      photos = List<Map<String, dynamic>>.from(response);
      loading = false;
    });
  }

  Future<void> pickAndUploadPhoto() async {
    final picker = ImagePicker();

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (picked == null) return;

    try {
      final file = File(picked.path);

      await uploadPhoto(file);
      await loadPhotos();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo uploaded')),
      );
    } catch (e) {
      debugPrint('Photo upload failed: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo upload failed: $e')),
      );
    }
  }


  Future<Map<String, File>> processImage(File file) async {
    final bytes = await file.readAsBytes();
    final original = img.decodeImage(bytes)!;

    // Resize full (max 1200)
    final full = img.copyResize(
      original,
      width: original.width > 1200 ? 1200 : original.width,
    );

    // Resize thumbnail (300)
    final thumb = img.copyResize(original, width: 300);

    // Convert to WebP
    final fullWebp = img.encodeWebP(full, quality: 85);
    final thumbWebp = img.encodeWebP(thumb, quality: 75);

    final dir = await Directory.systemTemp.createTemp();

    final fullFile = File('${dir.path}/full.webp')
      ..writeAsBytesSync(fullWebp);

    final thumbFile = File('${dir.path}/thumb.webp')
      ..writeAsBytesSync(thumbWebp);

    return {
      'full': fullFile,
      'thumb': thumbFile,
    };
  }


  Widget buildPhotoCard(Map<String, dynamic> photo) {
    final thumbPath = photo['thumb_url'] ?? "";
    final fullPath = photo['url'] ?? "";

    final thumbUrl = "$baseUrl/$thumbPath";
    final fullUrl = "$baseUrl/$fullPath";

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
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

        if (result == true) {
          loadPhotos();
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          thumbUrl,
          fit: BoxFit.cover,
        ),
      ),
    );
  }


  void openViewer(String url, String description) {

    Navigator.push(

      context,

      MaterialPageRoute(

        builder: (_) => Scaffold(

          appBar: AppBar(),

          backgroundColor: Colors.black,

          body: Column(

            children: [

              Expanded(

                child: Center(

                  child: Image.network(url),
                ),
              ),

              if (description.isNotEmpty)

                Padding(

                  padding: const EdgeInsets.all(16),

                  child: Text(

                    description,

                    style: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (photos.isEmpty) {
      return const Center(child: Text("No photos"));
    }

    return GridView.builder(

      padding: const EdgeInsets.all(8),

      itemCount: photos.length,

      gridDelegate:
      const SliverGridDelegateWithFixedCrossAxisCount(

        crossAxisCount: 3,

        crossAxisSpacing: 8,

        mainAxisSpacing: 8,
      ),

      itemBuilder: (context, index) {

        return buildPhotoCard(photos[index]);
      },
    );
  }
}
