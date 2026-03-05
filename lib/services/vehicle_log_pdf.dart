import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;

class VehicleLogPdfService {
  static Future<pw.Document> generate({
    required List<Map<String, dynamic>> logs,
    required String vehicleName,
  }) async {
    final pdf = pw.Document();

    /// Load logo
    final logoBytes = await rootBundle.load('assets/images/amity_logo.png');

    final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());

    int totalKm = 0;
    int businessKm = 0;
    int privateKm = 0;

    for (final log in logs) {
      final distance = log['distance_km'] ?? 0;

      totalKm += distance;

      if (log['is_business'] == true) {
        businessKm += distance;
      } else {
        privateKm += distance;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        /// FORCE LANDSCAPE
        pageFormat: PdfPageFormat.a4.landscape,

        margin: const pw.EdgeInsets.all(24),

        build: (context) {
          return [
            /// HEADER WITH LOGO
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,

              children: [
                pw.Image(logo, height: 60),

                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,

                  children: [
                    pw.Text(
                      "Amity Labradoodles",
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),

                    pw.Text(
                      "$vehicleName Vehicle Report",
                      style: const pw.TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 20),

            /// TABLE
            pw.Table(
              border: pw.TableBorder.all(),

              columnWidths: {
                0: const pw.FlexColumnWidth(2), // Date
                1: const pw.FlexColumnWidth(3), // Driver
                2: const pw.FlexColumnWidth(2), // Business
                3: const pw.FlexColumnWidth(2), // Start
                4: const pw.FlexColumnWidth(2), // End
                5: const pw.FlexColumnWidth(2), // Distance
                6: const pw.FlexColumnWidth(6), // Notes (WIDE)
              },

              children: [
                /// HEADER ROW
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),

                  children: [
                    header("Date"),
                    header("Driver"),
                    header("Business"),
                    header("Start KM"),
                    header("End KM"),
                    header("Distance"),
                    header("Notes"),
                  ],
                ),

                /// DATA ROWS
                ...logs.map((log) {
                  return pw.TableRow(
                    children: [
                      cell(formatDate(log['log_date'])),

                      cell(log['driver_name']?.toString() ?? ''),

                      cell(log['is_business'] ? "Yes" : "No"),

                      cell(log['start_km'].toString()),

                      cell(log['end_km'].toString()),

                      cell(log['distance_km'].toString()),

                      cell(log['notes']?.toString() ?? ''),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 20),

            /// TOTAL SUMMARY
            pw.Container(
              padding: const pw.EdgeInsets.all(12),

              decoration: pw.BoxDecoration(border: pw.Border.all()),

              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,

                children: [
                  pw.Text(
                    "Summary",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  pw.SizedBox(height: 6),

                  pw.Text("Total KM: $totalKm"),

                  pw.Text("Business KM: $businessKm"),

                  pw.Text("Private KM: $privateKm"),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  static pw.Widget header(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),

      child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
    );
  }

  static pw.Widget cell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),

      child: pw.Text(text),
    );
  }

  static String formatDate(dynamic date) {
    if (date == null) return "";

    final d = DateTime.parse(date.toString());

    return "${d.day.toString().padLeft(2, '0')}/"
        "${d.month.toString().padLeft(2, '0')}/"
        "${d.year}";
  }
}
