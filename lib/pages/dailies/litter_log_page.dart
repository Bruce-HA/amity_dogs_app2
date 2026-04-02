import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'add_log_modal.dart';

final supabase = Supabase.instance.client;

class LitterLogPage extends StatefulWidget {
  final Map litter;

  const LitterLogPage({super.key, required this.litter});

  @override
  State<LitterLogPage> createState() => _LitterLogPageState();
}

class _LitterLogPageState extends State<LitterLogPage> {
  String selectedCategory = 'all';
  String? heroImage;
  List logs = [];
  bool loading = true;

  late RealtimeChannel channel;

  @override
  void initState() {
    super.initState();
    loadLogs();

    channel = supabase.channel('whelping_logs');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'whelping_logs',
      callback: (payload) {
        if (payload.newRecord['litter_id'] == widget.litter['id']) {
          loadLogs();
        }
      },
    ).subscribe();
  }

  @override
  void dispose() {
    channel.unsubscribe();
    super.dispose();
  }

  List get filteredLogs {
    if (selectedCategory == 'all') return logs;

    return logs.where((log) {
      return (log['category'] ?? '').toLowerCase() == selectedCategory;
    }).toList();
  }

  Future<void> loadLogs() async {
    final logsRes = await supabase
        .from('whelping_logs')
        .select()
        .eq('litter_id', widget.litter['id'])
        .order('event_time', ascending: false);

    // HERO IMAGE
    final dogRes = await supabase
        .from('dogs_list_view_with_hero')
        .select('hero, dog_ala')
        .eq('dog_ala', widget.litter['dam_ala'])
        .limit(1);

    String? hero;

    if (dogRes.isNotEmpty) {
      final dog = dogRes.first;
      final heroList = dog['hero'] as List?;

      if (heroList != null && heroList.isNotEmpty) {
        final heroItem = heroList.first;
        final fileName = heroItem['url'];
        final dogAla = dog['dog_ala'];

        if (fileName != null && dogAla != null) {
          hero = supabase.storage
              .from('dog_files')
              .getPublicUrl('$dogAla/photos/$fileName');
        }
      }
    }

    setState(() {
      logs = logsRes;
      heroImage = hero;
      loading = false;
    });
  }

  Color getCategoryColor(String? category) {
    switch (category) {
      case 'mum feed':
        return Colors.blue;
      case 'pup feed':
        return Colors.teal;
      case 'toilet':
        return Colors.brown;
      case 'medication':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget buildChip(String value, String label) {
    final isSelected = selectedCategory == value;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: GestureDetector(
          onTap: () => setState(() => selectedCategory = value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? getCategoryColor(value)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String formatDateTime(dynamic time) {
    final dt = DateTime.parse(time.toString()).toLocal();
    return "${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final litter = widget.litter;

    return Scaffold(
      appBar: AppBar(title: Text(litter['litter_full_code'] ?? '')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showAddLogModal(context, litter);
          loadLogs();
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // HEADER
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (heroImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      heroImage!,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        litter['short_litter_name'] ??
                            litter['litter_full_code'],
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        litter['ala_litter_number'] ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // FILTER CHIPS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    buildChip('all', 'All'),
                    buildChip('mum feed', 'Mum'),
                    buildChip('pup feed', 'Pup'),
                  ],
                ),
                Row(
                  children: [
                    buildChip('toilet', 'Toilet'),
                    buildChip('medication', 'Medication'),
                    buildChip('other', 'Other'),
                  ],
                ),
              ],
            ),
          ),

          // LOG LIST
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : (filteredLogs.isEmpty
                    ? const Center(child: Text("No logs yet"))
                    : ListView.builder(
                        itemCount: filteredLogs.length,
                        itemBuilder: (context, index) {
                          final log = filteredLogs[index];

                          return ListTile(
                            leading: Container(
                              width: 6,
                              height: 40,
                              color: getCategoryColor(log['category']),
                            ),
                            title: Text(log['note'] ?? ''),
                            subtitle: Text(
                              "${log['category']} • ${formatDateTime(log['event_time'])} • ${log['created_by_name'] ?? ''}",
                            ),
                          );
                        },
                      )),
          ),
        ],
      ),
    );
  }
}