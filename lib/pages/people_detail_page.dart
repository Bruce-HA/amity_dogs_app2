import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dog_details_page.dart';

class PeopleDetailPage extends StatefulWidget {
  final String personId;

  const PeopleDetailPage({
    super.key,
    required this.personId,
  });

  @override
  State<PeopleDetailPage> createState() => _PeopleDetailPageState();
}

class _PeopleDetailPageState extends State<PeopleDetailPage> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? person;
  List<Map<String, dynamic>> dogs = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final personResponse = await supabase
        .from('people')
        .select()
        .eq('people_id', widget.personId)
        .single();

    final dogResponse = await supabase
        .from('dogs')
        .select('id, dog_name, dog_ala, pet_name, dog_status')
        .eq('owner_person_id', widget.personId);

    if (!mounted) return;

    setState(() {
      person = personResponse;
      dogs = List<Map<String, dynamic>>.from(dogResponse);
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Owner Details")),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Owner Details")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${person?['first_name_1st'] ?? ''} '
              '${person?['last_name_1st'] ?? ''}',
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              "Dogs",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (dogs.isEmpty)
              const Text("No dogs linked.")
            else
              Expanded(
                child: ListView.builder(
                  itemCount: dogs.length,
                  itemBuilder: (context, index) {
                    final dog = dogs[index];

                    return Card(
                      child: ListTile(
                        title: Text(dog['dog_name'] ?? ''),
                        subtitle: Text(
                          '${dog['dog_ala']} • ${dog['pet_name'] ?? ''} • ${dog['dog_status'] ?? ''}',
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DogDetailsPage(dogId: dog['id']),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}