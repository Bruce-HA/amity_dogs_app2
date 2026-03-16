import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:typed_data';

class DnaTab extends StatefulWidget {
  final String dogId;

  const DnaTab({super.key, required this.dogId});

  @override
  State<DnaTab> createState() => _DnaTabState();
}

class _DnaTabState extends State<DnaTab> {
  final supabase = Supabase.instance.client;

  String extractPdfText(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(document).extractText();
    document.dispose();
    return text;
  }

  bool isLoading = true;
  bool hasDna = false;
  List<Map<String, dynamic>> loci = [];

  @override
  void initState() {
    super.initState();
    loadDna();
  }
///
  Future<void> uploadDnaSummary() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result == null) return;

    final file = result.files.first;
    final bytes = file.bytes;

    if (bytes == null) return;

    // 👇 THIS PART STAYS
    final dog = await supabase
        .from('dogs')
        .select('dog_ala')
        .eq('id', widget.dogId)
        .single();

    final dogAla = dog['dog_ala'];

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
      'is_active': true,
    });

    await supabase
        .from('dogs')
        .update({'has_dna_summary': true})
        .eq('id', widget.dogId);

    // 👇 REPLACE THE OLD DEBUG TEXT BLOCK WITH THIS

    final extractedText = extractPdfText(bytes);

    final parsed = parseLoci(extractedText);

    print("PARSED LOCI:");
    parsed.forEach((key, value) {
      print("$key → ${value[0]} / ${value[1]}");
    });

    // 👇 reload state
    await loadDna();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('DNA Summary Uploaded')),
    );
  }
//////..
  Map<String, List<String>> parseLoci(String text) {
    final loci = <String, List<String>>{};

    final patterns = {
      'E': RegExp(r'E Locus.*?([A-Za-z]+/[A-Za-z]+)'),
      'B': RegExp(r'B Locus.*?([A-Za-z]+/[A-Za-z]+)'),
      'K': RegExp(r'K Locus.*?([A-Za-z]+/[A-Za-z]+)'),
      'A': RegExp(r'A Locus.*?([A-Za-z_]+/[A-Za-z_]+)'),
      'D': RegExp(r'D.*Dilute.*?([A-Za-z]+/[A-Za-z]+)'),
      'S': RegExp(r'S.*Piebald.*?([A-Za-z]+/[A-Za-z]+)'),
      'Merle': RegExp(r'Merle.*?([A-Za-z]+/[A-Za-z]+)'),
      'KRT71': RegExp(r'KRT71.*?([A-Za-z]+/[A-Za-z]+)'),
      'MC5R': RegExp(r'MC5R.*?([A-Za-z]+/[A-Za-z]+)'),
      'RSPO2': RegExp(r'RSPO2.*?([A-Za-z]+/[A-Za-z]+)'),
    };

    for (final entry in patterns.entries) {
      final match = entry.value.firstMatch(text);
      if (match != null) {
        final allelePair = match.group(1)!;
        final parts = allelePair.split('/');
        if (parts.length == 2) {
          loci[entry.key] = [parts[0], parts[1]];
        }
      }
    }

    return loci;
  }
///..
  Future<void> loadDna() async {
    setState(() {
      isLoading = true;
    });

    final dogResponse = await supabase
        .from('dogs')
        .select('has_dna_summary')
        .eq('id', widget.dogId)
        .maybeSingle();

    hasDna = dogResponse?['has_dna_summary'] == true;

    if (hasDna) {
      final response = await supabase
          .from('dna_loci')
          .select()
          .eq('dog_id', widget.dogId);

      loci = List<Map<String, dynamic>>.from(response);
    } else {
      loci = [];
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    print("BUILD DNA TAB — hasDna = ${hasDna}");

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!hasDna) {
      return Center(
        child: ElevatedButton(
          onPressed: () {
            uploadDnaSummary();
          },
          child: const Text('Upload DNA Summary'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: loci.length,
      itemBuilder: (context, index) {
        final locus = loci[index];
        return Card(
          child: ListTile(
            title: Text(locus['locus'] ?? ''),
            subtitle: Text(
              '${locus['allele_1'] ?? ''} / ${locus['allele_2'] ?? ''}',
            ),
          ),
        );
      },
    );
  }
}