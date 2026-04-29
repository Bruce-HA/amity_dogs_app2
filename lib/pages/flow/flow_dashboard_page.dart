import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'flow_detail_page.dart';

class FlowDashboardPage extends StatefulWidget {
  const FlowDashboardPage({super.key});

  @override
  State<FlowDashboardPage> createState() => _FlowDashboardPageState();
}

class _FlowDashboardPageState extends State<FlowDashboardPage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  List<Map<String, dynamic>> tasks = [];
  String selectedFlowId = 'all';

  static const Color flowBackground = Color(0xFFFFF8EA);
  static const Color flowHeader = Color(0xFFF3DFC1);

  @override
  void initState() {
    super.initState();
    loadFlowTasks();
  }

  Future<void> loadFlowTasks() async {
  setState(() => loading = true);

  final data = await supabase
      .from('flow_tasks')
      .select('''
        id,
        flow_id,
        task_group,
        task_title,
        task_type,
        due_date,
        actual_date,
        is_booked,
        place,
        result,
        completed,
        completed_at,
        notes,
        sort_order,
        not_used,
        breeding_flows!inner (
          id,
          flow_code,
          flow_name,
          female_dog_ala,
          male_dog_ala,
          status,
          current_stage,
          archived
        )
      ''')
      .eq('breeding_flows.archived', false)
      .not(
        'breeding_flows.status',
        'in',
        '(completed,archived,cancelled,whelped,closed)',
      )
      .order('completed', ascending: true)
      .order('due_date', ascending: true)
      .order('sort_order', ascending: true);

      setState(() {
      tasks = List<Map<String, dynamic>>.from(data);
      loading = false;
    });
    }

  DateTime _todayOnly() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  List<Map<String, dynamic>> _tasksForBucket(String bucket) {
    final today = _todayOnly();
    final weekEnd = today.add(const Duration(days: 7));

    return tasks.where((task) {
      final flow = task['breeding_flows'] as Map<String, dynamic>?;
      final completed = task['completed'] == true;
      final notUsed = task['not_used'] == true;
      final dueDate = _parseDate(task['due_date']);

      if (selectedFlowId != 'all') {
        if (flow == null || flow['id'].toString() != selectedFlowId) {
          return false;
        }
      }

      if (notUsed) return false;

      if (bucket == 'COMPLETED') return completed;
      if (completed) return false;

      if (dueDate == null) {
        return bucket == 'UPCOMING';
      }

      final dueOnly = DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day,
      );

      if (bucket == 'OVERDUE') return dueOnly.isBefore(today);
      if (bucket == 'TODAY') return dueOnly.isAtSameMomentAs(today);

      if (bucket == 'THIS WEEK') {
        return dueOnly.isAfter(today) && dueOnly.isBefore(weekEnd);
      }

      if (bucket == 'UPCOMING') return dueOnly.isAfter(weekEnd);

      return false;
    }).toList();
  }

  Color _bucketColor(String bucket) {
    switch (bucket) {
      case 'OVERDUE':
        return Colors.red.shade50;
      case 'TODAY':
        return Colors.amber.shade50;
      case 'THIS WEEK':
        return const Color(0xFFFFF3DC);
      case 'UPCOMING':
        return Colors.grey.shade100;
      case 'COMPLETED':
        return Colors.green.shade50;
      default:
        return Colors.white;
    }
  }

  String _dueText(dynamic value, bool completed) {
    if (completed) return 'Completed';
    final due = _parseDate(value);
    if (due == null) return 'No date set';

    final today = _todayOnly();
    final dueOnly = DateTime(due.year, due.month, due.day);
    final diff = dueOnly.difference(today).inDays;

    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    if (diff < 0) return 'Overdue by ${diff.abs()} day${diff.abs() == 1 ? '' : 's'}';

    return 'Due in $diff days';
  }

  Future<void> toggleCompleted(Map<String, dynamic> task) async {
    final newValue = task['completed'] != true;

    await supabase.from('flow_tasks').update({
      'completed': newValue,
      'completed_at': newValue ? DateTime.now().toIso8601String() : null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', task['id']);

    await loadFlowTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: flowBackground,
      appBar: AppBar(
        backgroundColor: flowHeader,
        title: const Text(
          'The Flow',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadFlowTasks,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _headerCard(),
                  const SizedBox(height: 12),
                  _flowFilter(),
                  const SizedBox(height: 16),
                  _bucketSection('OVERDUE'),
                  _bucketSection('TODAY'),
                  _bucketSection('THIS WEEK'),
                  _bucketSection('UPCOMING'),
                  _bucketSection('COMPLETED'),
                ],
              ),
            ),
    );
  }
