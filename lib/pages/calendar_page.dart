import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import '../pages/dog_details_page.dart';
import '../pages/flow/flow_detail_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {

  final supabase = Supabase.instance.client;

  CalendarFormat calendarFormat = CalendarFormat.month;

  DateTime focusedDay = DateTime.now();
  DateTime? selectedDay;

  Map<DateTime, List<Map>> events = {};

  @override
  void initState() {
    super.initState();
    loadAllEvents();
  }

  Future<void> loadSpayDates() async {

    final dogs = await supabase
        .from('dogs')
        .select('id, dog_name, spay_due')
        .not('spay_due', 'is', null);

    Map<DateTime, List<Map>> map = {};

    for (var dog in dogs) {

    final raw = dog['spay_due'];

    if (raw == null || raw.toString().trim().isEmpty || raw == "NULL") {
      continue;
    }

    DateTime date;

    try {
      date = raw is DateTime ? raw : DateTime.parse(raw.toString());
    } catch (e) {
      print("Invalid date: $raw");
      continue;
    }

    final key = DateTime.utc(date.year, date.month, date.day);

    map.putIfAbsent(key, () => []);

    map[key]!.add({
      "title": "${dog['dog_name']} spay due",
      "dog_id": dog['id']
      
    });
  }

   //. for debug.  print("Loaded events: $map");

    setState(() {
      events = map;
    });
  }

  Future<void> loadAllEvents() async {

    Map<DateTime, List<Map>> map = {};

    // ==============================
    // EXISTING: SPAY DATES
    // ==============================

    final dogs = await supabase
        .from('dogs')
        .select('id, dog_name, spay_due')
        .not('spay_due', 'is', null);

    for (var dog in dogs) {

      final raw = dog['spay_due'];

      if (raw == null || raw.toString().trim().isEmpty || raw == "NULL") {
        continue;
      }

      DateTime date;

      try {
        date = raw is DateTime ? raw : DateTime.parse(raw.toString());
      } catch (_) {
        continue;
      }

      final key = DateTime.utc(date.year, date.month, date.day);

      map.putIfAbsent(key, () => []);

      map[key]!.add({
        "title": "${dog['dog_name']} spay due",
        "type": "spay",
        "dog_id": dog['id'],
        "colour_key": dog['id'],
      });
    }

    // ==============================
    // NEW: FLOW TASKS
    // ==============================

    final tasks = await supabase
      .from('flow_tasks')
      .select('''
        task_title,
        task_type,
        due_date,
        completed,
        flow_id,
        breeding_flows (
          flow_name,
          flow_code
        )
      ''')
      .not('due_date', 'is', null);

  for (var task in tasks) {
    final raw = task['due_date'];
    if (raw == null) continue;

    DateTime date;

    try {
      date = raw is DateTime ? raw : DateTime.parse(raw.toString());
    } catch (_) {
      continue;
    }

    final flow = task['breeding_flows'] as Map<String, dynamic>?;
    final litterName =
        flow?['flow_name']?.toString().trim().isNotEmpty == true
            ? flow!['flow_name'].toString()
            : flow?['flow_code']?.toString() ?? 'Flow';

    final key = DateTime.utc(date.year, date.month, date.day);

    map.putIfAbsent(key, () => []);

    map[key]!.add({
      "title": '${task['task_title']} — $litterName',
      "type": task['task_type'],
      "flow_id": task['flow_id'],
      "litter_name": litterName,
      "completed": task['completed'] == true,
      "colour_key": litterName,
    });
  }

    setState(() {
      events = map;
    });
  }

  List<dynamic> getEventsForDay(DateTime day) {
    final key = DateTime.utc(day.year, day.month, day.day);
    return events[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {

    final todaysEvents = getEventsForDay(selectedDay ?? focusedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Calendar"),
      ),
      body: SafeArea(
      child: RefreshIndicator(
        onRefresh: loadAllEvents,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [

              TableCalendar(
                firstDay: DateTime.utc(2020),
                lastDay: DateTime.utc(2035),
                focusedDay: focusedDay,

                calendarFormat: calendarFormat,

                availableCalendarFormats: const {
                  CalendarFormat.month: 'Month',
                },

                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                ),

                calendarStyle: const CalendarStyle(
                  markerSize: 8,
                  markersMaxCount: 3,
                  markerDecoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),

                onFormatChanged: (format) {
                  setState(() {
                    calendarFormat = format;
                  });
                },

                selectedDayPredicate: (day) {
                  return isSameDay(selectedDay, day);
                },

                onDaySelected: (selected, focused) {
                  setState(() {
                    selectedDay = selected;
                    focusedDay = focused;
                  });
                },
                calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, dayEvents) {
                  if (dayEvents.isEmpty) return const SizedBox.shrink();

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: dayEvents.take(4).map((event) {
                      final mapEvent = event as Map;
                      return Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: _colourForEvent(mapEvent),
                          shape: BoxShape.circle,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
                eventLoader: getEventsForDay,
              ),

              const Divider(),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: todaysEvents.length,
                itemBuilder: (context, index) {

                  final event = todaysEvents[index];

                  final eventColour = _colourForEvent(event);

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: eventColour.withOpacity(0.12),
                      border: Border.all(
                        color: eventColour,
                        width: 1.4,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: eventColour,
                        child: Icon(
                          _iconForEvent(event['type']),
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        event['title'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: event['completed'] == true
                              ? TextDecoration.lineThrough
                              : null,
                          color: event['completed'] == true
                              ? Colors.grey
                              : null,
                        ),
                      ),
                      subtitle: event['litter_name'] == null
                          ? null
                          : Text(event['litter_name']),
                      trailing: event['completed'] == true
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      onTap: () {
                        if (event['dog_id'] != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DogDetailsPage(
                                dogId: event['dog_id'],
                              ),
                            ),
                          );
                        } else if (event['flow_id'] != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FlowDetailPage(
                                flowId: event['flow_id'],
                              ),
                            ),
                          ).then((_) => loadAllEvents());
                        }
                      },
                    ),
                  );
                },
              ),

            ],
          ),
        ),
      )
      ),
    );
  }
  IconData _iconForEvent(String? type) {
    switch (type) {
      case 'drontal':
        return Icons.medication;
      case 'baycox':
        return Icons.science;
      case 'nail_trimming':
        return Icons.content_cut;
      case 'ens':
        return Icons.psychology;
      case 'photo_reminder':
        return Icons.camera_alt;
      case 'vet_booking':
        return Icons.local_hospital;
      case 'spay':
        return Icons.pets;
      default:
        return Icons.event;
    }
  }

  Color _colourForEvent(Map event) {
    // Completed = grey
    if (event['completed'] == true) {
      return Colors.grey;
    }

    // 🔴 Spay = high visibility yellow
    if (event['type'] == 'spay') {
      return Colors.amber.shade600;
    }

    // Default: colour per litter/flow
    final key = event['colour_key']?.toString() ??
        event['litter_name']?.toString() ??
        event['flow_id']?.toString() ??
        event['dog_id']?.toString() ??
        event['type']?.toString() ??
        '';

    final colours = [
      Colors.teal,
      Colors.deepPurple,
      Colors.orange,
      Colors.blue,
      Colors.pink,
      Colors.green,
      Colors.indigo,
      Colors.brown,
    ];

    final index = key.hashCode.abs() % colours.length;
    return colours[index];
  }
  
}