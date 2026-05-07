import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../dog_details_page.dart';
import '../../services/pedigree_service.dart';

class BasicPedigreeReportPage extends StatefulWidget {
  final String dogAla;

  const BasicPedigreeReportPage({
    super.key,
    required this.dogAla,
  });

  @override
  State<BasicPedigreeReportPage> createState() =>
      _BasicPedigreeReportPageState();
}

class _BasicPedigreeReportPageState extends State<BasicPedigreeReportPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool loading = true;
  bool generatingPdf = false;

  Map<String, dynamic>? pedigreeTree;

  @override
  void initState() {
    super.initState();
    fetchPedigree();
  }

  Future<void> fetchPedigree() async {
    setState(() {
      loading = true;
      pedigreeTree = null;
    });

    try {
      final dog = await supabase
          .from('dogs')
          .select('id, dog_ala')
          .eq('dog_ala', widget.dogAla)
          .maybeSingle();

      if (dog == null) {
        if (!mounted) return;
        setState(() => loading = false);
        return;
      }

      final tree = await PedigreeService().getPedigreeTree(
        dogId: dog['id'],
        generations: 3,
      );

      if (!mounted) return;

      setState(() {
        pedigreeTree = tree;
        loading = false;
      });
    } catch (e) {
      debugPrint('Basic pedigree load error: $e');

      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load pedigree: $e')),
      );
    }
  }

  void openDog(Map<String, dynamic>? dog) {
    final dogId = dog?['id']?.toString();

    if (dogId == null || dogId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DogDetailsPage(dogId: dogId),
      ),
    );
  }

  Widget _emptyImageBox(double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey.shade200,
      child: const Icon(Icons.pets, color: Colors.grey),
    );
  }

  Widget dogCard(
    Map<String, dynamic>? dog, {
    required String label,
    double width = 150,
    double imageSize = 76,
    bool large = false,
  }) {
    final name = dog?['name']?.toString() ?? '';
    final ala = dog?['ala']?.toString() ?? '';
    final colour = dog?['colour']?.toString() ?? '';
    final dob = dog?['dob']?.toString() ?? '';
    final hero = dog?['hero']?.toString();

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: dog == null ? null : () => openDog(dog),
      child: Container(
        width: width,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: dog == null ? Colors.grey.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: hero != null && hero.isNotEmpty
                  ? Image.network(
                      hero,
                      width: imageSize,
                      height: imageSize,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return _emptyImageBox(imageSize);
                      },
                    )
                  : _emptyImageBox(imageSize),
            ),
            const SizedBox(height: 6),
            Text(
              name.isEmpty ? 'Unknown' : name,
              textAlign: TextAlign.center,
              maxLines: large ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: large ? 15 : 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            if (ala.isNotEmpty)
              Text(
                ala,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: large ? 12 : 9,
                  color: Colors.grey.shade700,
                ),
              ),
            if (colour.isNotEmpty)
              Text(
                colour,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: large ? 12 : 9,
                  color: Colors.grey.shade700,
                ),
              ),
            if (dob.isNotEmpty)
              Text(
                dob,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: large ? 11 : 8,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pedigreeColumn({
    required String title,
    required List<Widget> children,
    double width = 160,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPedigreeTree() {
    final dog = pedigreeTree;

    if (dog == null) return const SizedBox();

    final sire = dog['father'] as Map<String, dynamic>?;
    final dam = dog['mother'] as Map<String, dynamic>?;

    final sireSire = sire?['father'] as Map<String, dynamic>?;
    final sireDam = sire?['mother'] as Map<String, dynamic>?;
    final damSire = dam?['father'] as Map<String, dynamic>?;
    final damDam = dam?['mother'] as Map<String, dynamic>?;

    final g1 = sireSire?['father'] as Map<String, dynamic>?;
    final g2 = sireSire?['mother'] as Map<String, dynamic>?;
    final g3 = sireDam?['father'] as Map<String, dynamic>?;
    final g4 = sireDam?['mother'] as Map<String, dynamic>?;
    final g5 = damSire?['father'] as Map<String, dynamic>?;
    final g6 = damSire?['mother'] as Map<String, dynamic>?;
    final g7 = damDam?['father'] as Map<String, dynamic>?;
    final g8 = damDam?['mother'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _pedigreeColumn(
            title: 'Dog',
            width: 190,
            children: [
              const SizedBox(height: 170),
              dogCard(
                dog,
                label: 'Dog',
                width: 180,
                imageSize: 110,
                large: true,
              ),
            ],
          ),
          const SizedBox(width: 14),
          _pedigreeColumn(
            title: 'Parents',
            width: 170,
            children: [
              const SizedBox(height: 80),
              dogCard(sire, label: 'Sire', width: 160, imageSize: 82),
              const SizedBox(height: 130),
              dogCard(dam, label: 'Dam', width: 160, imageSize: 82),
            ],
          ),
          const SizedBox(width: 14),
          _pedigreeColumn(
            title: 'Grandparents',
            width: 170,
            children: [
              dogCard(sireSire, label: 'Sire’s Sire', width: 160),
              dogCard(sireDam, label: 'Sire’s Dam', width: 160),
              const SizedBox(height: 48),
              dogCard(damSire, label: 'Dam’s Sire', width: 160),
              dogCard(damDam, label: 'Dam’s Dam', width: 160),
            ],
          ),
          const SizedBox(width: 14),
          _pedigreeColumn(
            title: 'Great Grandparents',
            width: 170,
            children: [
              dogCard(g1, label: 'SSS', width: 160, imageSize: 58),
              dogCard(g2, label: 'SSD', width: 160, imageSize: 58),
              dogCard(g3, label: 'SDS', width: 160, imageSize: 58),
              dogCard(g4, label: 'SDD', width: 160, imageSize: 58),
              dogCard(g5, label: 'DSS', width: 160, imageSize: 58),
              dogCard(g6, label: 'DSD', width: 160, imageSize: 58),
              dogCard(g7, label: 'DDS', width: 160, imageSize: 58),
              dogCard(g8, label: 'DDD', width: 160, imageSize: 58),
            ],
          ),
        ],
      ),
    );
  }

  Widget header() {
    final dog = pedigreeTree;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF2B0B45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Text(
            'Pedigree Of',
            style: TextStyle(
              color: Color(0xFFD4AF37),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            dog?['name']?.toString() ?? 'Unknown Dog',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            dog?['ala']?.toString() ?? '',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<Uint8List?> _fetchImageBytes(String? url) async {
    if (url == null || url.isEmpty) return null;

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('PDF image fetch failed: $e');
    }

    return null;
  }

  Future<Map<String, Uint8List?>> _preparePdfImages() async {
    final imageMap = <String, Uint8List?>{};

    Future<void> addImage(String key, Map<String, dynamic>? dog) async {
      final hero = dog?['hero']?.toString();

      if (hero == null || hero.isEmpty) {
        imageMap[key] = null;
        return;
      }

      imageMap[key] = await _fetchImageBytes(hero);
    }

    final dog = pedigreeTree;

    if (dog == null) return imageMap;

    final sire = dog['father'] as Map<String, dynamic>?;
    final dam = dog['mother'] as Map<String, dynamic>?;

    final sireSire = sire?['father'] as Map<String, dynamic>?;
    final sireDam = sire?['mother'] as Map<String, dynamic>?;
    final damSire = dam?['father'] as Map<String, dynamic>?;
    final damDam = dam?['mother'] as Map<String, dynamic>?;

    final g1 = sireSire?['father'] as Map<String, dynamic>?;
    final g2 = sireSire?['mother'] as Map<String, dynamic>?;
    final g3 = sireDam?['father'] as Map<String, dynamic>?;
    final g4 = sireDam?['mother'] as Map<String, dynamic>?;
    final g5 = damSire?['father'] as Map<String, dynamic>?;
    final g6 = damSire?['mother'] as Map<String, dynamic>?;
    final g7 = damDam?['father'] as Map<String, dynamic>?;
    final g8 = damDam?['mother'] as Map<String, dynamic>?;

    await addImage('dog', dog);
    await addImage('sire', sire);
    await addImage('dam', dam);
    await addImage('sireSire', sireSire);
    await addImage('sireDam', sireDam);
    await addImage('damSire', damSire);
    await addImage('damDam', damDam);
    await addImage('g1', g1);
    await addImage('g2', g2);
    await addImage('g3', g3);
    await addImage('g4', g4);
    await addImage('g5', g5);
    await addImage('g6', g6);
    await addImage('g7', g7);
    await addImage('g8', g8);

    return imageMap;
  }

  Future<void> _generatePdf() async {
    if (pedigreeTree == null) return;

    setState(() => generatingPdf = true);

    try {
      final images = await _preparePdfImages();
      final pdf = pw.Document();

      final dog = pedigreeTree!;

      final sire = dog['father'] as Map<String, dynamic>?;
      final dam = dog['mother'] as Map<String, dynamic>?;

      final sireSire = sire?['father'] as Map<String, dynamic>?;
      final sireDam = sire?['mother'] as Map<String, dynamic>?;
      final damSire = dam?['father'] as Map<String, dynamic>?;
      final damDam = dam?['mother'] as Map<String, dynamic>?;

      final g1 = sireSire?['father'] as Map<String, dynamic>?;
      final g2 = sireSire?['mother'] as Map<String, dynamic>?;
      final g3 = sireDam?['father'] as Map<String, dynamic>?;
      final g4 = sireDam?['mother'] as Map<String, dynamic>?;
      final g5 = damSire?['father'] as Map<String, dynamic>?;
      final g6 = damSire?['mother'] as Map<String, dynamic>?;
      final g7 = damDam?['father'] as Map<String, dynamic>?;
      final g8 = damDam?['mother'] as Map<String, dynamic>?;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(18),
          build: (context) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColor.fromHex('#D4AF37'),
                  width: 1.5,
                ),
              ),
              padding: const pw.EdgeInsets.all(10),
              child: pw.Column(
                children: [
                  _pdfHeader(dog, images['dog']),
                  pw.SizedBox(height: 10),
                  pw.Expanded(
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        _pdfColumn(
                          title: 'Dog',
                          width: 130,
                          children: [
                            pw.SizedBox(height: 126),
                            _pdfDogCard(
                              dog,
                              label: 'Dog',
                              imageBytes: images['dog'],
                              imageSize: 74,
                              large: true,
                            ),
                          ],
                        ),
                        _pdfColumn(
                          title: 'Parents',
                          width: 130,
                          children: [
                            pw.SizedBox(height: 64),
                            _pdfDogCard(
                              sire,
                              label: 'Sire',
                              imageBytes: images['sire'],
                            ),
                            pw.SizedBox(height: 84),
                            _pdfDogCard(
                              dam,
                              label: 'Dam',
                              imageBytes: images['dam'],
                            ),
                          ],
                        ),
                        _pdfColumn(
                          title: 'Grandparents',
                          width: 150,
                          children: [
                            _pdfDogCard(
                              sireSire,
                              label: 'Sire’s Sire',
                              imageBytes: images['sireSire'],
                            ),
                            _pdfDogCard(
                              sireDam,
                              label: 'Sire’s Dam',
                              imageBytes: images['sireDam'],
                            ),
                            pw.SizedBox(height: 28),
                            _pdfDogCard(
                              damSire,
                              label: 'Dam’s Sire',
                              imageBytes: images['damSire'],
                            ),
                            _pdfDogCard(
                              damDam,
                              label: 'Dam’s Dam',
                              imageBytes: images['damDam'],
                            ),
                          ],
                        ),
                        _pdfColumn(
                          title: 'Great Grandparents',
                          width: 330,
                          children: [
                            pw.Wrap(
                              spacing: 5,
                              runSpacing: 5,
                              children: [
                                _pdfDogCard(
                                  g1,
                                  label: 'SSS',
                                  imageBytes: images['g1'],
                                  imageSize: 34,
                                  compact: true,
                                ),
                                _pdfDogCard(
                                  g2,
                                  label: 'SSD',
                                  imageBytes: images['g2'],
                                  imageSize: 34,
                                  compact: true,
                                ),
                                _pdfDogCard(
                                  g3,
                                  label: 'SDS',
                                  imageBytes: images['g3'],
                                  imageSize: 34,
                                  compact: true,
                                ),
                                _pdfDogCard(
                                  g4,
                                  label: 'SDD',
                                  imageBytes: images['g4'],
                                  imageSize: 34,
                                  compact: true,
                                ),
                                _pdfDogCard(
                                  g5,
                                  label: 'DSS',
                                  imageBytes: images['g5'],
                                  imageSize: 34,
                                  compact: true,
                                ),
                                _pdfDogCard(
                                  g6,
                                  label: 'DSD',
                                  imageBytes: images['g6'],
                                  imageSize: 34,
                                  compact: true,
                                ),
                                _pdfDogCard(
                                  g7,
                                  label: 'DDS',
                                  imageBytes: images['g7'],
                                  imageSize: 34,
                                  compact: true,
                                ),
                                _pdfDogCard(
                                  g8,
                                  label: 'DDD',
                                  imageBytes: images['g8'],
                                  imageSize: 34,
                                  compact: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Generated by Amity Dogs App',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'pedigree_${dog['ala'] ?? 'dog'}.pdf',
      );
    } catch (e) {
      debugPrint('PDF generation error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate PDF: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => generatingPdf = false);
      }
    }
  }

  pw.Widget _pdfHeader(
    Map<String, dynamic> dog,
    Uint8List? imageBytes,
  ) {
    final name = dog['name']?.toString() ?? 'Unknown Dog';
    final ala = dog['ala']?.toString() ?? '';
    final dob = dog['dob']?.toString() ?? '';
    final colour = dog['colour']?.toString() ?? '';
    final sex = dog['sex']?.toString() ?? '';
    final microchip = dog['microchip']?.toString() ?? '';

    return pw.Container(
      height: 78,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#2B0B45'),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 76,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromHex('#D4AF37')),
            ),
            child: pw.Text(
              'AMITY',
              style: pw.TextStyle(
                color: PdfColor.fromHex('#D4AF37'),
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'Pedigree Of',
                  style: pw.TextStyle(
                    color: PdfColor.fromHex('#D4AF37'),
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  name,
                  maxLines: 1,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  [
                    if (ala.isNotEmpty) 'ALA: $ala',
                    if (sex.isNotEmpty) 'Sex: $sex',
                    if (dob.isNotEmpty) 'DOB: $dob',
                    if (colour.isNotEmpty) 'Colour: $colour',
                    if (microchip.isNotEmpty) 'Microchip: $microchip',
                  ].join('   |   '),
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 10),
          if (imageBytes != null)
            pw.ClipRRect(
              horizontalRadius: 8,
              verticalRadius: 8,
              child: pw.Image(
                pw.MemoryImage(imageBytes),
                width: 58,
                height: 58,
                fit: pw.BoxFit.cover,
              ),
            )
          else
            pw.Container(
              width: 58,
              height: 58,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              child: pw.Text(
                'No Photo',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _pdfColumn({
    required String title,
    required double width,
    required List<pw.Widget> children,
  }) {
    return pw.Container(
      width: width,
      padding: const pw.EdgeInsets.symmetric(horizontal: 3),
      child: pw.Column(
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#2B0B45'),
            ),
          ),
          pw.SizedBox(height: 5),
          ...children,
        ],
      ),
    );
  }

  pw.Widget _pdfDogCard(
    Map<String, dynamic>? dog, {
    required String label,
    Uint8List? imageBytes,
    double imageSize = 44,
    bool large = false,
    bool compact = false,
  }) {
    final width = compact ? 78.0 : large ? 112.0 : 118.0;
    final name = dog?['name']?.toString() ?? '';
    final ala = dog?['ala']?.toString() ?? '';
    final colour = dog?['colour']?.toString() ?? '';
    final dob = dog?['dob']?.toString() ?? '';

    return pw.Container(
      width: width,
      margin: const pw.EdgeInsets.only(bottom: 4),
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        color: dog == null ? PdfColors.grey200 : PdfColors.white,
        border: pw.Border.all(
          color: PdfColors.grey500,
          width: 0.6,
        ),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            label,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: compact ? 5.5 : 6.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#2B0B45'),
            ),
          ),
          pw.SizedBox(height: 2),
          if (imageBytes != null)
            pw.Image(
              pw.MemoryImage(imageBytes),
              width: imageSize,
              height: imageSize,
              fit: pw.BoxFit.cover,
            )
          else
            pw.Container(
              width: imageSize,
              height: imageSize,
              color: PdfColors.grey300,
              alignment: pw.Alignment.center,
              child: pw.Text(
                'Photo',
                style: const pw.TextStyle(fontSize: 5),
              ),
            ),
          pw.SizedBox(height: 2),
          pw.Text(
            name.isEmpty ? 'Unknown' : name,
            maxLines: compact ? 2 : 3,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: compact ? 5.8 : large ? 8 : 6.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (ala.isNotEmpty)
            pw.Text(
              ala,
              maxLines: 1,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: compact ? 5 : 5.8,
                color: PdfColors.grey700,
              ),
            ),
          if (!compact && colour.isNotEmpty)
            pw.Text(
              colour,
              maxLines: 1,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(
                fontSize: 5.5,
                color: PdfColors.grey700,
              ),
            ),
          if (!compact && dob.isNotEmpty)
            pw.Text(
              dob,
              maxLines: 1,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(
                fontSize: 5.2,
                color: PdfColors.grey700,
              ),
            ),
        ],
      ),
    );
  }

  Widget actionBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: generatingPdf ? null : fetchPedigree,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: generatingPdf ? null : _generatePdf,
              icon: generatingPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf),
              label: Text(generatingPdf ? 'Building PDF...' : 'Print / Share'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (pedigreeTree == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Basic Pedigree')),
        body: const Center(
          child: Text('No pedigree found for this dog.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Basic Pedigree'),
      ),
      backgroundColor: Colors.grey.shade300,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Container(
            width: 920,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.08),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                header(),
                const SizedBox(height: 16),
                _buildPedigreeTree(),
                actionBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}