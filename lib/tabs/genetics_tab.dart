import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:typed_data';
import '../services/dna_service.dart';

class GeneticsTab extends StatefulWidget {
    final String dogId;

    const GeneticsTab({
      super.key,
      required this.dogId,
    });

    @override
    State<GeneticsTab> createState() => _GeneticsTabState();
  }

class _GeneticsTabState extends State<GeneticsTab> {
  final supabase = Supabase.instance.client;
  final noseColourController = TextEditingController();
  final coatColourController = TextEditingController();
  final secondCoatController = TextEditingController();
  final coatTypeController = TextEditingController();

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
        .maybeSingle();

    final dogAla = dog?['dog_ala'];

    final filePath =
        '$dogAla/DNA/${DateTime.now().millisecondsSinceEpoch}_${file.name}';

    final storage = supabase.storage.from('dog_files');

      await storage.uploadBinary(
        filePath,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );

      final publicUrl = storage.getPublicUrl(filePath);

      await DNAService().processDNA(
        dogId: widget.dogId,
        fileBytes: bytes,
        fileUrl: publicUrl,
      );

    await supabase
        .from('dogs')
        .update({'has_dna_summary': true})
        .eq('id', widget.dogId);

  /*  final parsed = parseLoci(extractedText);

    print("PARSED LOCI:");
    parsed.forEach((key, value) {
      print("$key → ${value[0]} / ${value[1]}");
    });
*/
    // 👇 reload state
    await loadDna();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('DNA Summary Uploaded')),
    );
  }
//////..
/*
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

  */
///..
  Color _getHealthChipColor(String result) {
    final value = result.toLowerCase();

    if (value.contains('clear')) {
      return Colors.green.shade100;
    }

    if (value.contains('carrier')) {
      return Colors.orange.shade100;
    }

    if (value.contains('at risk')) {
      return Colors.red.shade100;
    }

    return Colors.grey.shade200;
  }
///
  Future<void> loadDna() async {
    setState(() {
      isLoading = true;
    });

    final dogResponse = await supabase
        .from('dogs')
        .select(
          'has_dna_summary, colour, second_colour, coat_type, nose_colour'
        )
        .eq('id', widget.dogId)
        .maybeSingle();

    hasDna = dogResponse?['has_dna_summary'] == true;

    coatColourController.text =
        dogResponse?['colour'] ?? '';

    secondCoatController.text =
        dogResponse?['second_colour'] ?? '';

    coatTypeController.text =
        dogResponse?['coat_type'] ?? '';

    if ((dogResponse?['nose_colour'] ?? '').toString().isNotEmpty) {
      noseColourController.text =
          dogResponse?['nose_colour'] ?? '';
    }
    

    if (hasDna) {
      final response = await supabase
          .from('dna_bank')
          .select()
          .eq('dog_id', widget.dogId);

      loci = List<Map<String, dynamic>>.from(response);

      // 🐽 AUTO-FILL NOSE COLOUR FROM B LOCUS
      final b = loci.firstWhere(
        (l) => l['locus'] == 'B',
        orElse: () => {},
      );

      if (b.isNotEmpty) {
        final a1 = (b['allele_1'] ?? '').toLowerCase();
        final a2 = (b['allele_2'] ?? '').toLowerCase();

        if (a1 == 'b' && a2 == 'b') {
          noseColourController.text = 'liver';
        } else {
          noseColourController.text = 'black';
        }
      }

    } else {
      loci = [];
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    print("BUILD DNA TAB — hasDna = $hasDna");

    return Padding(
      padding: const EdgeInsets.all(16),
      child: isLoading
        ? const Center(child: CircularProgressIndicator())
        : hasDna
            ? FutureBuilder(
                future: Future.wait([
                  supabase
                      .from('dna_bank')
                      .select()
                      .eq('dog_id', widget.dogId),
                  supabase
                      .from('dna_health')
                      .select()
                      .eq('dog_id', widget.dogId),
                ]),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.data as List;
                  final loci = List<Map<String, dynamic>>.from(data[0]);
                  final health = List<Map<String, dynamic>>.from(data[1]);

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 🧬 Genetics
                      const Text(
                      'Genetics Profile',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                    ),
                      const SizedBox(height: 16),
                      const Text(
                        "Core Genetics",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      ...loci.map((locus) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.biotech),
                          title: Text(
                            locus['locus'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${locus['allele_1'] ?? ''} / ${locus['allele_2'] ?? ''}',
                          ),
                        ),
                      )),

                      const SizedBox(height: 20),

                      // 🧪 Health
                      const Text(
                        "Health & Disease",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      ...health.map((h) => Card(
                        child: ListTile(
                          title: Text(
                            h['test_name'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: Chip(
                            backgroundColor: _getHealthChipColor(
                              h['result'] ?? '',
                            ),
                            label: Text(
                              h['result'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        ),
                      )),

                          const SizedBox(height: 20),

                          // 🐕 Phenotype
                         const Text(
                            "Phenotype Override",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [

                                  TextField(
                                    controller: noseColourController,
                                    decoration: const InputDecoration(
                                      labelText: "Nose Colour",
                                    ),
                                  ),

                                  TextField(
                                    controller: coatColourController,
                                    decoration: const InputDecoration(
                                      labelText: "Coat Colour",
                                    ),
                                  ),

                                  TextField(
                                    controller: secondCoatController,
                                    decoration: const InputDecoration(
                                      labelText: "Secondary Colour",
                                    ),
                                  ),

                                  TextField(
                                    controller: coatTypeController,
                                    decoration: const InputDecoration(
                                      labelText: "Coat Type",
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  ElevatedButton(
                                    onPressed: () async {
                                      await supabase.from('dogs').update({
                                        'nose_colour': noseColourController.text,
                                        'colour': coatColourController.text,
                                        'second_colour': secondCoatController.text,
                                        'coat_type': coatTypeController.text,
                                      }).eq('id', widget.dogId);

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("Saved"),
                                        ),
                                      );
                                    },
                                    child: const Text("Save Phenotype"),
                                  ),

                                  const SizedBox(height: 20),

                                  Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Breeding Warnings",
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),

                                          const SizedBox(height: 12),

                                          if (noseColourController.text.toLowerCase() == 'liver')
                                            const Text(
                                              "• Chocolate pigment present (b/b likely)",
                                            ),

                                          const Text(
                                            "• Review carrier pairings before mating",
                                          ),

                                          const Text(
                                            "• Check Merle (M locus) before merle breeding",
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  );
                },
              )
            : 
      Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.biotech,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            const Text(
              'No DNA Summary Uploaded',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: uploadDnaSummary,
              child: const Text('Upload DNA Summary'),
            ),
          ],
        ),
      ),
                
    );
    
  }
  
}