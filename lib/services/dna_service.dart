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
    required String fileUrl,
  }) async {
    if (_running.contains(dogId)) {
      print("⛔ SKIPPED duplicate process for $dogId");
      return;
    }

    _running.add(dogId);

    try {
      final text = await _extractPdfText(fileBytes);

      String diseaseText = text;
      String traitsText = text;

      final start = text.indexOf('Tests Reported');
      final end = text.lastIndexOf('Traits');

      if (start != -1 && end != -1 && end > start) {
        diseaseText = text.substring(start, end);
      }

      traitsText = text;

      print("TRAITS TEXT:");
      print(traitsText);

      final parsed = _parseOrivet(traitsText);

      final loci =
          parsed['loci'] as Map<String, String>;

      final String? testDate =
          parsed['test_date'];

      print("LOCI FOUND: $loci");
      print("📅 TEST DATE: $testDate");

      final diseases =
          _extractDiseases(diseaseText);

      final tests =
          _extractAllTests(diseaseText);

      await _saveDiseases(dogId, diseases);

      await Future.delayed(
        const Duration(seconds: 1),
      );

      await rebuildDNABank(
        dogId,
        loci,
        traitsText,
      );

      await supabase.from('dna_reports').upsert({
        'dog_id': dogId,
        'lab': 'Orivet',
        'report_type': 'summary',
        'report_url': fileUrl,
        'test_date': testDate,
        'is_active': true,
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

    final clean = text
        .toLowerCase()
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');

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
    // B locus
      if (
          clean.contains('brown/chocolate') ||
          clean.contains('brown/chocolate, liver') ||
          clean.contains('brown/chocolate liver') ||
          clean.contains('bs bs/bs') ||
          clean.contains('bs bs / bs') ||
          clean.contains('bs b s / b s') ||
          clean.contains('bs/bs') ||
          clean.contains('b s / b s')) {
        result['B'] = 'b/b';
      }

    // E locus
    if (clean.contains('e/e')) {
      result['E'] = 'e/e';
    }

  // K locus (robust parser for broken PDF spacing)

    if (
        clean.contains('kb / k y') ||
        clean.contains('kb/k y') ||
        clean.contains('kb / ky') ||
        clean.contains('kb/ky') ||
        clean.contains('ky/kb') ||
        clean.contains('k locus (dominant black) kb / k y') ||
        clean.contains('one copy dominant black (kb)')
    ) {
      result['K'] = 'kb/ky';
    }
    else if (
        clean.contains('ky / ky') ||
        clean.contains('ky/ky')
    ) {
      result['K'] = 'ky/ky';
    }
    else if (
        clean.contains('kb / kb') ||
        clean.contains('kb/kb')
    ) {
      result['K'] = 'kb/kb';
    }
    else if (
        clean.contains('k/k')
    ) {
      result['K'] = 'K/K';
    }

  // A locus (regex parser — much safer)

  final aMatch = RegExp(
    r'a\s*t\s*/\s*a\b|a\s*t\s*/\s*a\s',
    caseSensitive: false,
  ).firstMatch(clean);

  if (aMatch != null) {
    result['A'] = 'at/a';
  }
  else if (RegExp(
    r'a\s*y\s*/\s*a\s*t',
    caseSensitive: false,
  ).hasMatch(clean)) {
    result['A'] = 'ay/at';
  }
  else if (RegExp(
    r'a\s*t\s*/\s*a\s*t',
    caseSensitive: false,
  ).hasMatch(clean)) {
    result['A'] = 'at/at';
  }
  else if (RegExp(
    r'a\s*y\s*/\s*a\s*y',
    caseSensitive: false,
  ).hasMatch(clean)) {
    result['A'] = 'ay/ay';
  }
  else if (RegExp(
    r'a\s*y\s*/\s*a\b',
    caseSensitive: false,
  ).hasMatch(clean)) {
    result['A'] = 'ay/a';
  }
  else if (RegExp(
    r'a\s*/\s*a',
    caseSensitive: false,
  ).hasMatch(clean)) {
    result['A'] = 'a/a';
  }

    // M locus
    if (clean.contains('m [171bp] / m [171bp]')) {
      result['M'] = 'm/m';
    } else if (clean.contains('merle')) {
      result['M'] = 'M/m';
    }

    // S locus
    if (clean.contains('no piebald')) {
      result['S'] = 'S/S';
    } else if (clean.contains('parti coat colour')) {
      result['S'] = 'sp/sp';
    }

    print("🧬 PARSED LOCI: $result");

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
    final lines = clean.split('\n');

    for (final line in lines) {
      final l = line.trim();

      // =========================
      // DM
      // =========================
      if (l.contains('degenerative myelopathy') || l.contains(' dm ')) {
        if (l.contains('clear') ||
            l.contains('negative') ||
            l.contains('normal') ||
            l.contains('not detected')) {
          map['DM'] = 'clear';
        } else if (l.contains('carrier')) {
          map['DM'] = 'carrier';
        } else if (l.contains('affected') ||
                  l.contains('positive')) {
          map['DM'] = 'affected';
        }
      }

      // =========================
      // PRA
      // =========================
      if (l.contains('pra') || l.contains('prcd')) {
        if (l.contains('clear') ||
            l.contains('negative') ||
            l.contains('normal') ||
            l.contains('not detected')) {
          map['PRA'] = 'clear';
        } else if (l.contains('carrier')) {
          map['PRA'] = 'carrier';
        } else if (l.contains('affected') ||
                  l.contains('positive')) {
          map['PRA'] = 'affected';
        }
      }
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
