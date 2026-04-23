import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class BreedingReportService {
  Future<void> generateAndShareReport({
    required Map<String, dynamic> femaleDog,
    required Map<String, dynamic> maleDog,
    required Map<String, dynamic> colourResults,
    required String puppyGrade,
    required double coi,
    required double avk,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Amity Breeding Report',
              style: pw.TextStyle(fontSize: 24),
            ),
          ),

          pw.SizedBox(height: 12),

          pw.Text(
            '${maleDog['dog_name'] ?? 'Sire'} × ${femaleDog['dog_name'] ?? 'Dam'}',
            style: pw.TextStyle(fontSize: 18),
          ),

          pw.SizedBox(height: 16),

          pw.Text('Expected Puppy Grade: $puppyGrade'),
          pw.Text('COI: ${coi.toStringAsFixed(2)}%'),
          pw.Text('AVK / ALC: ${avk.toStringAsFixed(1)}%'),

          pw.SizedBox(height: 20),

          pw.Text(
            'Expected Colours',
            style: pw.TextStyle(fontSize: 16),
          ),

          pw.SizedBox(height: 8),

          ...colourResults.entries.map(
            (e) => pw.Text('${e.key}: ${e.value}%'),
          ),

          pw.SizedBox(height: 20),

          pw.Text(
            'Female',
            style: pw.TextStyle(fontSize: 16),
          ),
          pw.Text('Name: ${femaleDog['dog_name'] ?? ''}'),
          pw.Text('Registered: ${femaleDog['registered_name'] ?? ''}'),
          pw.Text('ALA Grade: ${femaleDog['ala_grade'] ?? ''}'),
          pw.Text('Colour: ${femaleDog['colour'] ?? ''}'),
          pw.Text('Coat: ${femaleDog['coat_type'] ?? ''}'),

          pw.SizedBox(height: 16),

          pw.Text(
            'Male',
            style: pw.TextStyle(fontSize: 16),
          ),
          pw.Text('Name: ${maleDog['dog_name'] ?? ''}'),
          pw.Text('Registered: ${maleDog['registered_name'] ?? ''}'),
          pw.Text('ALA Grade: ${maleDog['ala_grade'] ?? ''}'),
          pw.Text('Colour: ${maleDog['colour'] ?? ''}'),
          pw.Text('Coat: ${maleDog['coat_type'] ?? ''}'),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/breeding_report.pdf');
    await file.writeAsBytes(await pdf.save());

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'breeding_report.pdf',
    );
  }
}