// =====================================================
// BREEDING REPORT SERVICE
// lib/services/breeding_report.dart
// FINAL CLEAN PRODUCTION VERSION
// =====================================================

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BreedingReportService {
  Future<void> generateAndShareReport({
    required Map<String, dynamic> company,
    required Map<String, dynamic> femaleDog,
    required Map<String, dynamic> maleDog,
    required Map<String, dynamic> colourResults,
    required String puppyGrade,
    required double coi,
    required double avk,
    required List<String> warnings,
    required List<String> healthWarnings,
    required String breedingPlanCode,
  }) async {
    final femaleImageUrl = await _fetchDogImage(
      femaleDog['id'],
      femaleDog['dog_ala'],
    );

    final maleImageUrl = await _fetchDogImage(
      maleDog['id'],
      maleDog['dog_ala'],
    );

    final femaleImageBytes = await _networkImageBytes(femaleImageUrl);
    final maleImageBytes = await _networkImageBytes(maleImageUrl);

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              company['company_name'] ?? 'Breeding Plan Report',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),

          pw.SizedBox(height: 16),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _metricBox(
                title: "Puppy Grade",
                value: puppyGrade,
              ),

              _metricBox(
                title: "COI",
                value: "${coi.toStringAsFixed(2)}%",
              ),

              _metricBox(
                title: "AVK / ALC",
                value: "${avk.toStringAsFixed(1)}%",
              ),
            ],
          ),

          pw.SizedBox(height: 24),

          // =====================================================
          // EXPECTED COLOUR OUTCOMES
          // =====================================================

          pw.Text(
            "Expected Colour Outcomes",
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),

          pw.SizedBox(height: 12),

          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: PdfColors.amber700,
                width: 1,
              ),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [

                pw.Text(
                  "Likely Puppy Outcomes",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.SizedBox(height: 12),

                ...colourResults.entries.map(
                  (entry) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Row(
                      mainAxisAlignment:
                          pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          entry.key.toString(),
                          style: const pw.TextStyle(
                            fontSize: 11,
                          ),
                        ),
                        pw.Text(
                          "${entry.value}%",
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                pw.SizedBox(height: 14),

                pw.Divider(),

                pw.SizedBox(height: 10),

                pw.Text(
                  "Breeder Notes",
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.SizedBox(height: 8),

                _bulletLine("Low shedding fleece coats expected"),
                _bulletLine("Furnished coats expected"),
                _bulletLine("Chocolate gene carried"),
                _bulletLine("Possible phantom expression"),
                _bulletLine("Liver nose potential"),
              ],
            ),
          ),

          pw.SizedBox(height: 24),

          pw.Text(
    company['default_disclaimer'] ??
        'Breeding planning report only.',
  ),

          ],
        ),
      );
    final safeCode = breedingPlanCode.replaceAll(' ', '_');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/breeding_report_$safeCode.pdf');
    final bytes = await pdf.save();

    await file.writeAsBytes(bytes);

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'breeding_report_$safeCode.pdf',
    );
  }

  pw.Widget _metricBox({required String title, required String value}) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Column(
        children: [
          pw.Text(title),
          pw.SizedBox(height: 6),
          pw.Text(value),
        ],
      ),
    );
    
  }

///----
  
///---
  pw.Widget _roleBadge(String label) => pw.Text(label);

  pw.Widget _detailLine(String label, String value) =>
      pw.Text('$label: $value');

  pw.Widget _bulletLine(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(
        bottom: 6,
      ),
      child: pw.Text(
        "• $text",
        style: const pw.TextStyle(
          fontSize: 11,
        ),
      ),
    );
  }    

  Future<String?> _fetchDogImage(String dogId, String dogAla) async {
    try {
      final photos = await Supabase.instance.client
          .from('dog_photos')
          .select('url, is_hero')
          .eq('dog_id', dogId);

      if (photos.isEmpty) return null;

      final hero = photos.firstWhere(
        (p) => p['is_hero'] == true,
        orElse: () => photos.first,
      );

      final rawUrl = hero['url'];
      if (rawUrl == null) return null;

      final path = '$dogAla/photos/$rawUrl';

      return Supabase.instance.client.storage
          .from('dog_files')
          .getPublicUrl(path);
    } catch (e) {
      debugPrint('DOG IMAGE ERROR: $e');
      return null;
    }
  }

  Future<Uint8List?> _networkImageBytes(String? url) async {
    try {
      if (url == null) return null;
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) return response.bodyBytes;
      return null;
    } catch (e) {
      debugPrint('IMAGE DOWNLOAD ERROR: $e');
      return null;
    }
  }
}
