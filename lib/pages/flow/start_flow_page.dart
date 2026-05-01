import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../ui/app_page_theme.dart';
import 'flow_detail_page.dart';

class StartFlowPage extends StatefulWidget {
  final Map<String, dynamic> femaleDog;
  final Map<String, dynamic> breedingPlan;
  final Map<String, dynamic>? maleDog;

  const StartFlowPage({
    super.key,
    required this.femaleDog,
    required this.breedingPlan,
    this.maleDog,
  });

  @override
  State<StartFlowPage> createState() => _StartFlowPageState();
}

class _StartFlowPageState extends State<StartFlowPage> {
  final supabase = Supabase.instance.client;

  DateTime? seasonStartDate;
  final notesController = TextEditingController();

  bool saving = false;

  static const flowTheme = AppPageThemes.flow;

  static Color get flowPrimary => flowTheme.primary;
  static Color get flowPrimaryDark => flowTheme.dark;

  String get femaleName =>
      widget.femaleDog['dog_name']?.toString() ??
      widget.femaleDog['name']?.toString() ??
      'Female';

  String get femaleAla => widget.femaleDog['dog_ala']?.toString() ?? '';

  String get maleName =>
      widget.maleDog?['pet_name']?.toString() ??
      widget.maleDog?['dog_name']?.toString() ??
      widget.maleDog?['name']?.toString() ??
      'Male';

  String get maleAla => widget.maleDog?['dog_ala']?.toString() ?? '';

