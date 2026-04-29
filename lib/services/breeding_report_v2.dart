// =====================================================
// BREEDING REPORT SERVICE V2 - FIXED A4 GOLDEN LAYOUT
// Target file: lib/services/breeding_report_v2.dart
//
// Purpose:
// Build a single-page, print-first A4 breeding report that follows
// the golden sample structure:
// Header / Parent Dogs / Puppy Outcomes / Genetics + Health /
// Recommendation / Footer
//
// NOTE:
// This version prioritises fixed layout and visual structure.
// Some genetics values are still placeholders/fallbacks until we wire
// the exact calculated values from BreedingPlanCard into the plan payload.
// =====================================================

import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;

  class BreedingReportServiceV2 {
    final supabase = Supabase.instance.client;

    Future<Map<String, dynamic>?> _fetchCompanyProfile() async {
      try {
        final data = await supabase
            .from('company_profile')
            .select()
            .limit(1)
            .maybeSingle();

        return data;
      } catch (e) {
        return null;
      }
    }

    Future<void> generateAndShareReport({
    required Map<String, dynamic> femaleDog,
    required Map<String, dynamic> maleDog,
    required Map<String, dynamic> breedingPlan,
  }) async {
    final company = await _fetchCompanyProfile();

    final companyLogoBytes = await _networkImageBytes(
      company?['company_logo_url'],
    );

    final associationLogoBytes = await _networkImageBytes(
      company?['association_logo_url'],
    );

    final femaleImageBytes = await _fetchDogImage(
      femaleDog['id']?.toString(),
      femaleDog['dog_ala']?.toString(),
    );

    final maleImageBytes = await _fetchDogImage(
      maleDog['id']?.toString(),
      maleDog['dog_ala']?.toString(),
    );

    final femaleStats = await _fetchLitterStats(
      femaleDog['dog_ala']?.toString(),
    );

    final maleStats = await _fetchLitterStats(
      maleDog['dog_ala']?.toString(),
    );

    final colourKeyItems = await _buildDynamicColourKeyItems(
      breedingPlan,
    );

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (context) {
          return pw.Container(
            width: double.infinity,
            height: double.infinity,
            child: pw.Column(
              children: [
                _buildHeader(
                  company: company,
                  breedingPlan: breedingPlan,
                  companyLogoBytes: companyLogoBytes,
                ),
                pw.SizedBox(height: 7),
                _buildParentSection(
                  dam: femaleDog,
                  sire: maleDog,
                  damImageBytes: femaleImageBytes,
                  sireImageBytes: maleImageBytes,
                  damStats: femaleStats,
                  sireStats: maleStats,
                ),
                pw.SizedBox(height: 7),
                _buildPuppyOutcomesSection(
                  breedingPlan: breedingPlan,
                  colourKeyItems: colourKeyItems,
                ),
                pw.SizedBox(height: 7),
                _buildGeneticsHealthSection(
                  breedingPlan: breedingPlan,
                ),
                pw.SizedBox(height: 7),
                _buildRecommendationSection(
                  breedingPlan: breedingPlan,
                ),
                pw.Spacer(),
                _buildFooter(
                  company: company,
                  associationLogoBytes: associationLogoBytes,
                ),
              ],
            ),
          );
        },
      ),
    );

    final bytes = await pdf.save();

    final safeCode = (breedingPlan['breeding_plan_code'] ?? 'report')
        .toString()
        .replaceAll(' ', '_');

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'breeding_report_$safeCode.pdf',
    );
  }

  // =====================================================
  // SECTION 1 - HEADER
  // =====================================================

  pw.Widget _buildHeader({
    required Map<String, dynamic>? company,
    required Map<String, dynamic> breedingPlan,
    required Uint8List? companyLogoBytes,
  }) {
    final today = DateTime.now();
    final dateText = '${today.day}/${today.month}/${today.year}';

    return pw.Container(
      height: 62,
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#2B0B45'),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        children: [
          if (companyLogoBytes != null)
            pw.Container(
              width: 110,
              height: 48,
              child: pw.Image(
                pw.MemoryImage(companyLogoBytes),
                fit: pw.BoxFit.contain,
              ),
            )
          else
            pw.Container(
              width: 110,
              child: pw.Text(
                company?['company_name'] ?? 'Amity Labradoodles',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'BREEDING REPORT',
                  style: pw.TextStyle(
                    color: PdfColor.fromHex('#D4AF37'),
                    fontSize: 25,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'FOR BREEDING DECISIONS BETWEEN BREEDERS',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Plan: ${breedingPlan['breeding_plan_code'] ?? '-'}   |   Generated: $dateText',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 7.5,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Container(
            width: 46,
            height: 46,
            decoration: pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              border: pw.Border.all(
                color: PdfColor.fromHex('#D4AF37'),
                width: 1.2,
              ),
            ),
            child: pw.Center(
              child: pw.Text(
                'A',
                style: pw.TextStyle(
                  color: PdfColor.fromHex('#D4AF37'),
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // SECTION 2 - PARENT DOGS
  // =====================================================

  pw.Widget _buildParentSection({
    required Map<String, dynamic> dam,
    required Map<String, dynamic> sire,
    required Uint8List? damImageBytes,
    required Uint8List? sireImageBytes,
    required Map<String, dynamic> damStats,
    required Map<String, dynamic> sireStats,
  }) {
    return pw.Container(
      height: 125,
      decoration: _panelDecoration(),
      padding: const pw.EdgeInsets.all(7),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 22,
            child: _dogInfoCard(
              role: 'DAM',
              dog: dam,
              stats: damStats,
            ),
          ),
          pw.SizedBox(width: 5),
          pw.Expanded(
            flex: 24,
            child: _dogPhoto(damImageBytes),
          ),
          pw.Expanded(
            flex: 8,
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'X',
                  style: pw.TextStyle(
                    color: PdfColor.fromHex('#D4AF37'),
                    fontSize: 30,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Expected\nLitter\nOutcomes',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: PdfColor.fromHex('#2B0B45'),
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.Expanded(
            flex: 24,
            child: _dogPhoto(sireImageBytes),
          ),
          pw.SizedBox(width: 5),
          pw.Expanded(
            flex: 22,
            child: _dogInfoCard(
              role: 'SIRE',
              dog: sire,
              stats: sireStats,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _dogInfoCard({
    required String role,
    required Map<String, dynamic> dog,
    required Map<String, dynamic> stats,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#3B0F4D'),
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text(
              role,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          dog['dog_name'] ?? '-',
          maxLines: 2,
          style: pw.TextStyle(
            color: PdfColor.fromHex('#2B0B45'),
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          dog['pet_name'] ?? '',
          style: pw.TextStyle(
            color: PdfColor.fromHex('#D4AF37'),
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 5),
        _smallDogLine('ALA', dog['dog_ala']),
        _smallDogLine('Colour', dog['colour']),
        _smallDogLine('Coat', dog['coat_type']),
        _smallDogLine('Size', dog['size']),
        _smallDogLine('Grade', dog['ala_grade']),
        pw.SizedBox(height: 4),
        pw.Text(
          '${stats['litters']} Litters | ${stats['puppies']} Puppies',
          style: pw.TextStyle(
            fontSize: 6.8,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 3),
        _miniGenderRatio(stats),
      ],
    );
  }

  pw.Widget _smallDogLine(String label, dynamic value) {
    final display = value == null || value.toString().trim().isEmpty
        ? 'NYA'
        : value.toString();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1.5),
      child: pw.Text(
        '$label: $display',
        maxLines: 1,
        style: const pw.TextStyle(fontSize: 6.7),
      ),
    );
  }

  pw.Widget _dogPhoto(Uint8List? imageBytes) {
    return pw.Container(
      height: double.infinity,
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(4),
        color: PdfColor.fromHex('#F5F2EE'),
      ),
      child: imageBytes != null
          ? pw.ClipRRect(
              horizontalRadius: 4,
              verticalRadius: 4,
              child: pw.Image(
                pw.MemoryImage(imageBytes),
                fit: pw.BoxFit.cover,
              ),
            )
          : pw.Center(
              child: pw.Text(
                'No Photo',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
    );
  }

  // =====================================================
  // SECTION 3 - PUPPY OUTCOMES
  // =====================================================

  pw.Widget _buildPuppyOutcomesSection({
    required Map<String, dynamic> breedingPlan,
    required List<Map<String, dynamic>> colourKeyItems,
  }) {
    return pw.Container(
      height: 205,
      decoration: _panelDecoration(),
      padding: const pw.EdgeInsets.all(9),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('PUPPY COLOUR OUTCOMES (EXPECTED %)'),
          pw.SizedBox(height: 6),
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 42,
                  child: pw.Column(
                    children: [
                      pw.Expanded(
                        child: _colourWheelCard(breedingPlan),
                      ),
                      pw.SizedBox(height: 5),
                      _colourKeyStrip(colourKeyItems),
                    ],
                  ),
                ),
                pw.SizedBox(width: 7),
                pw.Expanded(
                  flex: 24,
                  child: _phantomCard(breedingPlan),
                ),
                pw.SizedBox(width: 7),
                pw.Expanded(
                  flex: 34,
                  child: pw.Column(
                    children: [
                      pw.Expanded(child: _allPuppiesWillCard()),
                      pw.SizedBox(height: 6),
                      _coatOutcomesCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _colourWheelCard(Map<String, dynamic> breedingPlan) {
    // This is the PDF version of the breeding-plan-page donut.
    // It is deliberately fixed-size for print consistency.
    return pw.Container(
      decoration: _innerBoxDecoration(),
      padding: const pw.EdgeInsets.all(7),
      child: pw.Row(
        children: [
          pw.Container(
            width: 130,
            height: 130,
            child: _breedingPlanStyleDonut(),
          ),
          pw.SizedBox(width: 9),
          pw.Expanded(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _wheelLegendRow(
                  percent: '50%',
                  label: 'CHOCOLATE',
                  colourHex: '#6B442D',
                ),
                pw.SizedBox(height: 16),
                _wheelLegendRow(
                  percent: '50%',
                  label: 'CARAMEL / APRICOT',
                  colourHex: '#D8A15B',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _breedingPlanStyleDonut() {
    return pw.Stack(
      alignment: pw.Alignment.center,
      children: [
        // Gold half background
        pw.Container(
          width: 124,
          height: 124,
          decoration: pw.BoxDecoration(
            shape: pw.BoxShape.circle,
            color: PdfColor.fromHex('#D8A15B'),
          ),
        ),

        // Chocolate half overlay
        pw.Positioned(
          left: 0,
          child: pw.Container(
            width: 62,
            height: 124,
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#6B442D'),
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(62),
                bottomLeft: pw.Radius.circular(62),
              ),
            ),
          ),
        ),

        // White centre hole
        pw.Container(
          width: 46,
          height: 46,
          decoration: const pw.BoxDecoration(
            shape: pw.BoxShape.circle,
            color: PdfColors.white,
          ),
        ),

        // Left percent
        pw.Positioned(
          left: 16,
          top: 47,
          child: pw.Text(
            '50%',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),

        // Right percent
        pw.Positioned(
          right: 15,
          top: 47,
          child: pw.Text(
            '50%',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _wheelLegendRow({
    required String percent,
    required String label,
    required String colourHex,
  }) {
    return pw.Row(
      children: [
        pw.Container(
          width: 9,
          height: 9,
          decoration: pw.BoxDecoration(
            shape: pw.BoxShape.circle,
            color: PdfColor.fromHex(colourHex),
          ),
        ),
        pw.SizedBox(width: 7),
        pw.Text(
          percent,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(width: 7),
        pw.Expanded(
          child: pw.Text(
            label,
            maxLines: 2,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _phantomCard(Map<String, dynamic> breedingPlan) {
    final phantomSummary = breedingPlan['phantom_summary'] ?? '~25%';
    return pw.Container(
      decoration: _innerBoxDecoration(),
      padding: const pw.EdgeInsets.all(7),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            'PHANTOM',
            style: pw.TextStyle(
              color: PdfColor.fromHex('#2B0B45'),
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            phantomSummary,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              color: PdfColor.fromHex('#D4AF37'),
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 7),
          pw.Text(
            'PUPPIES MAY BE PHANTOM',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Phantom gene carried by both parents where indicated.',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 6.5),
          ),
        ],
      ),
    );
  }

  pw.Widget _allPuppiesWillCard() {
    return pw.Container(
      width: double.infinity,
      decoration: _innerBoxDecoration(),
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(
            child: pw.Text(
              'ALL PUPPIES WILL:',
              style: pw.TextStyle(
                color: PdfColor.fromHex('#2B0B45'),
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 7),
          _checkLine('Carry chocolate where inherited'),
          _checkLine('Have low shedding fleece coats'),
          _checkLine('Be furnished'),
          _checkLine('Be reviewed for phantom expression'),
          _checkLine('Have pigment reviewed'),
        ],
      ),
    );
  }

  pw.Widget _checkLine(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 8,
            height: 8,
            decoration: pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              color: PdfColor.fromHex('#3B0F4D'),
            ),
          ),
          pw.SizedBox(width: 5),
          pw.Expanded(
            child: pw.Text(text, style: const pw.TextStyle(fontSize: 6.8)),
          ),
        ],
      ),
    );
  }

  pw.Widget _coatOutcomesCard() {
    return pw.Container(
      width: double.infinity,
      height: 56,
      decoration: _innerBoxDecoration(),
      padding: const pw.EdgeInsets.all(6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _coatMini('WAVE', 'Most Likely', '~~~'),
          _coatMini('CURLY', 'Possible', 'OOO'),
          _coatMini('STRAIGHT', 'Unlikely', '|||'),
          _coatMini('LOW', 'Shedding', '100%'),
        ],
      ),
    );
  }

  pw.Widget _coatMini(String title, String sub, String iconText) {
    return pw.Container(
      width: 42,
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            iconText,
            style: pw.TextStyle(
              color: PdfColor.fromHex('#B87422'),
              fontSize: iconText == '100%' ? 13 : 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            title,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 6.8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#2B0B45'),
            ),
          ),
          pw.Text(
            sub,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 5.4),
          ),
        ],
      ),
    );
  }

  pw.Widget _colourKeyStrip(
    List<Map<String, dynamic>> items,
  ) {
    return pw.Container(
      height: 58,
      decoration: _innerBoxDecoration(),
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: items.map((item) {
          return _colourKeyItem(
            item['label'] as String,
            item['hex'] as String,
            item['bytes'] as Uint8List?,
          );
        }).toList(),
      ),
    );
  }

  pw.Widget _colourKeyItem(
    String label,
    String hex,
    Uint8List? imageBytes,
  ) {
    return pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Container(
          width: 46,
          height: 36,
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex(hex),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: imageBytes != null
              ? pw.ClipRRect(
                  horizontalRadius: 5,
                  verticalRadius: 5,
                  child: pw.Image(
                    pw.MemoryImage(imageBytes),
                    fit: pw.BoxFit.cover,
                  ),
                )
              : pw.Container(),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          label,
          textAlign: pw.TextAlign.center,
          maxLines: 2,
          style: pw.TextStyle(
            color: PdfColor.fromHex('#2B0B45'),
            fontSize: 5.6,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // =====================================================
  // SECTION 4 - GENETICS + HEALTH
  // =====================================================

  pw.Widget _buildGeneticsHealthSection({
    required Map<String, dynamic> breedingPlan,
  }) {
    return pw.Container(
      height: 125,
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 60,
            child: _geneticTraitsSummary(),
          ),
          pw.SizedBox(width: 7),
          pw.Expanded(
            flex: 40,
            child: _healthConsiderations(breedingPlan),
          ),
        ],
      ),
    );
  }

  pw.Widget _geneticTraitsSummary() {
    return pw.Container(
      decoration: _panelDecoration(),
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('GENETIC TRAITS SUMMARY'),
          pw.SizedBox(height: 5),
          _traitTableRow('Colour Genes', 'Both parents reviewed for colour loci.', 'Expected colour range calculated.'),
          _traitTableRow('Phantom Gene', 'Tan point capability reviewed.', 'Phantom possible where inherited.'),
          _traitTableRow('Coat Type', 'Fleece coat expected.', 'Low shedding coat target.'),
          _traitTableRow('Furnishings', 'Furnishings reviewed.', 'Furnished puppies expected.'),
          _traitTableRow('Nose Pigment', 'Pigment inheritance reviewed.', 'Pigment noted for litter.'),
        ],
      ),
    );
  }

  pw.Widget _traitTableRow(String label, String left, String right) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.3)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 60,
            child: pw.Text(label, style: pw.TextStyle(fontSize: 6.6, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(child: pw.Text(left, style: const pw.TextStyle(fontSize: 6.3))),
          pw.SizedBox(width: 4),
          pw.Expanded(child: pw.Text(right, style: const pw.TextStyle(fontSize: 6.3))),
        ],
      ),
    );
  }

  pw.Widget _healthConsiderations(Map<String, dynamic> breedingPlan) {
    final pra = breedingPlan['pra_summary'] ?? 'PRA status reviewed where available.';
    final copper = breedingPlan['copper_summary'] ??
        breedingPlan['copper_toxicosis_summary'] ??
        'Carrier status reviewed.';
    final eic = breedingPlan['eic_summary'] ?? 'Clear / carrier risks reviewed.';
    final diseaseSummary = breedingPlan['disease_summary'] ??
        breedingPlan['health_warning_summary'] ??
        'Disease carrier risks reviewed where data is available.';

    return pw.Container(
      decoration: _panelDecoration(),
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('HEALTH + GENETIC CONSIDERATIONS'),
          pw.SizedBox(height: 5),
          _healthRow('Disease / Carrier Summary', diseaseSummary),
          _healthRow('Copper Toxicosis', copper),
          _healthRow('PRA', pra),
          _healthRow('EIC', eic),
          _healthRow('Hips + Elbows', 'NYA where not yet active.'),
        ],
      ),
    );
  }

  pw.Widget _healthRow(String title, String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 22,
            height: 22,
            decoration: pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              color: PdfColor.fromHex('#F3E7D6'),
              border: pw.Border.all(color: PdfColor.fromHex('#D4AF37'), width: 0.5),
            ),
            child: pw.Center(
              child: pw.Text(
                _healthIconText(title),
                style: pw.TextStyle(
                  color: PdfColor.fromHex('#3B0F4D'),
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(text, maxLines: 2, style: const pw.TextStyle(fontSize: 5.9)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _healthIconText(String title) {
    final t = title.toLowerCase();
    if (t.contains('copper')) return 'Cu';
    if (t.contains('pra')) return 'Eye';
    if (t.contains('eic')) return 'EIC';
    if (t.contains('hip')) return 'Hip';
    return 'DNA';
  }

  // =====================================================
  // SECTION 5 - RECOMMENDATION
  // =====================================================

  pw.Widget _buildRecommendationSection({
    required Map<String, dynamic> breedingPlan,
  }) {
    final ibc = breedingPlan['ala_ibc']?.toString() ?? '--';
    final commonAncestor = _nearestRelativesText(breedingPlan);
    final alaGrade = breedingPlan['expected_ala_grade'] ?? 'Review Required';
    final notes = breedingPlan['notes'] ?? '';

    return pw.Container(
      height: 65,
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 34,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#2B0B45'),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('THIS MATING IS IDEAL FOR', style: pw.TextStyle(color: PdfColor.fromHex('#D4AF37'), fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  _goldLine('Consistent fleece coat quality'),
                  _goldLine('Balanced colour range'),
                  _goldLine('Low shedding family coats'),
                  _goldLine('Future breeding potential'),
                ],
              ),
            ),
          ),
          pw.SizedBox(width: 7),
          pw.Expanded(
            flex: 33,
            child: _recommendationCard(
              title: 'BREEDING GOALS SUPPORTED',
              lines: [
                'ALA IBC: $ibc%',
                'Expected ALA Grade: $alaGrade',
                'Nearest Relatives: $commonAncestor',
              ],
            ),
          ),
          pw.SizedBox(width: 7),
          pw.Expanded(
            flex: 33,
            child: _recommendationCard(
              title: 'NOTES',
              lines: [
                notes.isEmpty ? 'Breeder notes may be added here.' : notes,
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _nearestRelativesText(Map<String, dynamic> breedingPlan) {
    final direct = breedingPlan['closest_common_ancestor'] ??
        breedingPlan['shared_ancestors_summary'] ??
        breedingPlan['nearest_relatives_summary'];

    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString();
    }

    final shared = breedingPlan['shared_ancestors'];
    if (shared is List && shared.isNotEmpty) {
      return shared.take(3).map((e) => e.toString()).join(', ');
    }

    return 'No close common ancestor recorded';
  }

  pw.Widget _goldLine(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Text(
        '- $text',
        style: const pw.TextStyle(color: PdfColors.white, fontSize: 6.5),
      ),
    );
  }

  pw.Widget _recommendationCard({required String title, required List<String> lines}) {
    return pw.Container(
      height: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: _panelDecoration(),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2B0B45'))),
          pw.SizedBox(height: 5),
          ...lines.map((l) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(l, maxLines: 2, style: const pw.TextStyle(fontSize: 6.3)),
          )),
        ],
      ),
    );
  }

  // =====================================================
  // SECTION 6 - FOOTER
  // =====================================================

  pw.Widget _buildFooter({
    required Map<String, dynamic>? company,
    required Uint8List? associationLogoBytes,
  }) {
    final footerText =
    company?['footer_text'] ??
    'Ethical Breeding - Exceptional Dogs - Lifetime Support';

  final website =
      company?['website'] ?? '';

  final disclaimer =
      company?['default_disclaimer'] ??
      'This report is intended for responsible breeding decisions between responsible breeders.';

    return pw.Container(
      height: 44,
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#2B0B45'),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 22,
            child: pw.Text(
              company?['company_name'] ?? 'Amity Labradoodles',
              style: pw.TextStyle(
                color: PdfColor.fromHex('#D4AF37'),
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            flex: 50,
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  footerText,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: PdfColor.fromHex('#D4AF37'),
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  disclaimer,
                  textAlign: pw.TextAlign.center,
                  maxLines: 2,
                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 5.5),
                ),
              ],
            ),
          ),
          pw.Expanded(
            flex: 28,
            child: pw.Text(
              website,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                color: PdfColor.fromHex('#D4AF37'),
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // SHARED HELPERS
  // =====================================================

  pw.BoxDecoration _panelDecoration() {
    return pw.BoxDecoration(
      color: PdfColor.fromHex('#FFFCF7'),
      border: pw.Border.all(color: PdfColor.fromHex('#D4AF37'), width: 0.8),
      borderRadius: pw.BorderRadius.circular(7),
    );
  }

  pw.BoxDecoration _innerBoxDecoration() {
    return pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: PdfColor.fromHex('#E2D3A2'), width: 0.6),
      borderRadius: pw.BorderRadius.circular(5),
    );
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        color: PdfColor.fromHex('#2B0B45'),
        fontSize: 10.5,
        fontWeight: pw.FontWeight.bold,
      ),
    );
  }

  pw.Widget _miniGenderRatio(Map<String, dynamic> stats) {
    final females = stats['females'] ?? 0;
    final males = stats['males'] ?? 0;
    final total = females + males;
    final femalePercent = total == 0 ? 0.0 : females / total;
    final malePercent = total == 0 ? 0.0 : males / total;

    final double femaleWidth = (68 * femalePercent).toDouble();
    final double maleWidth = (68 * malePercent).toDouble();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          height: 5,
          width: 68,
          child: pw.Row(
            children: [
              pw.Container(width: femaleWidth, color: PdfColor.fromHex('#C98AA5')),
              pw.Container(width: maleWidth, color: PdfColor.fromHex('#6F8FBF')),
            ],
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          '${(femalePercent * 100).round()}% Female | ${(malePercent * 100).round()}% Male',
          style: const pw.TextStyle(fontSize: 5.5),
        ),
      ],
    );
  }

  // =====================================================
  // COLOUR KEY SYSTEM
  // =====================================================

  Future<Uint8List?> _networkImageBytes(String? url) async {
    if (url == null || url.isEmpty) return null;

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (_) {}

    return null;
  }
  Future<Uint8List?> _fetchDogImage(
  String? dogId,
  String? dogAla,
    ) async {
      if (dogId == null || dogAla == null) return null;

      try {
        final photo = await supabase
            .from('dog_photos')
            .select('url, file_name, storage_path, is_hero')
            .eq('dog_id', dogId)
            .eq('is_hero', true)
            .maybeSingle();

        if (photo == null) return null;

        final rawPath =
            photo['storage_path'] ??
            photo['url'] ??
            photo['file_name'];

        if (rawPath == null) return null;

        final path = rawPath.toString().startsWith('$dogAla/')
            ? rawPath.toString()
            : '$dogAla/photos/${rawPath.toString()}';

        final bytes = await supabase.storage
            .from('dog_files')
            .download(path);

        return bytes;
      } catch (e) {
        return null;
      }
    }
    Future<Map<String, dynamic>> _fetchLitterStats(String? dogAla) async {
    if (dogAla == null || dogAla.isEmpty) {
      return {
        'litters': 0,
        'puppies': 0,
        'males': 0,
        'females': 0,
      };
    }

    try {
      final litters = await supabase
          .from('litters')
          .select('id, male_count, female_count')
          .or('dam_ala.eq.$dogAla,sire_ala.eq.$dogAla');

      int totalLitters = 0;
      int males = 0;
      int females = 0;

      for (final litter in litters as List) {
        totalLitters++;

        males += (litter['male_count'] ?? 0) as int;
        females += (litter['female_count'] ?? 0) as int;
      }

      return {
        'litters': totalLitters,
        'puppies': males + females,
        'males': males,
        'females': females,
      };
    } catch (e) {
      return {
        'litters': 0,
        'puppies': 0,
        'males': 0,
        'females': 0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> _buildDynamicColourKeyItems(
    Map<String, dynamic> breedingPlan,
  ) async {
    return [
      {
        'label': 'Chocolate',
        'hex': '#6B442D',
        'bytes': null,
      },
      {
        'label': 'Caramel',
        'hex': '#D8A15B',
        'bytes': null,
      },
      {
        'label': 'Black',
        'hex': '#2B2B2B',
        'bytes': null,
      },
      {
        'label': 'Phantom',
        'hex': '#5A3A6E',
        'bytes': null,
      },
      {
        'label': 'Parti',
        'hex': '#E8E1D4',
        'bytes': null,
      },
    ];
  }
}
