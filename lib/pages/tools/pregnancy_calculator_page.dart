import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

import '../dog_details_page.dart';
import '../../utils/date_utils.dart'; // your shared age calculator

class PregnancyCalculatorPage extends StatefulWidget {
  const PregnancyCalculatorPage({super.key});

  @override
  State<PregnancyCalculatorPage> createState() =>
      _PregnancyCalculatorPageState();
}

class _PregnancyCalculatorPageState
    extends State<PregnancyCalculatorPage> {
  final supabase = Supabase.instance.client;

  final _alaController = TextEditingController();

  Map<String, dynamic>? dog;
  DateTime? ovulationDate;
  String? heroUrl;
  DateTime? xrayDate;
  DateTime? expectedDelivery;
  DateTime? sixWeeks;
  DateTime? eightWeeks;

  final formatter = DateFormat('EEEE, d MMMM yyyy');

  Future<void> searchDog() async {
    final query = _alaController.text.trim();
    if (query.isEmpty) return;

    final result = await supabase
        .from('dogs')
        .select()
        .or('dog_ala.eq.$query,dog_name.ilike.%$query%')
        .eq('sex', 'Female')
        .limit(1)
        .maybeSingle();

    String? photoUrl;

    if (result != null) {
      final heroPhoto = await supabase
          .from('dog_photos')
          .select('url')
          .eq('dog_id', result['id'])
          .eq('is_hero', true)
          .maybeSingle();

      if (heroPhoto != null && heroPhoto['url'] != null) {
        photoUrl = supabase.storage
            .from('dog_files')
            .getPublicUrl(
                "${result['dog_ala']}/photos/${heroPhoto['url']}");
      }
    }

    setState(() {
      dog = result;
      heroUrl = photoUrl;
    });
  }

  void calculateDates() {
    if (ovulationDate == null) return;

    setState(() {
      xrayDate = ovulationDate!.add(const Duration(days: 56));
      expectedDelivery =
          ovulationDate!.add(const Duration(days: 63));
      sixWeeks =
          expectedDelivery!.add(const Duration(days: 42));
      eightWeeks =
          expectedDelivery!.add(const Duration(days: 56));
    });
  }
////====
///
///
///=====
  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() {
        ovulationDate = picked;
      });
      calculateDates();
    }
  }

  Future<void> sharePdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Pregnancy Schedule - ${dog?['dog_name']}",
                style: pw.TextStyle(fontSize: 20),
              ),
              pw.SizedBox(height: 10),
              pw.Text("Ovulation: ${formatter.format(ovulationDate!)}"),
              pw.Text("Pre-Delivery X-Ray: ${formatter.format(xrayDate!)}"),
              pw.Text("Expected Delivery: ${formatter.format(expectedDelivery!)}"),
              pw.Text("6 Weeks Old: ${formatter.format(sixWeeks!)}"),
              pw.Text("8 Weeks Old: ${formatter.format(eightWeeks!)}"),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'pregnancy_schedule.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pregnancy Date Calculator"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            /// DOG SEARCH
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _alaController,
                    decoration: const InputDecoration(
                      labelText: "Female Dog ALA",
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: searchDog,
                )
              ],
            ),

            const SizedBox(height: 16),
            /// Show dog
            if (dog != null)
              Card(
                margin: const EdgeInsets.only(top: 16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // HERO IMAGE
                      if (heroUrl != null)
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              heroUrl!,
                              height: 140,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),

                      const SizedBox(height: 12),

                      Text(
                        dog!['dog_name'],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      Text("ALA: ${dog!['dog_ala']}"),
                      Text("Age: ${calculateDogAge(dog!['dob'])}"),
                    ],
                  ),
                ),
              ),
            /// DATE PICKER
            ElevatedButton(
              onPressed: dog != null ? pickDate : null,
              child: const Text("Select Ovulation Date"),
            ),

            const SizedBox(height: 20),

            /// RESULTS
            if (dog != null &&
                ovulationDate != null &&
                expectedDelivery != null)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      /// HEADER
                      Text(
                        "${dog!['dog_name']}",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text("ALA: ${dog!['dog_ala']}"),
                      Text(
                        "Age: ${calculateDogAge(dog!['dob'])}",
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Expected Delivery: ${formatter.format(expectedDelivery!)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const Divider(height: 30),

                      Text("Ovulation Date: ${formatter.format(ovulationDate!)}"),
                      Text("Pre-Delivery X-Ray: ${formatter.format(xrayDate!)}"),
                      Text("Expected Delivery: ${formatter.format(expectedDelivery!)}"),
                      Text("6 Weeks Old: ${formatter.format(sixWeeks!)}"),
                      Text("8 Weeks Old: ${formatter.format(eightWeeks!)}"),

                      const SizedBox(height: 30),

                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: sharePdf,
                            child: const Text("Share / Email"),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}