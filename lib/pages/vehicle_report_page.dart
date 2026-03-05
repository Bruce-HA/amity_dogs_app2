import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:intl/intl.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:printing/printing.dart';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class VehicleReportPage extends StatefulWidget {
  final String vehicleName;

  const VehicleReportPage({super.key, required this.vehicleName});

  @override
  State<VehicleReportPage> createState() => _VehicleReportPageState();
}

class _VehicleReportPageState extends State<VehicleReportPage> {
  final supabase = Supabase.instance.client;

  DateTime startDate = DateTime.now().subtract(const Duration(days: 30));

  DateTime endDate = DateTime.now();

  String tripFilter = "Both";

  bool loading = false;

  pw.MemoryImage? logo;

  @override
  void initState() {
    super.initState();
    loadLogo();
  }

  Future<void> loadLogo() async {
    final bytes = await rootBundle.load('assets/images/amity_logo.png');

    logo = pw.MemoryImage(bytes.buffer.asUint8List());
  }

  // =============================
  // DATE PICKERS
  // =============================

  Future<void> pickStartDate() async {
    final picked = await showDatePicker(
      context: context,

      initialDate: startDate,

      firstDate: DateTime(2020),

      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        startDate = picked;
      });
    }
  }

  Future<void> pickEndDate() async {
    final picked = await showDatePicker(
      context: context,

      initialDate: endDate,

      firstDate: DateTime(2020),

      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        endDate = picked;
      });
    }
  }

  // =============================
  // LOAD LOG DATA
  // =============================

  Future<List<Map<String, dynamic>>> loadLogs() async {
    final builder = supabase
        .from('vehicle_logs')
        .select()
        .eq('vehicle_name', widget.vehicleName)
        .gte('created_at', startDate.toIso8601String())
        .lte('created_at', endDate.toIso8601String());

    if (tripFilter == "Business") {
      builder.eq('is_business', true);
    }

    if (tripFilter == "Private") {
      builder.eq('is_business', false);
    }

    final data = await builder.order('created_at');

    return List<Map<String, dynamic>>.from(data);
  }

  // =============================
  // SUPABASE BACKUP
  // =============================

  Future<void> uploadPdfToSupabase(Uint8List bytes, String filename) async {
    try {
      final vehicle = widget.vehicleName.replaceAll(" ", "");

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final safeFilename = "${timestamp}_$filename";

      final path = "$vehicle/$safeFilename";

      debugPrint("Uploading to Supabase path: $path");

      await supabase.storage
          .from('vehicle_reports')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: true,
            ),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Backup saved successfully"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("SUPABASE UPLOAD ERROR: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Backup failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // =============================
  // EMAIL REPORT
  // =============================

  Future<void> emailPdf(pw.Document pdf) async {
    final bytes = await pdf.save();

    final dir = await getTemporaryDirectory();

    final vehicle = widget.vehicleName.replaceAll(" ", "");

    final trip = tripFilter == "Both" ? "AllTrips" : tripFilter;

    final start = DateFormat("yyyy-MM-dd").format(startDate);

    final end = DateFormat("yyyy-MM-dd").format(endDate);

    final filename = "Amity_${vehicle}_${trip}_${start}_to_${end}.pdf";

    final file = File("${dir.path}/$filename");

    await file.parent.create(recursive: true);

    await file.writeAsBytes(bytes);

    await uploadPdfToSupabase(bytes, filename);

    await Share.shareXFiles([XFile(file.path)], subject: "Vehicle Log Report");
  }

  // =============================
  // PDF CELL
  // =============================

  pw.Widget cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  // =============================
  // GENERATE PDF
  // =============================

  Future<void> generatePdf() async {
    setState(() => loading = true);

    final logs = await loadLogs();

    int totalKm = 0;
    int businessKm = 0;
    int privateKm = 0;

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,

        footer: (context) {
          return pw.Align(
            alignment: pw.Alignment.centerRight,

            child: pw.Text(
              "Page ${context.pageNumber} "
              "of ${context.pagesCount}",
            ),
          );
        },

        build: (context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,

              children: [
                pw.Text(
                  "${widget.vehicleName} "
                  "Vehicle Report",
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                if (logo != null) pw.Image(logo!, width: 80),
              ],
            ),

            pw.SizedBox(height: 20),

            pw.Table(
              border: pw.TableBorder.all(),

              children: [
                pw.TableRow(
                  children: [
                    cell("Date", bold: true),

                    cell("Driver", bold: true),

                    cell("Business", bold: true),

                    cell("Start", bold: true),

                    cell("End", bold: true),

                    cell("Distance", bold: true),

                    cell("Notes", bold: true),
                  ],
                ),

                ...logs.map((log) {
                  final start = (log['start_km'] ?? 0) as num;

                  final end = (log['end_km'] ?? 0) as num;

                  final distance = end.toInt() - start.toInt();

                  totalKm += distance;

                  if (log['is_business'])
                    businessKm += distance;
                  else
                    privateKm += distance;

                  return pw.TableRow(
                    children: [
                      cell(
                        DateFormat(
                          'dd/MM/yyyy',
                        ).format(DateTime.parse(log['created_at'])),
                      ),

                      cell(log['driver_name'] ?? ""),

                      cell(log['is_business'] ? "Yes" : "No"),

                      cell(start.toString()),

                      cell(end.toString()),

                      cell(distance.toString()),

                      cell(log['notes'] ?? ""),
                    ],
                  );
                }).toList(),
              ],
            ),

            pw.SizedBox(height: 20),

            pw.Text("Total KM: $totalKm"),

            pw.Text("Business KM: $businessKm"),

            pw.Text("Private KM: $privateKm"),
          ];
        },
      ),
    );

    setState(() => loading = false);

    await Navigator.push(
      context,

      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text("Report Preview"),

            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.email),

                  label: const Text("Save and Email Report"),

                  onPressed: () => emailPdf(pdf),
                ),
              ),

              Expanded(
                child: PdfPreview(
                  build: (format) async => pdf.save(),
                  canDebug: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =============================
  // UI
  // =============================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "${widget.vehicleName} "
          "Report",
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [
            DropdownButtonFormField(
              initialValue: tripFilter,

              items: const [
                DropdownMenuItem(value: "Both", child: Text("Both")),

                DropdownMenuItem(value: "Business", child: Text("Business")),

                DropdownMenuItem(value: "Private", child: Text("Private")),
              ],

              onChanged: (value) {
                setState(() {
                  tripFilter = value.toString();
                });
              },
            ),

            const SizedBox(height: 10),

            ListTile(
              title: Text(
                "Start Date: "
                "${DateFormat('dd/MM/yyyy').format(startDate)}",
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: pickStartDate,
            ),

            ListTile(
              title: Text(
                "End Date: "
                "${DateFormat('dd/MM/yyyy').format(endDate)}",
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: pickEndDate,
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: loading ? null : generatePdf,

              child: const Text("Generate Report"),
            ),
          ],
        ),
      ),
    );
  }
}
