import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import '../pages/dog_details_page.dart';

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
    loadSpayDates();
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
        child: SingleChildScrollView(
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

                eventLoader: getEventsForDay,
              ),

              const Divider(),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: todaysEvents.length,
                itemBuilder: (context, index) {

                  final event = todaysEvents[index];

                  return ListTile(
                    leading: const Icon(Icons.pets),
                    title: Text(event['title']),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DogDetailsPage(
                            dogId: event['dog_id'],
                          ),
                        ),
                      );
                    },
                  );;
                },
              ),

            ],
          ),
        ),
      )
    );
  }
}