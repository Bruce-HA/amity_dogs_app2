import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BreedingPairDnaPage extends StatelessWidget {
  final Map<String, dynamic> female;
  final Map<String, dynamic> male;
  final Map<String, dynamic> plan;

  const BreedingPairDnaPage({
    super.key,
    required this.female,
    required this.male,
    required this.plan,
  });

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'DNA - ${plan['breeding_plan_code'] ?? 'Breeding Plan'}',
        ),
      ),
      body: FutureBuilder(
        future: Future.wait([
          supabase.from('dna_bank').select().eq('dog_id', female['id']),
          supabase.from('dna_bank').select().eq('dog_id', male['id']),
          supabase.from('dna_health').select().eq('dog_id', female['id']),
          supabase.from('dna_health').select().eq('dog_id', male['id']),
        ]),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('DNA error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final femaleDna =
              List<Map<String, dynamic>>.from(snapshot.data![0] as List);
          final maleDna =
              List<Map<String, dynamic>>.from(snapshot.data![1] as List);
          final femaleHealth =
              List<Map<String, dynamic>>.from(snapshot.data![2] as List);
          final maleHealth =
              List<Map<String, dynamic>>.from(snapshot.data![3] as List);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _pairHeader(),
              const SizedBox(height: 16),

              _dnaSection(
                title: 'Colour / Coat DNA',
                femaleRows: femaleDna,
                maleRows: maleDna,
                isHealth: false,
              ),

              const SizedBox(height: 16),

              _buildTraitProgressCard(
              _dnaToMap(femaleDna),
              _dnaToMap(maleDna),
            ),

              const SizedBox(height: 16),

              _dnaSection(
                title: 'Health DNA',
                femaleRows: femaleHealth,
                maleRows: maleHealth,
                isHealth: true,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _pairHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(
              plan['breeding_plan_code'] ?? '',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${female['dog_name'] ?? female['dog_ala']} × ${male['dog_name'] ?? male['dog_ala']}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              '${female['dog_ala'] ?? ''} × ${male['dog_ala'] ?? ''}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dnaSection({
    required String title,
    required List<Map<String, dynamic>> femaleRows,
    required List<Map<String, dynamic>> maleRows,
    required bool isHealth,
  }) {
    final keys = <String>{
      ...femaleRows.map((e) => _rowKey(e, isHealth)),
      ...maleRows.map((e) => _rowKey(e, isHealth)),
    }.where((e) => e.trim().isNotEmpty).toList()
      ..sort();

    if (keys.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text('No $title data found'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _comparisonHeader(),
            const Divider(),
            ...keys.map((key) {
              final f = _findRow(femaleRows, key, isHealth);
              final m = _findRow(maleRows, key, isHealth);

              return _comparisonRow(
                key,
                _displayValue(f, isHealth),
                _displayValue(m, isHealth),
              );
            }),
          ],
        ),
      ),
    );
  }
/// Traits
    Map<String, String> _dnaToMap(List<Map<String, dynamic>> dna) {
      final map = <String, String>{};

      for (final row in dna) {
        final locus = row['locus']?.toString();
        final a1 = row['allele_1']?.toString();
        final a2 = row['allele_2']?.toString();

        if (locus != null && locus.isNotEmpty) {
          map[locus] = '${a1 ?? '-'}/${a2 ?? '-'}';
        }
      }

      if (!map.containsKey('S')) {
        map['S'] = '(S/S) Assumed';
      }

      if (!map.containsKey('M')) {
        map['M'] = '(m/m) Assumed';
      }

      return map;
    }
/// 
/// 
  //====================
    Widget _buildTraitProgressCard(
      Map<String, String> female,
      Map<String, String> male,
    ) {
      final traits = <Map<String, dynamic>>[
        {
          'label': 'Phantom Capable',
          'value': _traitPercent(
            female['A'],
            male['A'],
            trigger: 'at',
          ),
          'icon': Icons.pets,
        },
        {
          'label': 'Tan Points',
          'value': _traitPercent(
            female['A'],
            male['A'],
            trigger: 'at',
          ),
          'icon': Icons.pets,
        },
        {
          'label': 'Ky Carrier',
          'value': _traitPercent(
            female['K'],
            male['K'],
            trigger: 'ky',
          ),
          'icon': Icons.circle,
        },
        {
          'label': 'Parti Carrier',
          'value': _traitPercent(
            female['S'],
            male['S'],
            trigger: 's',
          ),
          'icon': Icons.circle,
        },
        {
          'label': 'Chocolate Carrier',
          'value': _traitPercent(
            female['B'],
            male['B'],
            trigger: 'b',
          ),
          'icon': Icons.circle,
        },
        {
          'label': 'Dilute Carrier',
          'value': _traitPercent(
            female['D'],
            male['D'],
            trigger: 'd',
          ),
          'icon': Icons.circle,
        },
        {
          'label': 'Merle Carrier',
          'value': _traitPercent(
            female['M'],
            male['M'],
            trigger: 'M',
          ),
          'icon': Icons.circle,
        },
      ];

      traits.sort(
        (a, b) => (b['value'] as double)
            .compareTo(a['value'] as double),
      );

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "🧬 Traits (List with Progress)",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 16),

              ...traits.map((trait) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _traitRow(
                    label: trait['label'],
                    value: trait['value'],
                    icon: trait['icon'],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      );
    }
/// 
    double _traitPercent(
      String? female,
      String? male, {
      required String trigger,
    }) {
      if (female == null || male == null) return 0;

      int score = 0;

      if (female.contains(trigger)) score += 50;
      if (male.contains(trigger)) score += 50;

      return score.toDouble();
    }
  //-------
    Widget _traitRow({
      required String label,
      required double value,
      required IconData icon,
    }) {
      return Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: Colors.grey.shade700,
          ),

          const SizedBox(width: 12),

          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: value / 100,
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
              ),
            ),
          ),

          const SizedBox(width: 12),

          SizedBox(
            width: 45,
            child: Text(
              "${value.toInt()}%",
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }
/// 
  Widget _comparisonHeader() {
    return const Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            'Test',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'Female',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'Male',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _comparisonRow(String label, String femaleValue, String maleValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label),
          ),
          Expanded(
            flex: 2,
            child: Text(
              femaleValue,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              maleValue,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _rowKey(Map<String, dynamic> row, bool isHealth) {
    if (isHealth) {
      return (row['test_name'] ?? row['name'] ?? '').toString();
    }

    return (row['locus'] ?? row['test_name'] ?? '').toString();
  }

  Map<String, dynamic>? _findRow(
    List<Map<String, dynamic>> rows,
    String key,
    bool isHealth,
  ) {
    for (final row in rows) {
      if (_rowKey(row, isHealth) == key) return row;
    }
    return null;
  }

  String _displayValue(Map<String, dynamic>? row, bool isHealth) {
    if (row == null) return '-';

    if (isHealth) {
      return (row['result'] ?? '-').toString();
    }

    final a1 = row['allele_1'];
    final a2 = row['allele_2'];
    final genotype = row['genotype'];

    if (genotype != null && genotype.toString().trim().isNotEmpty) {
      return genotype.toString();
    }

    if (a1 != null || a2 != null) {
      return '${a1 ?? '-'} / ${a2 ?? '-'}';
    }

    return (row['result'] ?? '-').toString();
  }
}