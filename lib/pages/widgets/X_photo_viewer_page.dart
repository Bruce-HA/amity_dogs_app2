import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class PhotoViewerPage extends StatefulWidget {

  final String imageUrl;
  final Map<String, dynamic> photo;
  final String dogId;
  final String dogAla;

  const PhotoViewerPage({
    super.key,
    required this.imageUrl,
    required this.photo,
    required this.dogId,
    required this.dogAla,
  });

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {

  final supabase = Supabase.instance.client;

  Future<void> deletePhoto() async {

    final fileName = widget.photo['url'];

    final storagePath =
        "${widget.dogId}/${widget.dogAla}/photo/$fileName";

    await supabase.storage
        .from('dog_files')
        .remove([storagePath]);

    await supabase
        .from('dog_photos')
        .delete()
        .eq('id', widget.photo['id']);

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> setHeroImage() async {

    final fileName = widget.photo['url'];

    final sourcePath =
        "${widget.dogId}/${widget.dogAla}/photo/$fileName";

    final heroPath =
        "${widget.dogId}/${widget.dogAla}/photo/hero.jpg";

    final bytes = await supabase.storage
        .from('dog_files')
        .download(sourcePath);

    await supabase.storage
        .from('dog_files')
        .uploadBinary(
          heroPath,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Hero image updated")),
      );
    }
  }

  Future<void> editDescription() async {

    final controller = TextEditingController(
      text: widget.photo['description'] ?? "",
    );

    final result = await showDialog<String>(

      context: context,

      builder: (_) => AlertDialog(

        title: const Text("Edit Description"),

        content: TextField(
          controller: controller,
        ),

        actions: [

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),

          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, controller.text),
            child: const Text("Save"),
          ),

        ],
      ),
    );

    if (result == null) return;

    await supabase
        .from('dog_photos')
        .update({'description': result})
        .eq('id', widget.photo['id']);

    setState(() {
      widget.photo['description'] = result;
    });
  }

  Future<void> sharePhoto() async {

    final response =
        await http.get(Uri.parse(widget.imageUrl));

    final dir =
        await getTemporaryDirectory();

    final file =
        File("${dir.path}/photo.jpg");

    await file.writeAsBytes(response.bodyBytes);

    await Share.shareXFiles([XFile(file.path)]);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Colors.black,

      appBar: AppBar(

        backgroundColor: Colors.black,

        automaticallyImplyLeading: true,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),

        actions: [

          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: editDescription,
          ),

          IconButton(
            icon: const Icon(Icons.star),
            onPressed: setHeroImage,
          ),

          IconButton(
            icon: const Icon(Icons.share),
            onPressed: sharePhoto,
          ),

          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: deletePhoto,
          ),

        ],
      ),

      body: Center(
        child: InteractiveViewer(
          child: Image.network(widget.imageUrl),
        ),
      ),

      bottomNavigationBar:
          widget.photo['description'] != null &&
                  widget.photo['description'] != ""
              ? Container(
                  color: Colors.black,
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    widget.photo['description'],
                    style:
                        const TextStyle(color: Colors.white),
                  ),
                )
              : null,
    );
  }
}