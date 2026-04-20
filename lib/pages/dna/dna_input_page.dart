// imports (cleaned)
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

enum NoseColor { black, liver }

class _DnaInputPageState extends State<DnaInputPage> {
  final supabase = Supabase.instance.client;

  String? eLocus;
  String? bLocus;
  String? kLocus;
  String? aLocus;
  String? dLocus;

  String? selectedPrimary;
  String? selectedSecondary;
  NoseColor? selectedNose;

  bool isSaving = false;
  bool isLoading = true;
  bool isUploading = false;

  final List<String> alaPrimaryColours = [
    "Abstract","Black","Blue","Brindle","Cafe","Caramel","Chalk","Chocolate","Gold","Cream",
  ];

  final List<String> alaSecondaryColours = [
    "Abstract","Apricot","Black","Black/Chalk","Black/Gold","Black/Red",
    "Black/Silver","Blue","Blue/Chalk","Blue/Silver","Cafe","Caramel",
    "Caramel/Chalk","Chalk","Chalk/Cream","Chalk/Gold","Charcoal",
    "Chocolate","Chocolate/Caramel","Chocolate/Chalk","Chocolate/Cream",
    "Chocolate/Gold","Cream","Cream/Chalk","Cream/Gold","Gold","Gold/Chalk",
    "Latte","Red","Red/Chalk","Sable","Silver","Silver/Chalk",
  ];

  @override
  void initState() {
    super.initState();
    loadDog();
    loadDNA();
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

      final nose = data['nose_colour'];
      if (nose == 'black') selectedNose = NoseColor.black;
      if (nose == 'liver') selectedNose = NoseColor.liver;
    }

    setState(() => isLoading = false);
  }

  Future<void> loadDNA() async {
    final res = await supabase
        .from('dna_bank')
        .select()
        .eq('dog_id', widget.dogId);

    for (var d in res) {
      final locus = d['locus'];
      final val = "${d['allele_1']}/${d['allele_2']}";

      if (locus == 'E') eLocus = val;
      if (locus == 'B') bLocus = val;
      if (locus == 'K') kLocus = val;
      if (locus == 'A') aLocus = val;
      if (locus == 'D') dLocus = val;
    }
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
          .single();

      final filePath =
          '${dog['dog_ala']}/DNA/${DateTime.now().millisecondsSinceEpoch}_${file.name}';

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
          content: Text('🧬 DNA Summary uploaded and processed'),
          backgroundColor: Colors.green,
        ),
      );
        // 🔥 ADD THIS
          await Future.delayed(const Duration(milliseconds: 800));

          if (mounted) {
            Navigator.pop(context, true); // returns to previous page
          }
    } 
    catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ DNA processing failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isUploading = false);
      }
    }
  }

  Future<void> saveData() async {
    setState(() => isSaving = true);

    await supabase.from('dogs').update({
      'colour': selectedPrimary,
      'second_colour': selectedSecondary,
      'nose_colour': selectedNose?.name,
    }).eq('id', widget.dogId);

    Future<void> insertGene(String locus, String? value) async {
      if (value == null || !value.contains('/')) return;

      final parts = value.split('/');

      final res = await supabase
          .from('dna_bank')
          .upsert({
            'dog_id': widget.dogId,
            'locus': locus,
            'allele_1': parts[0],
            'allele_2': parts[1],
          })
          .select();

      if (res.isEmpty) {
        print("❌ dna_bank INSERT FAILED: $locus");
      } else {
        print("✅ dna_bank inserted: $locus");
      }
    }

    await insertGene('E', eLocus);
    await insertGene('B', bLocus);
    await insertGene('K', kLocus);
    await insertGene('A', aLocus);
    await insertGene('D', dLocus);

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Saved")));

      Navigator.pop(context, true);
    }

    setState(() => isSaving = false);
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: items.contains(value) ? value : null,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text(widget.dogName ?? 'DNA Input'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
    ),


    body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

               Center(
                child: SizedBox(
                  width: 280, // 👈 controls width
                  height: 55, // 👈 controls height
                  child: ElevatedButton(
                    onPressed: isUploading ? null : _uploadDnaSummary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.black, // 👈 THIS FIXES IT
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 3,
                    ),
                    child: isUploading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Upload DNA Summary',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),

                const SizedBox(height: 20),

                _buildDropdown(
                  "Primary Colour",
                  selectedPrimary,
                  alaPrimaryColours,
                  (val) => setState(() => selectedPrimary = val),
                ),

                _buildDropdown(
                  "Secondary Colour",
                  selectedSecondary,
                  alaSecondaryColours,
                  (val) => setState(() => selectedSecondary = val),
                ),

                const SizedBox(height: 20),

                Center(
                  child: SizedBox(
                    width: 220,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : saveData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.black, // 👈 THIS FIXES IT
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 3,
                      ),
                      child: isSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                DevInfoPanel(
                  page: 'DNA Input Page',
                  filePath: 'lib/pages/dna_input_page.dart',
                  purpose: 'Upload and process DNA summary PDFs',
                  dataSources: [
                    'dna_summary',
                    'dna_bank',
                    'dna_health',
                    'dna_reports',
                  ],
                  notes: '''
Dog ID: ${widget.dogId}

Parsed Loci:
E: ${eLocus ?? '-'}
K: ${kLocus ?? '-'}
A: ${aLocus ?? '-'}
D: ${dLocus ?? '-'}
B: ${bLocus ?? '-'}

State:
Uploading: $isUploading
Saving: $isSaving
''',
                ),
              ],
            ),
          ),
  );
}
  }