//. add filter
  Widget _flowFilter() {
    final flows = activeFlowOptions;

    if (flows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedFlowId,
            isExpanded: true,
            icon: const Icon(Icons.filter_list),
            items: [
              const DropdownMenuItem(
                value: 'all',
                child: Text('All Active Flows'),
              ),
              ...flows.map((flow) {
                return DropdownMenuItem(
                  value: flow['id'].toString(),
                  child: Text(_flowDisplayName(flow)),
                );
              }),
            ],
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                selectedFlowId = value;
              });
            },
          ),
        ),
      ),
    );
  }
///
  Widget _headerCard() {
    final activeFlows = tasks
        .map((t) => t['breeding_flows'])
        .where((f) => f != null)
        .map((f) => f['id'])
        .toSet()
        .length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: flowHeader,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, 3),
            color: Colors.black12,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.timeline, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'THE FLOW',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '$activeFlows active flow${activeFlows == 1 ? '' : 's'} being monitored',
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  ///
  String _flowDisplayName(Map<String, dynamic>? flow) {
  if (flow == null) return 'Flow';

  final name = flow['flow_name']?.toString().trim();

  if (name != null && name.isNotEmpty) {
    return name;
  }
  return flow['flow_code']?.toString() ?? 'Flow';
}
//. add filter
  List<Map<String, dynamic>> get activeFlowOptions {
    final seen = <String>{};
    final flows = <Map<String, dynamic>>[];

    for (final task in tasks) {
      final flow = task['breeding_flows'] as Map<String, dynamic>?;

      if (flow == null) continue;

      final id = flow['id']?.toString();
      if (id == null || seen.contains(id)) continue;

      seen.add(id);
      flows.add(flow);
    }

    flows.sort((a, b) {
      return _flowDisplayName(a).compareTo(_flowDisplayName(b));
    });

    return flows;
  }

  ////. correct date display
  String formatDisplayDate(dynamic value) {
    if (value == null) return 'No date set';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return 'No date set';

    return DateFormat('EEE dd-MM-yyyy').format(date);
  }
  ///
  Widget _bucketSection(String title) {
    final bucketTasks = _tasksForBucket(title);

    if (bucketTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ...bucketTasks.map((task) => _taskCard(task, title)),
        ],
      ),
    );
  }

  Widget _taskCard(Map<String, dynamic> task, String bucket) {
    final flow = task['breeding_flows'] as Map<String, dynamic>?;
    final completed = task['completed'] == true;

    return Card(
      color: _bucketColor(bucket),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: Checkbox(
          value: completed,
          onChanged: (_) => toggleCompleted(task),
        ),
  /// name
  /// 
        title: Text(
          task['task_title'] ?? '',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: completed ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _flowDisplayName(flow),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 8),

            if (flow != null)
              Text(
                '${flow['female_dog_ala'] ?? ''} × ${flow['male_dog_ala'] ?? ''}',
              ),

            Text(
              'Due: ${formatDisplayDate(task['due_date'])}',
            ),

            Text(
              _dueText(task['due_date'], completed),
            ),

            if ((task['place'] ?? '').toString().isNotEmpty)
              Text('Place: ${task['place']}'),

            if ((task['result'] ?? '').toString().isNotEmpty)
              Text('Result: ${task['result']}'),
          ],
        ),
      ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          if (flow == null) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FlowDetailPage(flowId: flow['id']),
            ),
          ).then((_) => loadFlowTasks());
        },
      ),
    );
  }
}