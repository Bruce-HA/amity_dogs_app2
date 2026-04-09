import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/app_title.dart';

class LitterWeightsPage extends StatefulWidget {
  final Map litter;

  const LitterWeightsPage({
    super.key,
    required this.litter,
  });

  @override
  State<LitterWeightsPage> createState() => _LitterWeightsPageState();
}

class _LitterWeightsPageState extends State<LitterWeightsPage> {
  final supabase = Supabase.instance.client;

  List puppies = [];
  List weights = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      print('🔵 Loading puppies...');
      final pups = await supabase
          .from('dogs')
          .select('id, dog_name, dog_ala, collar_colour')
          .eq('litter_id', widget.litter['id'])
          .order('dog_ala', ascending: true);

      print('✅ Puppies loaded: ${pups.length}');

      print('🔵 Loading weights...');
      final w = await supabase
          .from('puppy_weights')
          .select()
          .eq('litter_id', widget.litter['id']);

      print('✅ Weights loaded: ${w.length}');

      setState(() {
        puppies = pups as List;
        weights = w as List;
        loading = false;
      });
    } catch (e) {
      print('❌ ERROR loading weights: $e');
      setState(() {
        loading = false;
      });
    }
  }

  String label(Map pup) {
    final name = pup['dog_name'] ?? '';
    final collar = pup['collar_colour'] ?? 'No Collar';

    return name.isNotEmpty ? "$collar ($name)" : collar;
  }

  int? getWeight(String dogId, String date, String session) {
    final row = weights.firstWhere(
      (w) =>
          w['dog_id'] == dogId &&
          w['recorded_at'] == date &&
          w['session'] == session,
      orElse: () => <String, dynamic>{}, // ✅ FIXED
    );

    if (row.isEmpty) return null;
    return row['weight'];
  }

  int? getPreviousWeight(String dogId, String date, String session) {
    final sorted = weights
        .where((w) => w['dog_id'] == dogId)
        .toList()
      ..sort((a, b) =>
          '${a['recorded_at']}${a['session']}'.compareTo(
              '${b['recorded_at']}${b['session']}'));

    for (int i = 0; i < sorted.length; i++) {
      final w = sorted[i];
      if (w['recorded_at'] == date && w['session'] == session) {
        if (i == 0) return null;
        return sorted[i - 1]['weight'];
      }
    }
    return null;
  }

  Color getColor(int current, int? previous) {
    if (previous == null) return Colors.black;
    if (current < previous) return Colors.red;
    if (current == previous) return Colors.orange;
    return Colors.green;
  }

  Future<void> enterWeight(Map pup, String date, String session) async {
    final controller = TextEditingController();

    DateTime selectedDate = DateTime.parse(date);
    String selectedSession = session;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('${label(pup)}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🐾 Weight input
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Weight (g)'),
                  ),

                  const SizedBox(height: 12),

                  // 📅 Date picker
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${selectedDate.toIso8601String().split('T').first}',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );

                          if (picked != null) {
                            setStateDialog(() {
                              selectedDate = picked;
                            });
                          }
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ⏰ AM / PM selector
                  DropdownButton<String>(
                    value: selectedSession,
                    isExpanded: true,
                    items: ['AM', 'PM']
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setStateDialog(() {
                        selectedSession = v!;
                      });
                    },
                  ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: () async {
                    final value = int.tryParse(controller.text);
                    if (value == null) return;

                    await supabase.from('puppy_weights').upsert({
                      'dog_id': pup['id'],
                      'litter_id': widget.litter['id'],
                      'weight': value,
                      'recorded_at':
                          selectedDate.toIso8601String().split('T').first,
                      'session': selectedSession,
                    });

                    if (!mounted) return;

                    Navigator.pop(context);
                    loadData();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<String> getDates() {
    final dates = weights
        .map((w) => w['recorded_at'].toString())
        .toSet()
        .toList();

    dates.sort();
    return dates;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toIso8601String().split('T').first;

    final dates = getDates();
    if (!dates.contains(today)) {
      dates.add(today);
    }

    return Scaffold(
      appBar: AppBar(
        title: buildTitle('Weights', 'LitterWeightsPage'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  const DataColumn(label: Text('Date')),
                  ...puppies.map((p) =>
                      DataColumn(label: Text(label(p)))),
                ],
                rows: dates.expand((date) {
                  return ['AM', 'PM'].map((session) {
                    return DataRow(
                      cells: [
                        DataCell(Text('$date $session')),
                        ...puppies.map((pup) {
                          final w = getWeight(
                              pup['id'], date, session);
                          final prev = getPreviousWeight(
                              pup['id'], date, session);

                          return DataCell(
                            GestureDetector(
                              onTap: () =>
                                  enterWeight(pup, date, session),
                              child: w == null
                                  ? const Text('+')
                                  : Text(
                                      '$w',
                                      style: TextStyle(
                                        color: getColor(w, prev),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          );
                        })
                      ],
                    );
                  });
                }).toList(),
              ),
            ),
    );
  }
}