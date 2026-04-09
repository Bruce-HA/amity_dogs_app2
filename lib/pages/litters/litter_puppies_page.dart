import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/app_title.dart';
import '../dog_details_page.dart';

class LitterPuppiesPage extends StatefulWidget {
  final Map litter;

  const LitterPuppiesPage({
    super.key,
    required this.litter,
  });

  @override
  State<LitterPuppiesPage> createState() => _LitterPuppiesPageState();
}

class _LitterPuppiesPageState extends State<LitterPuppiesPage> {
  final supabase = Supabase.instance.client;

  List puppies = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadPuppies();
  }

  Future<void> loadPuppies() async {
    final data = await supabase
      .from('dogs')
      .select(
          'id, dog_name, dog_ala, sex, colour, collar_colour, birth_weight, birth_time')
      .eq('litter_id', widget.litter['id'])
      .order('dog_ala', ascending: true); // 👈 THIS LINE

    setState(() {
      puppies = data as List;
      loading = false;
    });
  }

  Future<void> openDog(String id) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DogDetailsPage(dogId: id),
      ),
    );

    if (updated == true) {
      loadPuppies(); // 🔥 refresh after edit
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: buildTitle('Puppies', 'LitterPuppiesPage'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : puppies.isEmpty
              ? const Center(child: Text('No puppies found'))
              : ListView.builder(
                  itemCount: puppies.length,
                  itemBuilder: (context, index) {
                    final pup = puppies[index];

                    final name = pup['dog_name'] ?? '';
                    final collar = pup['collar_colour'] ?? 'No Collar';

                    final displayName = name.isNotEmpty
                        ? "$collar ($name)"
                        : collar;

                    return Card(
                      child: ListTile(
                        title: Text(displayName),
                        subtitle: Text(
                          '${pup['colour'] ?? ''} • ${pup['sex'] ?? ''}',
                        ),
                        onTap: () => openDog(pup['id']),
                      ),
                    );
                  },
                )
    );
  }
}