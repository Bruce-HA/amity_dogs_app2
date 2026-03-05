import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PeoplePage extends StatefulWidget {
  const PeoplePage({super.key});

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  final supabase = Supabase.instance.client;

  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = loadPeople();
  }

  Future<List<Map<String, dynamic>>> loadPeople() async {
    final response = await supabase
        .from('people')
        .select()
        .order('last_name_1st');

    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,

        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final people = snapshot.data!;

          return ListView.builder(
            itemCount: people.length,

            itemBuilder: (context, index) {
              final person = people[index];

              final name =
                  '${person['first_name_1st'] ?? ''} '
                  '${person['last_name_1st'] ?? ''}';

              return ListTile(
                leading: const Icon(Icons.person),

                title: Text(name),

                subtitle: Text(person['email_1st'] ?? ''),
              );
            },
          );
        },
      ),
    );
  }
}
