import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

import '../dog_details_page.dart';
import '../../services/pedigree_service.dart';

class SimplePedigreePage extends StatefulWidget {
  final String? initialDogAla;
  final int initialGenerations;

  const SimplePedigreePage({
    super.key,
    this.initialDogAla,
    this.initialGenerations = 3,
  });

  @override
  State<SimplePedigreePage> createState() => _SimplePedigreePageState();
}

class _SimplePedigreePageState extends State<SimplePedigreePage> {
  final SupabaseClient supabase = Supabase.instance.client;

  final TextEditingController _alaController = TextEditingController();

  late int _generations;

  bool _loading = false;
  Map<String, dynamic>? _tree;

  @override
  void initState() {
    super.initState();

    _generations = widget.initialGenerations;

    if (widget.initialDogAla != null &&
        widget.initialDogAla!.trim().isNotEmpty) {
      _alaController.text = widget.initialDogAla!.trim();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        fetchPedigree();
      });
    }
  }

  @override
  void dispose() {
    _alaController.dispose();
    super.dispose();
  }

  Future<void> fetchPedigree() async {
    setState(() {
      _loading = true;
      _tree = null;
    });

    final query = _alaController.text.trim();

    if (query.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    try {
      final dog = await supabase
          .from('dogs')
          .select('id, dog_ala')
          .or('dog_ala.eq.$query,dog_name.ilike.%$query%')
          .limit(1)
          .maybeSingle();

      if (dog == null) {
        setState(() => _loading = false);
        return;
      }

      final tree = await PedigreeService().getPedigreeTree(
        dogId: dog['id'],
        generations: _generations,
      );

      if (!mounted) return;

      setState(() {
        _tree = tree;
        _loading = false;
      });
    } catch (e) {
      debugPrint('PEDIGREE ERROR: $e');

      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load pedigree: $e'),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _flattenTree(
    Map<String, dynamic> node, {
    int level = 0,
    String role = 'Subject',
  }) {
    final list = <Map<String, dynamic>>[];

    list.add({
      'dog': node,
      'level': level,
      'role': role,
    });

    if (node['father'] != null) {
      list.addAll(
        _flattenTree(
          node['father'],
          level: level + 1,
          role: 'Sire',
        ),
      );
    }

    if (node['mother'] != null) {
      list.addAll(
        _flattenTree(
          node['mother'],
          level: level + 1,
          role: 'Dam',
        ),
      );
    }

    return list;
  }

  Widget _buildDogCard({
    required Map<String, dynamic> dog,
    required int level,
    required String role,
  }) {
    final indent = level * 18.0;

    final name = (dog['name'] ?? '').toString();
    final ala = (dog['ala'] ?? '').toString();
    final colour = (dog['colour'] ?? '').toString();
    final sex = (dog['sex'] ?? '').toString();
    final dob = (dog['dob'] ?? '').toString();
    final hero = dog['hero'];

    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: 8),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(10),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: hero != null && hero.toString().isNotEmpty
                ? Image.network(
                    hero,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return const SizedBox(
                        width: 56,
                        height: 56,
                        child: Icon(Icons.pets),
                      );
                    },
                  )
                : const SizedBox(
                    width: 56,
                    height: 56,
                    child: Icon(Icons.pets),
                  ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name.isEmpty ? 'Unnamed Dog' : name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Chip(
                label: Text(role),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          subtitle: Text(
            [
              if (ala.isNotEmpty) ala,
              if (sex.isNotEmpty) sex,
              if (colour.isNotEmpty) colour,
              if (dob.isNotEmpty) dob,
            ].join(' • '),
          ),
          trailing: dog['id'] == null
              ? null
              : const Icon(Icons.chevron_right),
          onTap: dog['id'] == null
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DogDetailsPage(
                        dogId: dog['id'],
                      ),
                    ),
                  );
                },
        ),
      ),
    );
  }

  Future<void> printPedigree() async {
    if (_tree == null) return;

    final flatList = _flattenTree(_tree!);
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: flatList.map((item) {
              final dog = item['dog'] as Map<String, dynamic>;
              final level = item['level'] as int;
              final role = item['role'] as String;

              final name = (dog['name'] ?? 'Unnamed Dog').toString();
              final ala = (dog['ala'] ?? '').toString();

              return pw.Padding(
                padding: pw.EdgeInsets.only(
                  left: level * 14.0,
                  bottom: 4,
                ),
                child: pw.Text(
                  '$role - $name ${ala.isNotEmpty ? "($ala)" : ""}',
                ),
              );
            }).toList(),
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'simple_pedigree.pdf',
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tree == null) {
      return const Center(
        child: Text(
          'No results yet',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    final flatList = _flattenTree(_tree!);

    return ListView.builder(
      itemCount: flatList.length,
      itemBuilder: (context, index) {
        final item = flatList[index];

        return _buildDogCard(
          dog: item['dog'],
          level: item['level'],
          role: item['role'],
        );
      },
    );
  }

  void _newSearch() {
    setState(() {
      _tree = null;
      _alaController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple Pedigree'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _alaController,
              decoration: const InputDecoration(
                labelText: 'Dog ALA Number or Name',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => fetchPedigree(),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _generations,
                    decoration: const InputDecoration(
                      labelText: 'Generations',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(
                      25,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text('${index + 1} Generations'),
                      ),
                    ),
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        _generations = value;
                      });

                      if (_tree != null) {
                        fetchPedigree();
                      }
                    },
                  ),
                ),

                const SizedBox(width: 12),

                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: fetchPedigree,
                    icon: const Icon(Icons.search),
                    label: const Text('Search'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Expanded(
              child: _buildResults(),
            ),

            if (_tree != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _newSearch,
                      icon: const Icon(Icons.refresh),
                      label: const Text('New Search'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: printPedigree,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Print'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}