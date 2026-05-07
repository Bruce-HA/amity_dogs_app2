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
    try {
      final fileName = (widget.photo['url'] ?? '').toString();
      final photoId = widget.photo['id'];

      if (fileName.isEmpty || photoId == null) {
        throw Exception('Missing photo file name or photo ID');
      }

      final storagePath = "${widget.dogAla}/photos/$fileName";

      debugPrint('PHOTO DELETE: removing storage file $storagePath');

      await supabase.storage
          .from('dog_files')
          .remove([storagePath]);

      debugPrint('PHOTO DELETE: storage remove complete');

      await supabase
          .from('dog_photos')
          .delete()
          .eq('id', photoId);

      debugPrint('PHOTO DELETE: dog_photos row deleted');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo deleted')),
      );

      Navigator.pop(context, true);
    } catch (e, st) {
      debugPrint('PHOTO DELETE ERROR: $e');
      debugPrint('PHOTO DELETE STACK: $st');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
    void initState() {
      super.initState();

      final rotationFromDb = widget.photo['rotation'] ?? 0;

      currentRotation = rotationFromDb.toDouble();
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
            onPressed: () =>
                Navigator.pop(context),
            child: const Text("Cancel"),
          ),

          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context,
                    controller.text),
            child: const Text("Save"),
          ),

        ],
      ),
    );

    if (result == null) return;

    await supabase
        .from('dog_photos')
        .update({
          'description': result,
        })
        .eq('id', widget.photo['id']);

    setState(() {
      widget.photo['description'] = result;
    });
  }
  double currentRotation = 0;
  
  Future<void> rotatePhoto() async {
    final newRotation =
        ((currentRotation + 90) % 360).toInt();

    setState(() {
      currentRotation = newRotation.toDouble();
    });

    await supabase
        .from('dog_photos')
        .update({
          'rotation': newRotation,
        })
        .eq('id', widget.photo['id']);

    // keep local object synced
    widget.photo['rotation'] = newRotation;
  }

  Future<void> sharePhoto() async {

    final response =
        await http.get(Uri.parse(widget.imageUrl));

    final dir =
        await getTemporaryDirectory();

    final file =
        File("${dir.path}/photo.jpg");

    await file.writeAsBytes(response.bodyBytes);

    await Share.shareXFiles([
      XFile(file.path),
    ]);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Colors.black,

      extendBodyBehindAppBar: true,

      appBar: AppBar(

        
        backgroundColor: Colors.black.withOpacity(0.4),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),

        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              Navigator.pop(context),
        ),

        actions: [

          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: editDescription,
          ),


          IconButton(
            icon: const Icon(Icons.share),
            onPressed: sharePhoto,
          ),

          IconButton(
            icon: const Icon(Icons.rotate_right),
            onPressed: rotatePhoto,
          ),


          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: deletePhoto,
          ),

        ],
      ),

      body: Center(
        child: InteractiveViewer(
          child: Transform.rotate(
          angle: currentRotation * 3.1415926535 / 180,
          child: Image.network(
            widget.imageUrl,
            key: ValueKey('${widget.imageUrl}-$currentRotation'),
          ),
        ),
        ),
      ),

      bottomNavigationBar:

          widget.photo['description'] != null &&
                  widget.photo['description'] != ""

              ? Container(

                  color: Colors.black,

                  padding:
                      const EdgeInsets.all(16),

                  child: Text(
                    widget.photo['description'],
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                )

              : null,
    );
  }
}