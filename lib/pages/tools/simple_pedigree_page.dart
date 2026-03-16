import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import '../dog_details_page.dart';

class SimplePedigreePage extends StatefulWidget {
  const SimplePedigreePage({super.key});

  @override
  State<SimplePedigreePage> createState() => _SimplePedigreePageState();
}

class _SimplePedigreePageState extends State<SimplePedigreePage> {
  final _alaController = TextEditingController();
  int _generations = 3;

  List<dynamic> _results = [];
  bool _loading = false;

  final supabase = Supabase.instance.client;

  Future<void> fetchPedigree() async {
    setState(() {
      _loading = true;
      _results.clear();
    });

    final query = _alaController.text.trim();

    if (query.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    try {
      // First find the dog by ALA or Name
      final dog = await supabase
          .from('dogs')
          .select('dog_ala')
          .or('dog_ala.eq.$query,dog_name.ilike.%$query%')
          .limit(1)
          .maybeSingle();

      if (dog == null) {
        setState(() {
          _loading = false;
        });
        return;
      }

      // Then call pedigree function using its ALA
      final response = await supabase.rpc(
        'get_simple_pedigree',
        params: {
          'start_ala': dog['dog_ala'],
          'max_generations': _generations,
        },
      );

      setState(() {
        _results = response ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> printPedigree() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: _results.map((row) {
              return pw.Text(
                  "Gen ${row['generation']} - ${row['lineage_path']} - ${row['dog_name']} (${row['dog_ala']})");
            }).toList(),
          );
        },
      ),
    );

    await Printing.sharePdf(
    bytes: await pdf.save(),
    filename: 'pedigree.pdf',
  );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Simple Pedigree"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            /// INPUTS
            TextField(
              controller: _alaController,
              decoration: const InputDecoration(
                labelText: "Dog ALA Number",
              ),
            ),

            const SizedBox(height: 12),

            DropdownButton<int>(
              value: _generations,
              items: List.generate(
                25,
                (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text('${index + 1} Generations'),
                ),
              ),
              onChanged: (value) {
                setState(() => _generations = value!);
              },
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: fetchPedigree,
              child: const Text("Search"),
            ),

            const SizedBox(height: 16),

            if (_loading) const CircularProgressIndicator(),

            /// RESULTS
            if (!_loading)
  Expanded(
    child: _results.isEmpty
        ? const Center(
            child: Text(
              "No results found",
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final row = _results[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        left: (row['generation'] as int) * 20.0,
                        top: 4,
                        bottom: 4,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DogDetailsPage(
                                dogId: row['dog_id'],
                              ),
                            ),
                          );
                        },
                        child: Card(
                          child: ListTile(
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    row['dog_name'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                if (row['lineage_path'].toString().endsWith('SIRE'))
                                  Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Chip(
                                      label: const Text('Sire'),
                                      backgroundColor: Colors.lightBlue.shade100,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),

                                if (row['lineage_path'].toString().endsWith('DAM'))
                                  Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Chip(
                                      label: const Text('Dam'),
                                      backgroundColor: Colors.pink.shade100,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text('Generation ${row['generation']}'),
                            trailing: Text(row['dog_ala'] ?? ''),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            /// ACTION BUTTONS
            if (_results.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _results.clear();
                      });
                    },
                    child: const Text("New Search"),
                  ),
                  ElevatedButton(
                    onPressed: printPedigree,
                    child: const Text("Print"),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}