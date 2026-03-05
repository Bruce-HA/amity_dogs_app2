import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class DogFilesTab extends StatefulWidget {
  final String dogId;

  const DogFilesTab({super.key, required this.dogId});

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

  Future<void> loadFiles() async {
    setState(() {
      loading = true;
    });

    try {
      final response = await supabase
          .from('dog_files')
          .select()
          .eq('dog_id', widget.dogId)
          .order('created_at', ascending: false);

      files = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading files: $e');
    }

    setState(() {
      loading = false;
    });
  }

  Future<void> openFile(String url) async {
    final uri = Uri.parse(url);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open file')));
    }
  }

  IconData getFileIcon(String url) {
    final lower = url.toLowerCase();

    if (lower.endsWith('.pdf')) {
      return Icons.picture_as_pdf;
    }

    if (lower.endsWith('.jpg') || lower.endsWith('.png')) {
      return Icons.image;
    }

    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return Icons.description;
    }

    return Icons.insert_drive_file;
  }

  Widget buildFileTile(Map<String, dynamic> file) {
    final url = file['url'] ?? '';

    final description = file['description'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

      child: ListTile(
        leading: Icon(getFileIcon(url), color: Colors.blue),

        title: Text(description.isNotEmpty ? description : 'File'),

        subtitle: Text(
          url.split('/').last,
          style: const TextStyle(fontSize: 12),
        ),

        trailing: const Icon(Icons.open_in_new),

        onTap: () => openFile(url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (files.isEmpty) {
      return const Center(child: Text('No files uploaded'));
    }

    return RefreshIndicator(
      onRefresh: loadFiles,

      child: ListView.builder(
        itemCount: files.length,

        itemBuilder: (context, index) {
          return buildFileTile(files[index]);
        },
      ),
    );
  }
}
