import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';


class LitterWeightsChartPage extends StatelessWidget {
  final List puppies;
  final List weights;

  const LitterWeightsChartPage({
    super.key,
    required this.puppies,
    required this.weights,
  });

  List<String> getDates() {
    final dates = weights
        .map((w) => w['recorded_at'].toString())
        .toSet()
        .toList();

    dates.sort();
    return dates;
  }

  List<FlSpot> buildSpots(String dogId, List<String> dates) {
    List<FlSpot> spots = [];

    for (int i = 0; i < dates.length; i++) {
      final row = weights.firstWhere(
        (w) =>
            w['dog_id'] == dogId &&
            w['recorded_at'] == dates[i],
        orElse: () => <String, dynamic>{},
      );

      if (row.isNotEmpty && row['weight'] != null) {
        spots.add(FlSpot(i.toDouble(), row['weight'].toDouble()));
      }
    }

    return spots;
  }
//. print chart
  Future<void> exportPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              /// TITLE
              pw.Text(
                'Litter Weights',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 12),

              /// LEGEND
              pw.Wrap(
                spacing: 8,
                runSpacing: 8,
                children: puppies.map((pup) {
                  final num = pupNumber(pup['dog_ala'] ?? '');

                  return pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(),
                    ),
                    child: pw.Text('Pup#$num'),
                  );
                }).toList(),
              ),

              pw.SizedBox(height: 20),

              pw.Text('Chart will be added next step'),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'litter_weights.pdf',
    );
  }

///
  Color collarColor(String? collar) {
    final c = (collar ?? '').toLowerCase().trim();

    switch (c) {
      case 'blue':
        return Colors.blue;
      case 'orange':
        return Colors.orange;
      case 'red':
        return Colors.red;
      case 'pink':
        return Colors.pink;
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.yellow.shade700;
      default:
        return Colors.grey;
    }
  }

  String pupNumber(String ala) {
    if (!ala.contains('-')) return '';
    return ala.split('-').last.replaceFirst(RegExp(r'^0+'), '');
  }

  @override
  Widget build(BuildContext context) {
    final dates = getDates();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weight Chart'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              exportPdf();
            },
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(12),

        child: Column(
          children: [

            /// 🐶 LEGEND (compact blocks)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: puppies.map((pup) {
                final color = collarColor(pup['collar_colour']);
                final num = pupNumber(pup['dog_ala'] ?? '');

                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Pup#$num',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            /// 📈 CHART
            Expanded(
              child: InteractiveViewer(
                panEnabled: true,
                scaleEnabled: true,
                minScale: 1,
                maxScale: 4,

                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true),

                    /// ❌ REMOVE LEFT LABELS
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),

                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40, // 👈 ADD THIs
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= dates.length) {
                              return const SizedBox();
                            }

                            final d = dates[i];
                            final parts = d.split('-'); // yyyy-mm-dd

                            return Column(
                              mainAxisSize: MainAxisSize.min, // 👈 IMPORTANT
                              children: [
                                Text(
                                  parts[2],
                                  style: const TextStyle(fontSize: 10),
                                ),
                                Text(
                                  parts[1],
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),

                    borderData: FlBorderData(show: true),

                    lineBarsData: [
                      ...puppies.asMap().entries.map((entry) {
                        final index = entry.key;
                        final pup = entry.value;

                        return LineChartBarData(
                          spots: buildSpots(pup['id'], dates),
                          isCurved: true,
                          color: collarColor(pup['collar_colour']),
                          barWidth: 3,
                          dotData: FlDotData(show: true),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}