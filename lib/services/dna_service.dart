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

_running.add(dogId);
    final traitsMatch = RegExp(
      r'Traits\s+Result[\s\S]+?A Locus[\s\S]+?(?=Owner|Glossary)',
      caseSensitive: false,
    ).firstMatch(text);

    if (traitsMatch != null) {
      traitsText = traitsMatch.group(0)!;
    }
    
    print("TRAITS TEXT:");
    print(traitsText);
    
    final loci = _parseOrivet(traitsText);
    print("LOCI FOUND: $loci");

    final diseases = _extractDiseases(diseaseText);
    final tests = _extractAllTests(diseaseText);

    try {

    await _saveDiseases(dogId, diseases);
    await _saveResults(dogId, tests);

    await Future.delayed(const Duration(seconds: 1));

    await rebuildDNABank(dogId, loci, traitsText);

    } finally {
  _running.remove(dogId);
}
  
  }

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
  // ===============================
  Map<String, String> _parseOrivet(String text) {
    final result = <String, String>{};

    final matches = RegExp(
      r'\b([ekabdt yEKABDTY]{1,2}\s*/\s*[ekabdt yEKABDTY]{1,2})\b',
    ).allMatches(text);

    for (final m in matches) {
      final raw = m.group(1);
      if (raw == null) continue;

      final cleaned = raw
          .toLowerCase()
          .replaceAll(' ', '')
          .replaceAll('a y', 'ay')
          .replaceAll('a t', 'at');

      String normalized = cleaned;

      // Fix broken A locus like y/a → ay/a
      if (normalized == 'y/a') normalized = 'ay/a';
      if (normalized == 'y/at') normalized = 'ay/at';
      if (normalized == 't/a') normalized = 'at/a';
      if (normalized == 't/at') normalized = 'at/at';

      final start = (m.start - 40).clamp(0, text.length);
      final end = (m.end + 40).clamp(0, text.length);
      final context = text.substring(start, end).toLowerCase();

      if (context.contains('e locus') && !result.containsKey('E')) {
        result['E'] = cleaned;
      }
      if (context.contains('k locus') && !result.containsKey('K')) {
        result['K'] = cleaned;
      }
      if (context.contains('a locus') && !result.containsKey('A')) {
        result['A'] = normalized;
      }
      if (context.contains('dilute') && !result.containsKey('D')) {
        result['D'] = cleaned;
      }
    }

    return result;
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

    final matches = RegExp(
      r'([A-Za-z0-9\-\(\)\/\s]+?)\s+(NEGATIVE|CARRIER|POSITIVE)',
      caseSensitive: false,
    ).allMatches(text);

    for (final m in matches) {
      final name = m.group(1)?.trim() ?? '';
      final raw = m.group(2)?.toUpperCase() ?? '';

      if (name.length < 5) continue;

      String status = 'UNKNOWN';
      if (raw == 'NEGATIVE') status = 'CLEAR';
      if (raw == 'CARRIER') status = 'CARRIER';
      if (raw == 'POSITIVE') status = 'AFFECTED';

      map[name] = status;
    }

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
    print("🚨 REBUILD START for $dogId at ${DateTime.now()}");
    print("🚀 rebuildDNABank RUNNING");
    print("LOCI PASSED IN: $loci");
    print("SUPABASE URL: ${Supabase.instance.client.rest.url}");

    await supabase.from('dna_bank').delete().eq('dog_id', dogId);

    if (loci.isEmpty || loci.length < 3) {
      print("⚠️ No loci from traitsText — using dna_summary fallback");

      final rows = await supabase
          .from('dna_summary')
          .select()
          .eq('dog_id', dogId);

      for (final r in rows) {
        final name = (r['test_name'] ?? '').toLowerCase();

        if (name.contains('b s /b s') ||
            name.contains('b c /b c') ||
            name.contains('b d /b d')) {
          await supabase.from('dna_bank').insert({
            'dog_id': dogId,
            'locus': 'B',
            'allele_1': 'b',
            'allele_2': 'b',
            'source': 'summary',
          });
        }

        if (name.contains('a y /a')) {
          await supabase.from('dna_bank').insert({
            'dog_id': dogId,
            'locus': 'A',
            'allele_1': 'ay',
            'allele_2': 'a',
            'source': 'summary',
          });
        }
      }
    }

    // E, K, A, D
    final inserted = <String>{};

    for (final entry in loci.entries) {
      final locus = entry.key;
      final value = entry.value;

      inserted.add(locus); // 👈 ADD THIS LINE

      print("PROCESSING LOCUS: $locus → $value");

      final parts = value.split('/');
      if (parts.length != 2) {
        print("❌ SKIPPED $locus (bad format)");
        continue;
      }

      print("🔥 ABOUT TO INSERT: $locus → $value");

      final res = await supabase
          .from('dna_bank')
          .insert({
            'dog_id': dogId,
            'locus': locus,
            'allele_1': parts[0],
            'allele_2': parts[1],
            'source': 'summary',
          })
            .select();

          final check = await supabase
            .from('dna_bank')
            .select()
            .eq('dog_id', dogId);

        print("🧪 APP READ BACK: $check");
        

      print("INSERT RESULT: $res");
    }

    // B locus
    String detectB(String text) {
      final clean = text.toLowerCase().replaceAll(' ', '');

      if (clean.contains('bs/') ||
          clean.contains('bc/') ||
          clean.contains('bd/') ||
          clean.contains('/bs') ||
          clean.contains('/bc') ||
          clean.contains('/bd')) {
        return 'b/b';
      }
      return 'B/B';
    }

/*
    String? extractALocus(String text) {
      final clean = text
          .replaceAll('a y', 'ay')
          .replaceAll('a t', 'at')
          .replaceAll('\n', ' ')
          .replaceAll(RegExp(r'\s+'), ' ');

      final match = RegExp(
        r'A\s*Locus.*?(ay/ay|ay/at|at/at|at/a|a/a)',
        caseSensitive: false,
      ).firstMatch(clean);

      if (match != null) {
        print("🧬 A LOCUS FOUND: ${match.group(1)}");
        return match.group(1);
      }

      print("❌ A LOCUS NOT FOUND");
      return null;
    }
*/
    if (!inserted.contains('B')) {
      final b = detectB(traitsText);
      final parts = b.split('/');

      await supabase.from('dna_bank').insert({
        'dog_id': dogId,
        'locus': 'B',
        'allele_1': parts[0],
        'allele_2': parts[1],
        'source': 'summary',
        
      });
      
    }

    // 👇 after inserting all loci
    // 🔥 get B from actual database (source of truth)
  final bRow = await supabase
      .from('dna_bank')
      .select()
      .eq('dog_id', dogId)
      .eq('locus', 'B')
      .maybeSingle();

  print("🐽 B ROW FROM DB: $bRow");

  if (bRow != null) {
    final allele1 = (bRow['allele_1'] as String).toLowerCase().trim();
    final allele2 = (bRow['allele_2'] as String).toLowerCase().trim();

    String noseColour;

    if (allele1 == 'b' && allele2 == 'b') {
      noseColour = 'liver';
    } else {
      noseColour = 'black';
    }

    print("🐽 Setting nose colour → $noseColour");

    await supabase.from('dogs').update({
      'nose_colour': noseColour,
    }).eq('id', dogId);
  }
  }
}