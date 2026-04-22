import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:typed_data';

class DNAService {
  final supabase = Supabase.instance.client;
  static final Set<String> _running = {};

  // ===============================
  // MAIN ENTRY
  // ===============================
  Future<void> processDNA({
    required String dogId,
    required Uint8List fileBytes,
    
  }) async {
    var text = await _extractPdfText(fileBytes);

    String diseaseText = text;
    String traitsText = text;

    final start = text.indexOf('Tests Reported');
    final end = text.lastIndexOf('Traits');

    if (start != -1 && end != -1 && end > start) {
      diseaseText = text.substring(start, end);
    }
    if (_running.contains(dogId)) {
      print("⛔ SKIPPED duplicate process for $dogId");
      return;
    }

    traitsText = text; // 🔥 USE FULL PDF TEXT
    
    print("TRAITS TEXT:");
    print(traitsText);
    
    final parsed = _parseOrivet(traitsText);

    final loci = parsed['loci'] as Map<String, String>;
    final String? testDate = parsed['test_date'];

    print("LOCI FOUND: $loci");
    print("📅 TEST DATE: $testDate");

    final diseases = _extractDiseases(diseaseText);
    final tests = _extractAllTests(diseaseText);

    try {

    await _saveDiseases(dogId, diseases);
    // await _saveResults(dogId, tests);

    await Future.delayed(const Duration(seconds: 1));

    await rebuildDNABank(dogId, loci, traitsText);

    await supabase.from('dna_reports').upsert({
      'dog_id': dogId,
      'lab': 'Orivet',
      'report_type': 'summary',
      'test_date': testDate,
      'created_at': DateTime.now().toIso8601String(),
    }, onConflict: 'dog_id,report_type');

    } finally {
  _running.remove(dogId);
}
  
  }
////
  String? _formatDate(String raw) {
    try {
      // remove ordinal (14th → 14)
      final cleaned = raw
          .replaceAll(RegExp(r'(st|nd|rd|th)'), '')
          .trim();

      final parts = cleaned.split(' ');
      if (parts.length != 3) return null;

      final day = parts[0].padLeft(2, '0');
      final monthStr = parts[1].toLowerCase();
      final year = parts[2];

      const months = {
        'jan': '01', 'feb': '02', 'dec': '12'
      };

      final month = months[monthStr.substring(0, 3)];
      if (month == null) return null;

      return "$year-$month-$day"; // ISO format
    } catch (_) {
      return null;
    }
  }
///
///
  // ===============================
  // PDF → TEXT
  // ===============================
  Future<String> _extractPdfText(Uint8List bytes) async {
    final document = PdfDocument(inputBytes: bytes);
    final rawText = PdfTextExtractor(document).extractText();
    document.dispose();

    return rawText
        .replaceAll('\u0000', '')
        .replaceAll(RegExp(r'[^\x00-\x7F]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // ===============================
  // LOCI PARSER
  Map<String, dynamic> _parseOrivet(String text) {
    final result = <String, String>{};

    // 🔥 STEP 1 — CLEAN OCR SPACING FIRST
    final clean = text
        .toLowerCase()
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')

    // 🔥 NORMALISE ALL SPACING VARIANTS
        .replaceAll(RegExp(r'b\s*/\s*b'), 'b/b')
        .replaceAll(RegExp(r'e\s*/\s*e'), 'e/e')

        .replaceAll(RegExp(r'b\s+b'), 'b/b')
        .replaceAll(RegExp(r'b\s*:\s*b\s*/\s*b'), 'b/b')
        .replaceAll(RegExp(r'\ba\s*t\b'), 'at')
        .replaceAll(RegExp(r'\ba\s*y\b'), 'ay')
        .replaceAll(RegExp(r'\bk\s*b\b'), 'kb')
        .replaceAll(RegExp(r'\bk\s*y\b'), 'ky')

        .replaceAll(RegExp(r'k\s*y\s*/\s*k\s*y'), 'ky/ky')
        .replaceAll(RegExp(r'k\s*b\s*/\s*k\s*y'), 'kb/ky')
        .replaceAll(RegExp(r'k\s*y\s*/\s*k\s*b'), 'ky/kb')
        .replaceAll(RegExp(r'\bbb\b'), 'b/b')
        .replaceAll(RegExp(r'a\s*y\s*/\s*a\s*t'), 'ay/at')
        .replaceAll(RegExp(r'a\s*t\s*/\s*a\s*t'), 'at/at')
        .replaceAll(RegExp(r'a\s*y\s*/\s*a\s*y'), 'ay/ay');

    // 🟤 B LOCUS — TARGETED EXTRACTION
    final bMatch = RegExp(
      r'b\s*locus[^a-z0-9]{0,20}([a-z])\s*[/\s]\s*([a-z])',
      caseSensitive: false,
    ).firstMatch(clean);

    if (bMatch != null) {
      final a1 = bMatch.group(1);
      final a2 = bMatch.group(2);

      if (a1 != null && a2 != null) {
        result['B'] = '$a1/$a2';
      }

      print("🟤 B MATCH: ${bMatch.group(0)}");
    }

  //
    // 📅 TEST DATE EXTRACTION
    String? testDate;

    final dateMatch = RegExp(
      r'date of test\s*:\s*([0-9]{1,2}\w*\s+[a-z]{3,}\s+[0-9]{4})',
      caseSensitive: false,
    ).firstMatch(text);

    if (dateMatch != null) {
      final raw = dateMatch.group(1);

      if (raw != null) {
        testDate = _formatDate(raw);
      }
    }

print("📅 TEST DATE: $testDate");
  //
    // 🟤 A LOCUS — MUST BE OUTSIDE
    final aMatch = RegExp(
      r'a\s*locus[\s\S]{0,80}?(ay|at|a)\s*[/\s]\s*(ay|at|a)',
      caseSensitive: false,
    ).firstMatch(clean);

    if (aMatch != null) {
      final a1 = aMatch.group(1);
      final a2 = aMatch.group(2);

      if (a1 != null && a2 != null) {
        result['A'] = '$a1/$a2';
      }

      print("🟤 A MATCH: ${aMatch.group(0)}");
    }


        // 🔥 STEP 2 — SIMPLE DETECTION (NO GUESSING)
        if (clean.contains('b/b')) result['B'] = 'b/b';
        if (clean.contains('e/e')) result['E'] = 'e/e';
        if (clean.contains('bb')) result['B'] = 'b/b';
        if (clean.contains('ky/ky')) result['K'] = 'ky/ky';
        if (clean.contains('kb/kb')) result['K'] = 'kb/kb';
        if (clean.contains('kb/ky') || clean.contains('ky/kb')) {
          result['K'] = 'kb/ky';
        }

    if (clean.contains('ay/at')) result['A'] = 'ay/at';
    if (clean.contains('ay/ay')) result['A'] = 'ay/ay';
    if (clean.contains('at/at')) result['A'] = 'at/at';

    print("🧬 PARSED LOCI: $result");
    print("🧪 CLEAN TEXT SAMPLE:");
    print("🔍 CONTAINS B LOCUS?");
    print(clean.contains('b locus'));
    print(clean.contains(' b '));
    print(clean.substring(0, 500));

    return {
      'loci': result,
      'test_date': testDate,
    };
    }

  // ===============================
  // SAVE DISEASES
  // ===============================
  Future<void> _saveDiseases(
    String dogId,
    Map<String, String> diseases,
  ) async {
    for (final entry in diseases.entries) {
      final testName = entry.key;
      final result = entry.value;

      if (testName.isEmpty || result.isEmpty) continue;

      await supabase.from('dna_health').upsert({
        'dog_id': dogId,
        'test_name': testName,
        'result': result,
        'source_type': 'pdf',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'dog_id,test_name');
    }
  }


  // ===============================
  // SAVE SUMMARY
  // ===============================
  Future<void> _saveResults(
    String dogId,
    List<Map<String, String>> tests,
  ) async {
    for (var t in tests) {
      await supabase.from('dna_summary').insert({
        'dog_id': dogId,
        'test_name': t['test_name'],
        'result': t['result'],
        'category': t['category'],
      });
    }
  }

  // ===============================
  // EXTRACT DISEASES
  // ===============================
  Map<String, String> _extractDiseases(String text) {
    final map = <String, String>{};

    final clean = text.toLowerCase();

    if (clean.contains('degenerative myelopathy')) {
      if (clean.contains('negative')) map['DM'] = 'clear';
      if (clean.contains('carrier')) map['DM'] = 'carrier';
      if (clean.contains('positive')) map['DM'] = 'affected';
    }

    if (clean.contains('prcd') || clean.contains('pra')) {
      if (clean.contains('negative')) map['PRA'] = 'clear';
      if (clean.contains('carrier')) map['PRA'] = 'carrier';
      if (clean.contains('positive')) map['PRA'] = 'affected';
    }

    print("🧪 DISEASE MAP: $map");

    return map;
  }

  // ===============================
  // EXTRACT ALL TESTS
  // ===============================
  List<Map<String, String>> _extractAllTests(String text) {
    final results = <Map<String, String>>[];

    final matches = RegExp(
      r'([A-Za-z0-9\-\(\)\/\s]+?)\s+(NEGATIVE|CARRIER|POSITIVE)',
      caseSensitive: false,
    ).allMatches(text);

    for (final m in matches) {
      final name = m.group(1)?.trim() ?? '';
      final raw = m.group(2)?.toUpperCase() ?? '';

      if (name.length < 5) continue;

      String result = 'UNKNOWN';
      if (raw == 'NEGATIVE') result = 'CLEAR';
      if (raw == 'CARRIER') result = 'CARRIER';
      if (raw == 'POSITIVE') result = 'AFFECTED';

      results.add({
        'test_name': name,
        'result': result,
        'category': 'health',
      });
    }

    return results;
  }

  // ===============================
  // 🔥 FINAL DNA BANK BUILDER
  // ===============================
  Future<void> rebuildDNABank(
    String dogId,
    Map<String, String> loci,
    String traitsText,
  ) async {

    print("🚀 rebuildDNABank for $dogId");
    print("LOCI: $loci");

    // OPTIONAL: keep for now
    // await supabase.from('dna_bank').delete().eq('dog_id', dogId);

    for (final entry in loci.entries) {
      final locus = entry.key;
      final value = entry.value;

      final parts = value.split('/');
      if (parts.length != 2) continue;

      await supabase.from('dna_bank').upsert({
        'dog_id': dogId,
        'locus': locus,
        'allele_1': parts[0],
        'allele_2': parts[1],
        'source': 'summary',
      }, onConflict: 'dog_id,locus');
    }

    // 🐽 Nose colour (based on B only)
    final bRow = await supabase
        .from('dna_bank')
        .select()
        .eq('dog_id', dogId)
        .eq('locus', 'B')
        .maybeSingle();

    if (bRow != null) {
      final a1 = (bRow['allele_1'] as String).toLowerCase();
      final a2 = (bRow['allele_2'] as String).toLowerCase();

      final noseColour = (a1 == 'b' && a2 == 'b') ? 'liver' : 'black';

      await supabase.from('dogs').update({
        'nose_colour': noseColour,
      }).eq('id', dogId);
    }
  }
}