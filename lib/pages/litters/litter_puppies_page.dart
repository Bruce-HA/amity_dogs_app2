import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/app_title.dart';
import '../dog_details_page.dart';
import 'puppy_create_page.dart';

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
        .from('dogs_list_view_with_hero')
        .select('id, dog_name, dog_ala, sex, collar_colour, hero')
        .eq('litter_id', widget.litter['id'])
        .order('dog_ala', ascending: true);

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
      loadPuppies();
    }
  }

  String buildPupTitle(Map pup) {
    final collar = pup['collar_colour'] ?? 'Unknown';
    final ala = pup['dog_ala'] ?? '';
    final sex = pup['sex'] ?? '';

    String pupNumber = '';
    if (ala.contains('-')) {
      pupNumber = ala.split('-').last.replaceFirst(RegExp(r'^0+'), '');
    }

    final sexShort = sex == 'Male'
        ? 'M'
        : sex == 'Female'
            ? 'F'
            : '';

    return '#$pupNumber $collar $sexShort';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
      title: buildTitle('Puppies', 'LitterPuppiesPage'),
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () async {
            final added = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PuppyCreatePage(
                  litter: Map<String, dynamic>.from(widget.litter),
                ),
              ),
            );

            if (added == true) {
              loadPuppies();
            }
          },
        ),
      ],
    ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : puppies.isEmpty
              ? const Center(child: Text('No puppies found'))
              : ListView.builder(
                  itemCount: puppies.length,
                  itemBuilder: (context, index) {
                    final pup = puppies[index];

                    /// 🔥 BUILD IMAGE URL (SAFE)
                    String? imageUrl;
                    final hero = pup['hero'];
                    final dogAla = pup['dog_ala'];

                    if (hero != null &&
                        hero.toString().isNotEmpty &&
                        dogAla != null) {
                      if (hero.toString().startsWith('http')) {
                        imageUrl = hero;
                      } else {
                        imageUrl = supabase.storage
                            .from('dog_files')
                            .getPublicUrl('$dogAla/photos/$hero');
                      }
                    }

                    return Card(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        onTap: () {
                          openDog(pup['id']);
                        },

                        /// 🖼 HERO IMAGE
                        leading: SizedBox(
                          width: 56,
                          height: 56,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: imageUrl != null
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                  )
                                : Image.asset(
                                    'assets/images/no_photo.png',
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),

                        /// 🐶 TITLE
                        title: Text(
                          buildPupTitle(pup),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        /// 🧾 SUBTITLE
                        subtitle: Text(
                          pup['dog_name'] ?? '',
                        ),

                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
    );
  }
}