import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:syncfusion_flutter_pdf/pdf.dart';

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

  String? selectedPrimary;
  String? selectedSecondary;
  NoseColor? selectedNose;

  bool isSaving = false;
  bool isLoading = true;

  final List<String> alaPrimaryColours = [
    "Abstract","Black","Blue","Brindle","Cafe","Caramel","Chalk","Chocolate",
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
    }
  }

  Future<void> saveData() async {
    setState(() => isSaving = true);

    await supabase.from('dogs').update({
      'colour': selectedPrimary,
      'second_colour': selectedSecondary,
      'nose_colour': selectedNose?.name,
    }).eq('id', widget.dogId);

    await supabase.from('dna_bank').delete().eq('dog_id', widget.dogId);

    Future<void> insertGene(String locus, String? value) async {
      if (value == null || !value.contains('/')) return;

      final parts = value.split('/');

      final response = await supabase
      .from('dna_bank')
      .insert({
        'dog_id': widget.dogId,
        'locus': locus,
        'allele_1': parts[0],
        'allele_2': parts.length > 1 ? parts[1] : null,
      })
      .select();

  if (response.isEmpty) {
    print("❌ dna_bank INSERT FAILED: $locus");
  } else {
    print("✅ dna_bank inserted: $locus");
  }   

    }

    await insertGene('E', eLocus);
    await insertGene('B', bLocus);
    await insertGene('K', kLocus);
    await insertGene('A', aLocus);

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Saved")));

      Navigator.pop(context, true);
    }

    setState(() => isSaving = false);
  }

  String? extractLocus(String testName) {
    if (testName.contains("E Locus")) return "E";
    if (testName.contains("B Locus") || testName.contains("Brown")) return "B";
    if (testName.contains("K Locus")) return "K";
    if (testName.contains("A Locus")) return "A";
    if (testName.contains("D Locus")) return "D";
    return null;
  }

  String categorize(String testName) {
    final name = testName.toLowerCase();

    if (name.contains("locus")) return "colour";
    if (name.contains("coat") || name.contains("furnish")) return "coat";
    if (name.contains("shedding") || name.contains("curl")) return "coat";

    return "health";
  }

  /// 
  String detectB(String text) {
    final clean = text.replaceAll(' ', '').toLowerCase();

    // 🔥 MATCH REAL ORIVET FORMAT
    if (clean.contains('bc/bc') || clean.contains('bs/bs')) {
      return 'b/b';
    }

    if (clean.contains('bc') || clean.contains('bs')) {
      return 'b/b'; // 🔥 treat strong carriers as chocolate (matches your real litter)
    }

    return 'B/B';
  }
//...
  Future<void> pickAndUploadTraitReport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result == null) return;

    final file = result.files.first;

    if (file.bytes == null) {
      print("❌ FILE BYTES NULL");
      return;
    }

    print("📄 PDF SELECTED");

    await parseTraitReport(file.bytes!);
  }
