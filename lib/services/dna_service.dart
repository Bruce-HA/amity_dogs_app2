import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class DNAService {
  final supabase = Supabase.instance.client;

  // ===============================
  // MAIN ENTRY
  // ===============================

  Future<void> processDNA({
    required String dogId,
    required File file,
  }) async {
    final text = await _extractPdfText(file);

    // 👇 ADD THIS HERE
    print("🧬 RAW TEXT:");
    print(text);

    final loci = _parseOrivet(text);
    final diseases = _extractDiseases(text);

    await _saveLoci(dogId, loci);
    await _saveDiseases(dogId, diseases);

    // mark dog as having DNA
    await supabase.from('dogs').update({
      'has_dna_summary': true,
    }).eq('id', dogId);
  }

  // ===============================
  // PDF → TEXT
  // ===============================

  Future<String> _extractPdfText(File file) async {
    final bytes = await file.readAsBytes();

    final document = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(document).extractText();

    document.dispose();

    return text;
  }

  // ===============================
  // LOCI PARSER (ORIVET)
  // ===============================

  Map<String, String> _parseOrivet(String text) {
    final result = <String, String>{};

    String? findGene(String label) {
      final reg = RegExp(
        "$label[\\s\\S]{0,80}?([A-Za-z]{1,2}\\s*/\\s*[A-Za-z]{1,2})",
        caseSensitive: false,
      );

      final match = reg.firstMatch(text);
      return match?.group(1)?.replaceAll(' ', '');
    }

    // 🧬 CORE GENES
    result['E'] = findGene("E Locus") ?? '';
    result['B'] = findGene("Brown") ?? '';
    result['D'] = findGene("Dilute") ?? '';
    result['K'] = findGene("K Locus") ?? '';
    result['A'] = findGene("A Locus") ?? '';

    // 🐾 PATTERNS
    result['S'] = findGene("Pied") ?? '';

    final merle = findGene("Merle");
    result['M'] = merle ?? 'm/m';

    return result;
  }

  // ===============================
  // DISEASE PARSER
  // ===============================

  Map<String, String> _extractDiseases(String text) {
    final map = <String, String>{};

    String status(String pattern) {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(text);
      if (match == null) return 'UNKNOWN';

      final line = match.group(0)!;

      if (line.contains('NEGATIVE')) return 'CLEAR';
      if (line.contains('CARRIER')) return 'CARRIER';
      if (line.contains('POSITIVE')) return 'AFFECTED';

      return 'UNKNOWN';
    }

    map['PRA'] = status(r'PRA.*');
    map['vWD'] = status(r'von Willebrand.*');
    map['SD2'] = status(r'Skeletal Dysplasia 2.*');

    return map;
  }

  // ===============================
  // SAVE LOCI
  // ===============================

  Future<void> _saveLoci(String dogId, Map<String, String> loci) async {
    await supabase.from('dna_bank').delete().eq('dog_id', dogId);

    for (final entry in loci.entries) {
      if (entry.value.isEmpty) continue;

      final parts = entry.value.split('/');

      await supabase.from('dna_bank').insert({
        'dog_id': dogId,
        'locus': entry.key,
        'allele_1': parts[0],
        'allele_2': parts.length > 1 ? parts[1] : parts[0],
      });
    }
  }

  // ===============================
  // SAVE DISEASES
  // ===============================

  Future<void> _saveDiseases(
    String dogId,
    Map<String, String> diseases,
  ) async {
    await supabase.from('dna_health').delete().eq('dog_id', dogId);

    for (final entry in diseases.entries) {
      await supabase.from('dna_health').insert({
        'dog_id': dogId,
        'disease': entry.key,
        'status': entry.value,
      });
    }
  }

  // ===============================
  // FETCH DNA FOR UI
  // ===============================

  Future<List<Map<String, dynamic>>> getDNA(String dogId) async {
    final res =
        await supabase.from('dna_bank').select().eq('dog_id', dogId);

    return (res as List).cast<Map<String, dynamic>>();
  }
}