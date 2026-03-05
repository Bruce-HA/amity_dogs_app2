import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../services/app_user.dart';

class DogFilesTab extends StatefulWidget {
  final String dogId;
  final String dogAla;

  const DogFilesTab({
    super.key,
    required this.dogId,
    required this.dogAla,
  });

  @override
  State<DogFilesTab> createState() => _DogFilesTabState();
}

class _DogFilesTabState extends State<DogFilesTab> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> files = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadFiles();
  }

  /*
  =========================================
  LOAD FILES
  =========================================
  */

  Future<void> loadFiles() async {
    setState(() => loading = true);

    final response = await supabase
        .from('dog_files')
        .select()
        .eq('dog_id', widget.dogId)
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false);

    files = List<Map<String, dynamic>>.from(response);

    setState(() => loading = false);
  }

  /*
  =========================================
  STORAGE HELPERS
  =========================================
  */

  String buildPath(String fileName) {
    return "${widget.dogAla}/documents/$fileName";
  }

  String getPublicUrl(String fileName) {
    return supabase.storage
        .from('dog_files')
        .getPublicUrl(buildPath(fileName));
  }

  /*
  =========================================
  UPLOAD FILE
  =========================================
  */

  Future<void> uploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
    );

    if (result == null) return;

    final file = result.files.first;
    final bytes = file.bytes;

    if (bytes == null) return;

    final fileName = file.name;
    final path = buildPath(fileName);

    await supabase.storage
        .from('dog_files')
        .uploadBinary(path, bytes);

    await supabase.from('dog_files').insert({
      "dog_id": widget.dogId,
      "file_name": fileName,
      "file_description": "",
      "file_type": file.extension,
      "uploaded_by": AppUser.name,
    });

    loadFiles();
  }

  /*
  =========================================
  DOWNLOAD FILE
  =========================================
  */

  Future<File> downloadFile(String fileName) async {
    final bytes = await supabase.storage
        .from('dog_files')
        .download(buildPath(fileName));

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/$fileName");

    await file.writeAsBytes(bytes);

    return file;
  }

  /*
  =========================================
  OPEN FILE
  =========================================
  */

  Future<void> openFile(String fileName) async {
    final file = await downloadFile(fileName);
    await OpenFilex.open(file.path);
  }

  /*
  =========================================
  SHARE FILE
  =========================================
  */

  Future<void> shareFile(String fileName) async {
    final file = await downloadFile(fileName);
    await Share.shareXFiles([XFile(file.path)]);
  }

  /*
  =========================================
  DELETE FILE
  =========================================
  */

  Future<void> deleteFile(Map file) async {
    final name = file['file_name'];

    await supabase.storage
        .from('dog_files')
        .remove([buildPath(name)]);

    await supabase
        .from('dog_files')
        .delete()
        .eq('id', file['id']);

    loadFiles();
  }
  /*
=========================================
PIN / UNPIN FILE
=========================================
*/

Future<void> togglePin(Map file) async {

  final newValue = !(file['is_pinned'] ?? false);

  await supabase
      .from('dog_files')
      .update({'is_pinned': newValue})
      .eq('id', file['id']);

  loadFiles();
}
  /*
  =========================================
  FILE ICON HELPER
  =========================================
  */

  IconData getFileIcon(String? type) {
    if (type == null) return Icons.insert_drive_file;

    type = type.toLowerCase();

    if (type.contains("pdf")) return Icons.picture_as_pdf;
    if (type.contains("xls")) return Icons.table_chart;
    if (type.contains("xlsx")) return Icons.table_chart;
    if (type.contains("jpg")) return Icons.image;
    if (type.contains("png")) return Icons.image;

    return Icons.insert_drive_file;
  }

  /*
  =========================================
  FILE CARD
  =========================================
  */

  Widget buildFileCard(Map file) {
    final name = file['file_name'] ?? "";
    final desc = file['file_description'] ?? "";
    final uploader = file['uploaded_by'] ?? "";
    final type = file['file_type'];

    return Card(
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [

            if (file['is_pinned'] == true)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.push_pin,
                  color: Colors.amber,
                  size: 18,
                ),
              ),

            Icon(
              getFileIcon(type),
              size: 32,
            ),

          ],
        ),

        title: Text(name),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            if (desc.isNotEmpty)
              Text(desc),

            Text(
              "Uploaded by $uploader",
              style: const TextStyle(fontSize: 12),
            ),
          ],
          
        ),
      

        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [

            IconButton(
              icon: Icon(
                file['is_pinned'] == true
                    ? Icons.push_pin
                    : Icons.push_pin_outlined,
              ),
              onPressed: () => togglePin(file),
            ),

            PopupMenuButton(
              itemBuilder: (_) => const [

                PopupMenuItem(
                  value: "view",
                  child: Text("View"),
                ),

                PopupMenuItem(
                  value: "share",
                  child: Text("Share"),
                ),

                PopupMenuItem(
                  value: "delete",
                  child: Text("Delete"),
                ),
              ],
              onSelected: (value) {

                if (value == "view") {
                  openFile(name);
                }

                if (value == "share") {
                  shareFile(name);
                }

                if (value == "delete") {
                  deleteFile(file);
                }
              },
            ),

          ],
        ),
      ),
    );
  }

  /*
  =========================================
  UI
  =========================================
  */

  @override
  Widget build(BuildContext context) {

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(

      body: files.isEmpty
          ? const Center(
              child: Text("No files uploaded"),
            )
          : ListView.builder(
              itemCount: files.length,
              itemBuilder: (_, i) {
                return buildFileCard(files[i]);
              },
            ),

      floatingActionButton: FloatingActionButton(
        onPressed: uploadFile,
        child: const Icon(Icons.upload_file),
      ),
    );
  }
}