  Future<void> pickSeasonDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: seasonStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() {
        seasonStartDate = picked;
      });
    }
  }

  String dateOnly(DateTime date) {
    return date.toIso8601String().split('T').first;
  }

  Future<String> buildMatingCode() async {
    final existing = await supabase
        .from('matings')
        .select('id')
        .eq('female_dog_ala', femaleAla);

    final nextNumber = (existing as List).length + 1;
    final padded = nextNumber.toString().padLeft(2, '0');

    return '$femaleAla-M$padded';
  }

  Future<String> buildFlowCode() async {
    final existing = await supabase
        .from('breeding_flows')
        .select('id')
        .eq('female_dog_ala', femaleAla);

    final nextNumber = (existing as List).length + 1;
    final padded = nextNumber.toString().padLeft(2, '0');

    return '$femaleAla-FLOW$padded';
  }

  Future<void> startFlow() async {
    if (seasonStartDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the season start date')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final matingCode = await buildMatingCode();

      final mating = await supabase.from('matings').insert({
        'mating_code': matingCode,
        'breeding_plan_id': widget.breedingPlan['id'],
        'female_dog_id': widget.femaleDog['id'],
        'male_dog_id': widget.maleDog?['id'],
        'female_dog_ala': femaleAla,
        'male_dog_ala': maleAla.isEmpty ? null : maleAla,
        'cycle_start_date': dateOnly(seasonStartDate!),
        'status': 'planned',
        'notes': notesController.text.trim(),
      }).select().single();

      final flowCode = await buildFlowCode();

      final flow = await supabase.from('breeding_flows').insert({
        'flow_code': flowCode,
        'flow_name': '$femaleName × $maleName',
        'female_dog_id': widget.femaleDog['id'],
        'male_dog_id': widget.maleDog?['id'],
        'breeding_plan_id': widget.breedingPlan['id'],
        'mating_id': mating['id'],
        'female_dog_ala': femaleAla,
        'male_dog_ala': maleAla.isEmpty ? null : maleAla,
        'season_start_date': dateOnly(seasonStartDate!),
        'status': 'in_season',
        'current_stage': 'Season',
        'notes': notesController.text.trim(),
      }).select().single();

      await createStarterTasks(flow['id'], mating['id']);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FlowDetailPage(flowId: flow['id']),
        ),
      );
    } catch (error) {
      setState(() => saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start The Flow: $error')),
      );
    }
  }

  Future<void> createStarterTasks(String flowId, String matingId) async {
    final start = seasonStartDate!;

    final tasks = [
      {
        'flow_id': flowId,
        'task_group': 'Season',
        'task_title': 'Day 1 of Cylce',
        'task_type': 'season_start',
        'due_date': dateOnly(start),
        'actual_date': dateOnly(start),
        'completed': true,
        'completed_at': DateTime.now().toIso8601String(),
        'source_table': 'matings',
        'source_id': matingId,
        'sort_order': 10,
      },
      {
        'flow_id': flowId,
        'task_group': 'Progesterone',
        'task_title': 'Progesterone 1 test',
        'task_type': 'progesterone',
        'due_date': dateOnly(start.add(const Duration(days: 7))),
        'source_table': 'mating_events',
        'sort_order': 20,
      },
      {
        'flow_id': flowId,
        'task_group': 'Progesterone',
        'task_title': 'Progesterone 2 test',
        'task_type': 'progesterone',
        'due_date': dateOnly(start.add(const Duration(days: 9))),
        'source_table': 'mating_events',
        'sort_order': 30,
      },
      {
        'flow_id': flowId,
        'task_group': 'Progesterone',
        'task_title': 'Progesterone 3 test',
        'task_type': 'progesterone',
        'due_date': dateOnly(start.add(const Duration(days: 11))),
        'source_table': 'mating_events',
        'sort_order': 40,
      },
      {
        'flow_id': flowId,
        'task_group': 'Progesterone',
        'task_title': 'Progesterone 4 test',
        'task_type': 'progesterone',
        'due_date': dateOnly(start.add(const Duration(days: 13))),
        'source_table': 'mating_events',
        'sort_order': 50,
      },
      {
        'flow_id': flowId,
        'task_group': 'Ovulation',
        'task_title': 'Enter ovulation date',
        'task_type': 'ovulation',
        'due_date': dateOnly(start.add(const Duration(days: 13))),
        'source_table': 'matings',
        'source_id': matingId,
        'sort_order': 60,
      },
      {
        'flow_id': flowId,
        'task_group': 'Mating',
        'task_title': 'Plan mating',
        'task_type': 'mating',
        'due_date': dateOnly(start.add(const Duration(days: 14))),
        'source_table': 'matings',
        'source_id': matingId,
        'sort_order': 70,
      },
    ];

    await supabase.from('flow_tasks').insert(tasks);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: flowPrimary,
        foregroundColor: Colors.white,
        title: const Text(
          'Start The Flow',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _header(),
          const SizedBox(height: 20),
          _infoCard(),
          const SizedBox(height: 20),
          _seasonDateCard(),
          const SizedBox(height: 20),
          TextField(
            controller: notesController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 26),
          ElevatedButton.icon(
            onPressed: saving ? null : startFlow,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.favorite),
            label: Text(saving ? 'Starting...' : 'Start The Flow'),
            style: ElevatedButton.styleFrom(
              backgroundColor: flowPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            flowPrimary,
            flowPrimaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 7),
            color: flowPrimary.withOpacity(0.25),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.route,
              size: 34,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'THE FLOW',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Start the live breeding workflow from this selected breeding plan.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _infoRow('Female', '$femaleName  $femaleAla'),
            const Divider(),
            _infoRow('Male', '$maleName  $maleAla'),
            const Divider(),
            _infoRow(
              'Breeding Plan',
              (
                widget.breedingPlan['breeding_plan_code'] ??
                widget.breedingPlan['plan_code'] ??
                widget.breedingPlan['breeding_code'] ??
                widget.breedingPlan['code'] ??
                widget.breedingPlan['id'] ??
                ''
              ).toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seasonDateCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        title: const Text(
          'Season Start Date',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          seasonStartDate == null
              ? 'Tap to select date'
              : dateOnly(seasonStartDate!),
        ),
        trailing: const Icon(Icons.calendar_month),
        onTap: pickSeasonDate,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}