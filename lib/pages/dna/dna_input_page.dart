import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';

import '../../services/dna_service.dart';
import '../../dev/dev_info_panel.dart';

class DnaInputPage extends StatefulWidget {
  final String dogId;
  final String? dogName;

  const DnaInputPage({
    super.key,
    required this.dogId,
    this.dogName,
  });

  @override
  State<DnaInputPage> createState() => _DnaInputPageState();
}

class _DnaInputPageState extends State<DnaInputPage> {
  final supabase = Supabase.instance.client;

  String? selectedPrimary;
  String? selectedSecondary;
  String? selectedNose;

  bool isUploading = false;
  bool isSaving = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadDog();
  }

  Future<void> loadDog() async {
    final data = await supabase
        .from('dogs')
        .select('colour, second_colour, nose_colour')
        .eq('id', widget.dogId)
        .maybeSingle();

    if (data != null) {
      selectedPrimary = data['colour'];
      selectedSecondary = data['second_colour'];
      selectedNose = data['nose_colour'];
    }

    setState(() => isLoading = false);
  }

  Future<void> _uploadDnaSummary() async {
    if (isUploading) return;

    setState(() => isUploading = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) return;

      final dog = await supabase
          .from('dogs')
          .select('dog_ala')
          .eq('id', widget.dogId)
          .maybeSingle();

      final dogAla = dog?['dog_ala'] ?? 'unknown';

      final filePath =
          '$dogAla/DNA/${DateTime.now().millisecondsSinceEpoch}_${file.name}';

      final storage = supabase.storage.from('dog_files');

      await storage.uploadBinary(
        filePath,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );

      final publicUrl = storage.getPublicUrl(filePath);

      await supabase.from('dna_reports').insert({
        'dog_id': widget.dogId,
        'lab': 'Orivet',
        'report_url': publicUrl,
        'report_type': 'summary',
        'test_date': DateTime.now().toIso8601String(),
        'is_active': true,
      });

      await DNAService().processDNA(
        dogId: widget.dogId,
        fileBytes: bytes,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🧬 DNA uploaded and processed'),
          backgroundColor: Colors.green,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 600));
      Navigator.pop(context, true);

    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    } finally {
      setState(() => isUploading = false);
    }
  }

  Future<void> saveData() async {
    setState(() => isSaving = true);

    await supabase.from('dogs').update({
      'colour': selectedPrimary,
      'second_colour': selectedSecondary,
      'nose_colour': selectedNose,
    }).eq('id', widget.dogId);

    if (mounted) {
      Navigator.pop(context, true);
    }

    setState(() => isSaving = false);
  }

  Widget _dropdown(
      String label, String? value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : null,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.dogName ?? 'DNA Input')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _uploadDnaSummary,
              child: isUploading
                  ? const CircularProgressIndicator()
                  : const Text("Upload DNA Summary"),
            ),

            const SizedBox(height: 20),

            _dropdown("Primary Colour", selectedPrimary, [
              "Black","Chocolate","Caramel","Cream"
            ], (v) => setState(() => selectedPrimary = v)),

            _dropdown("Secondary Colour", selectedSecondary, [
              "None","Abstract","Phantom","Sable"
            ], (v) => setState(() => selectedSecondary = v)),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: saveData,
              child: isSaving
                  ? const CircularProgressIndicator()
                  : const Text("Save"),
            ),

            const SizedBox(height: 20),

            DevInfoPanel(
              page: "DNA Input",
              filePath: "dna_input_page.dart",
              purpose: "Upload DNA",
              dataSources: ["dna_bank"],
              notes: "Dog ID: ${widget.dogId}",
            )
          ],
        ),
      ),
    );
  }
}