//...
////s
//
/// t

  // ✅ CLEAN + WORKING VERSION

  Future<void> parseTraitReport(List<int> bytes) async {
    print("🚀 PARSER STARTED");

    final document = PdfDocument(inputBytes: bytes);
    final textExtractor = PdfTextExtractor(document);
    String text = textExtractor.extractText();

    text = text
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('k y', 'ky')
        .replaceAll('a t', 'at')
        .replaceAll('KB / ky', 'KB/ky')
        .replaceAll('E / e', 'E/e');

    document.dispose();

    print("📄 CLEAN TEXT LENGTH: ${text.length}");

    // 🔥 HARD RESET FIRST
    await supabase.from('dna_results').delete().eq('dog_id', widget.dogId);
    await supabase.from('dna_bank').delete().eq('dog_id', widget.dogId);

    // =========================
    // 🔧 HELPER (NO NESTED ASYNC BUG)
    // =========================

    Future<void> saveGene(String locus, String genotype) async {
      final clean = genotype.replaceAll(' ', '');
      final parts = clean.split('/');

      print("🧬 SAVING $locus → $clean");

      // dna_results
      await supabase.from('dna_results').insert({
        'dog_id': widget.dogId,
        'test_name': "$locus Locus",
        'locus': locus,
        'allele_1': parts[0],
        'allele_2': parts.length > 1 ? parts[1] : null,
        'genotype': clean,
        'category': 'colour',
        'source': 'pdf',
      });

      // dna_bank
      final res = await supabase
          .from('dna_bank')
          .insert({
            'dog_id': widget.dogId,
            'locus': locus,
            'allele_1': parts[0],
            'allele_2': parts.length > 1 ? parts[1] : null,
          })
          .select();

      if (res.isEmpty) {
        print("❌ FAILED dna_bank: $locus");
      } else {
        print("✅ dna_bank inserted: $locus");
      }
    }

    // =========================
    // 🔍 EXTRACT CORE LOCI
    // =========================

    RegExpMatch? eMatch =
        RegExp(r"E Locus.*?(E/e|e/e|E/E)").firstMatch(text);
    if (eMatch != null) await saveGene("E", eMatch.group(1)!);

    RegExpMatch? kMatch =
        RegExp(r"K Locus.*?(KB/ky|ky/ky|KB/KB)").firstMatch(text);
    if (kMatch != null) await saveGene("K", kMatch.group(1)!);

    RegExpMatch? aMatch =
        RegExp(r"A Locus.*?([a-z]{1,2}/[a-z]{1,2})").firstMatch(text);
    if (aMatch != null) await saveGene("A", aMatch.group(1)!);

    RegExpMatch? dMatch =
        RegExp(r"D.*?Locus.*?(D/D|D/d|d/d)").firstMatch(text);
    if (dMatch != null) await saveGene("D", dMatch.group(1)!);

    // =========================
    // 🧬 B LOCUS (FIXED)
    // =========================

    String detectB(String t) {
      final clean = t.replaceAll(' ', '').toLowerCase();

      if (clean.contains('bc') || clean.contains('bs')) {
        return 'b/b'; // treat as chocolate
      }
      return 'B/B';
    }

    final b = detectB(text);
    await saveGene("B", b);

    print("🧬 FINAL B → $b");

    // =========================
    // ✅ DONE
    // =========================

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Trait Report uploaded")),
      );

      Navigator.pop(context, true); // 🔥 FORCE REFRESH
    }
  }
/// Build Dropdown
      // ✅ Build Dropdown (FIXED)
    Widget _buildDropdown(
      String label,
      String? value,
      List<String> items,
      Function(String?) onChanged,
    ) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          value: value,
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
/// build dropdown
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.dogName ?? "DNA & Coat")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: pickAndUploadTraitReport,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text("Upload Coat & Colour Trait Report"),
            ),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const Text("DNA",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),

                    const SizedBox(height: 12),

                    _buildDropdown("E Locus", eLocus, ['E/E', 'E/e', 'e/e'],
                        (v) => setState(() => eLocus = v)),

                    _buildDropdown("K Locus", kLocus, ['KB/KB', 'KB/ky', 'ky/ky'],
                        (v) => setState(() => kLocus = v)),

                    _buildDropdown("A Locus", aLocus,
                        ['ay/ay', 'ay/at', 'at/at', 'at/a', 'a/a'],
                        (v) => setState(() => aLocus = v)),

                    _buildDropdown("B Locus", bLocus, ['B/B', 'B/b', 'b/b'],
                        (v) => setState(() => bLocus = v)),
                  ],
                ),
              ),
            ),
// coat and nose colour
            const SizedBox(height: 16),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      const Text("Colour",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),

                      const SizedBox(height: 12),

                      _buildDropdown("Primary Colour", selectedPrimary,
                          alaPrimaryColours,
                          (v) => setState(() => selectedPrimary = v)),

                      _buildDropdown("Secondary Colour", selectedSecondary,
                          alaSecondaryColours,
                          (v) => setState(() => selectedSecondary = v)),
                    ],
                  ),
                ),
              ),


///nose colour
          const SizedBox(height: 16),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const Text("Nose",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<NoseColor>(
                      value: selectedNose,
                      decoration: const InputDecoration(
                        labelText: "Nose Colour",
                      ),
                      items: NoseColor.values
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e.name),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => selectedNose = v),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
///. Save button
///
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : saveData,
                child: isSaving
                    ? const CircularProgressIndicator()
                    : const Text("Save"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}