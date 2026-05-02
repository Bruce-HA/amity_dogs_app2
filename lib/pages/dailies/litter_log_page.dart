import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_log_modal.dart';

const dailyPrimary = Color(0xFFFF9800);
const dailyPrimaryDark = Color(0xFFF57C00);

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
  String? damName;

  List logs = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadLogs();
  }

  Future<void> loadLogs() async {
    final logsRes = await supabase
        .from('whelping_logs')
        .select()
        .eq('litter_id', widget.litter['id'])
        .order('event_time', ascending: false);

    final dogRes = await supabase
        .from('dogs_list_view_with_hero')
        .select('hero, dog_ala, dog_name')
        .eq('dog_ala', widget.litter['dam_ala'])
        .limit(1);

    String? hero;
    String? name;

    if (dogRes.isNotEmpty) {
      final dog = dogRes.first;

      final heroField = dog['hero'];
      if (heroField is List && heroField.isNotEmpty) {
        final item = heroField.first;
        if (item is Map) {
          final fileName = item['url'];
          final ala = dog['dog_ala'];

          if (fileName != null && ala != null) {
            hero = supabase.storage
                .from('dog_files')
                .getPublicUrl('$ala/photos/$fileName');
          }
        }
      }

      name = dog['dog_name'];
    }

    setState(() {
      logs = logsRes;
      heroImage = hero;
      damName = name;
      loading = false;
    });
  }

  LogCategory getCategory(String? value) {
    switch (value) {
      case 'mum feed':
        return const LogCategory('Mum', Icons.child_care, Colors.blue);
      case 'pup feed':
        return const LogCategory('Pup', Icons.pets, Colors.teal);
      case 'toilet':
        return const LogCategory('Toilet', Icons.water_drop, Colors.brown);
      case 'medication':
        return const LogCategory('Meds', Icons.medication, Colors.red);
      default:
        return const LogCategory('Other', Icons.notes, Colors.grey);
    }
  }

  Widget quickChip(String category) {
    final cat = getCategory(category);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: GestureDetector(
          onTap: () async {
            await showAddLogModal(
              context,
              widget.litter,
              initialCategory: category,
            );
            loadLogs();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: dailyPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: dailyPrimary.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Icon(cat.icon, color: cat.color, size: 20),
                const SizedBox(height: 4),
                Text(cat.label,
                    style: TextStyle(
                        fontSize: 12,
                        color: dailyPrimary,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget filterChip() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: GestureDetector(
          onTap: () async {
            final selected = await showModalBottomSheet<String>(
              context: context,
              builder: (_) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('All'),
                      onTap: () => Navigator.pop(context, 'all'),
                    ),
                    ListTile(
                      title: const Text('Mum'),
                      onTap: () => Navigator.pop(context, 'mum feed'),
                    ),
                    ListTile(
                      title: const Text('Pup'),
                      onTap: () => Navigator.pop(context, 'pup feed'),
                    ),
                    ListTile(
                      title: const Text('Toilet'),
                      onTap: () => Navigator.pop(context, 'toilet'),
                    ),
                    ListTile(
                      title: const Text('Meds'),
                      onTap: () => Navigator.pop(context, 'medication'),
                    ),
                    ListTile(
                      title: const Text('Other'),
                      onTap: () => Navigator.pop(context, 'other'),
                    ),
                  ],
                );
              },
            );

            if (selected != null) {
              setState(() {
                selectedCategory = selected;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: const [
                Icon(Icons.filter_list, size: 20),
                SizedBox(height: 4),
                Text('Filter',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List get filteredLogs {
    if (selectedCategory == 'all') return logs;
    return logs.where((l) => l['category'] == selectedCategory).toList();
  }

  String formatDateTime(dynamic time) {
    final dt = DateTime.parse(time.toString()).toLocal();
    return "${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')} "
        "${dt.day}/${dt.month}";
  }

  @override
  Widget build(BuildContext context) {
    final litter = widget.litter;

    return Scaffold(
      appBar: AppBar(
        title: Text(litter['litter_full_code'] ?? ''),
        backgroundColor: dailyPrimary,
        foregroundColor: Colors.white,
        ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (heroImage != null)
                  Image.network(heroImage!, width: 100, height: 100),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(litter['short_litter_name'] ?? '',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      if (damName != null) Text(damName!),
                      Text(litter['ala_litter_number'] ?? ''),
                    ],
                  ),
                )
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                Row(children: [
                  quickChip('mum feed'),
                  quickChip('pup feed'),
                  quickChip('toilet')
                ]),
                Row(children: [
                  quickChip('medication'),
                  quickChip('other'),
                  filterChip()
                ]),
              ],
            ),
          ),

          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = filteredLogs[index];
                      final cat = getCategory(log['category']);

                      return ListTile(
                        leading: Icon(cat.icon, color: cat.color),

                        title: Text(log['note'] ?? ''),

                        subtitle: Text(
                          "${cat.label} • ${formatDateTime(log['event_time'])} • ${log['created_by_name'] ?? ''}",
                        ),

                        trailing: log['modified_at'] != null
                            ? const Icon(
                                Icons.edit,
                                size: 18,
                                color: Colors.grey,
                              )
                            : null,

                        onLongPress: () async {
                          await showEditLogModal(
                            context,
                            log,
                          );

                          loadLogs();
                        },
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }
}

class LogCategory {
  final String label;
  final IconData icon;
  final Color color;

  const LogCategory(this.label, this.icon, this.color);
}