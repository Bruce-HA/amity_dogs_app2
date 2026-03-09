import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'people_detail_page.dart';

class PeoplePage extends StatefulWidget {
  const PeoplePage({super.key});

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> people = [];
  bool loading = true;
  String search = '';

  @override
  void initState() {
    super.initState();
    loadPeople();
  }

  Future<void> loadPeople() async {
    final response = await supabase.rpc(
      'search_people_dogs',
      params: {'search_text': search.isEmpty ? null : search},
    );

    if (!mounted) return;

    setState(() {
      people = List<Map<String, dynamic>>.from(response);
      loading = false;
    });
  }

  void onSearchChanged(String value) {
    search = value;
    loadPeople();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("People")),
      body: Column(
        children: [

          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: "Search dogs, owners, microchip...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          if (loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: people.length,
                itemBuilder: (context, index) {
                  final person = people[index];

                  final name =
                      '${person['first_name_1st']} ${person['last_name_1st']}';

                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(name),
                    subtitle: Row(
                      children: [
                        Chip(
                          label:
                              Text('${person['dog_count']} dogs'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            person['email_1st'] ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PeopleDetailPage(
                            personId: person['people_id'],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}