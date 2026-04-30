import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/app_title.dart';
import 'litter_weights_chart_page.dart';

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
    final pups = await supabase
        .from('dogs')
        .select('id, dog_name, dog_ala, collar_colour, sex')
        .eq('litter_id', widget.litter['id'])
        .order('dog_ala', ascending: true);

    final w = await supabase
        .from('puppy_weights')
        .select()
        .eq('litter_id', widget.litter['id']);

    setState(() {
      puppies = pups as List;
      weights = w as List;
      loading = false;
    });
  }

  String label(Map pup) {
    final collar = pup['collar_colour'] ?? 'No Collar';
    final ala = pup['dog_ala'] ?? '';
    final sex = pup['sex'] ?? '';

    String pupNumber = '';

    if (ala.contains('-')) {
      final parts = ala.split('-');
      pupNumber = parts.last.replaceFirst(RegExp(r'^0+'), '');
    }

    final sexShort = sex == 'Male'
        ? 'M'
        : sex == 'Female'
            ? 'F'
            : '';

    return '#$pupNumber $collar $sexShort'.trim();
  }

  int? getWeight(String dogId, String date) {
    final row = weights.firstWhere(
      (w) =>
          w['dog_id'] == dogId &&
          w['recorded_at'] == date,
      orElse: () => <String, dynamic>{},
    );

    if (row.isEmpty) return null;
    return row['weight'];
  }

  int? getPreviousWeight(String dogId, String date) {
    final sorted = weights
        .where((w) => w['dog_id'] == dogId)
        .toList()
      ..sort((a, b) =>
          a['recorded_at'].compareTo(b['recorded_at']));

    for (int i = 0; i < sorted.length; i++) {
      final w = sorted[i];
      if (w['recorded_at'] == date) {
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

  Future<void> enterWeight(Map pup, String date) async {
    final controller = TextEditingController();

    DateTime selectedDate = DateTime.parse(date);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(label(pup)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Weight (g)'),
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
                'session': 'daily',
              });

              if (!mounted) return;
              Navigator.pop(context);
              loadData();
            },
            child: const Text('Save'),
          ),
        ],
      ),
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

  int? rowAverageGain(String date) {
    List<int> gains = [];

    for (var pup in puppies) {
      final current = getWeight(pup['id'], date);
      final previous = getPreviousWeight(pup['id'], date);

      if (current != null && previous != null) {
        gains.add(current - previous);
      }
    }

    if (gains.isEmpty) return null;

    return (gains.reduce((a, b) => a + b) / gains.length).round();
  }

  int? puppyAverageGain(String dogId) {
    final pupWeights = weights
        .where((w) => w['dog_id'] == dogId)
        .toList()
      ..sort((a, b) =>
          a['recorded_at'].compareTo(b['recorded_at']));

    List<int> gains = [];

    for (int i = 1; i < pupWeights.length; i++) {
      final current = pupWeights[i]['weight'];
      final previous = pupWeights[i - 1]['weight'];

      if (current != null && previous != null) {
        gains.add(current - previous);
      }
    }

    if (gains.isEmpty) return null;

    return (gains.reduce((a, b) => a + b) / gains.length).round();
  }

  String formatDate(String date) {
    final dt = DateTime.parse(date);

    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final day = days[dt.weekday - 1];

    final formatted =
        '${dt.day.toString().padLeft(2, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.year.toString().substring(2)}';

    return '$day $formatted';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toIso8601String().split('T').first;

    final dates = getDates();
    if (!dates.contains(today)) dates.add(today);

    return Scaffold(
      appBar: AppBar(
        title: buildTitle('Weights', 'LitterWeightsPage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LitterWeightsChartPage(
                    puppies: puppies,
                    weights: weights,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    const DataColumn(label: Text('Date')),
                    ...puppies.map((p) {
                      final collar = p['collar_colour'] ?? '';
                      final ala = p['dog_ala'] ?? '';
                      final sex = p['sex'] ?? '';

                      String pupNumber = '';
                      if (ala.contains('-')) {
                        pupNumber = ala.split('-').last.replaceFirst(RegExp(r'^0+'), '');
                      }

                      final sexShort = sex == 'Male'
                          ? 'M'
                          : sex == 'Female'
                              ? 'F'
                              : '';

                      return DataColumn(
                        label: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              collar,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text('#$pupNumber $sexShort'),
                          ],
                        ),
                      );
                    }),
                    const DataColumn(label: Text('Avg')),
                  ],
                  rows: [
                    ...dates.map((date) {
                      return DataRow(
                        cells: [
                          DataCell(Text(formatDate(date))),
                          ...puppies.map((pup) {
                            final w = getWeight(pup['id'], date);
                            final prev = getPreviousWeight(pup['id'], date);

                            return DataCell(
                              GestureDetector(
                                onTap: () => enterWeight(pup, date),
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
                          }),
                          DataCell(
                            Builder(builder: (_) {
                              final avg = rowAverageGain(date);
                              if (avg == null) return const Text('');

                              return Text(
                                avg > 0 ? '+$avg' : '$avg',
                                style: TextStyle(
                                color: avg < 0
                                    ? Colors.red
                                    : avg == 0
                                        ? Colors.orange
                                        : Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                              );
                            }),
                          ),
                        ],
                      );
                    }),

                    DataRow(
                      cells: [
                        const DataCell(Text('Avg')),
                        ...puppies.map((pup) {
                          final avg = puppyAverageGain(pup['id']);
                          if (avg == null) return const DataCell(Text(''));

                          return DataCell(
                            Text(
                              avg > 0 ? '+$avg' : '$avg',
                              style: TextStyle(
                                color: avg < 0
                                    ? Colors.red
                                    : avg == 0
                                        ? Colors.orange
                                        : Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }),
                        const DataCell(Text('')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}