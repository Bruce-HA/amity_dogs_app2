import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'litter_detail_page.dart';

class LittersPage extends StatefulWidget {
  final String? dogId;

  const LittersPage({
    super.key,
    this.dogId,
  });

  @override
  State<LittersPage> createState() => _LittersPageState();
}

class _LittersPageState extends State<LittersPage> {
  final supabase = Supabase.instance.client;

  List litters = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadLitters();
  }

  Future<void> loadLitters() async {
    List data = [];

    if (widget.dogId != null) {
      // 🔥 Get dog ALA
      final dog = await supabase
          .from('dogs')
          .select('dog_ala')
          .eq('id', widget.dogId!)
          .maybeSingle();

      if (dog == null) return;

      final dogAla = dog['dog_ala'];

      // 🔥 Get litters for this dog
      final damLitters = await supabase
          .from('litters')
          .select('id, litter_name, whelp_date, dam_ala, sire_ala, created_at')
          .eq('dam_ala', dogAla);

      final sireLitters = await supabase
          .from('litters')
          .select('id, litter_name, whelp_date, dam_ala, sire_ala, created_at')
          .eq('sire_ala', dogAla);

      data = [
        ...damLitters as List,
        ...sireLitters as List,
      ];
    } else {
      // 🔥 Dashboard → all litters
      data = await supabase
          .from('litters')
          .select('id, litter_name, whelp_date, dam_ala, sire_ala, created_at')
          .order('whelp_date', ascending: false);
    }

    // 🔥 Sort newest first
    data.sort((a, b) {
      final aDate = a['whelp_date'] ?? a['created_at'] ?? '';
      final bDate = b['whelp_date'] ?? b['created_at'] ?? '';
      return bDate.toString().compareTo(aDate.toString());
    });

    setState(() {
      litters = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Litters'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : litters.isEmpty
              ? const Center(child: Text('No litters found'))
              : ListView.builder(
                  itemCount: litters.length,
                  itemBuilder: (context, index) {
                    final litter = litters[index];

                    return TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 300),
                      tween: Tween(begin: 0.95, end: 1),
                      curve: Curves.easeOut,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: child,
                        );
                      },
                      child: Card(
                        elevation: 3,
                        shadowColor: Colors.black12,
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text(
                            litter['litter_name'] ?? 'Unnamed Litter',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${litter['dam_ala']} × ${litter['sire_ala']}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _statusBadge(litter),
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LitterDetailPage(litter: litter),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
Widget _statusBadge(Map litter) {
  final isMating = litter['whelp_date'] == null;

  return AnimatedContainer(
    duration: const Duration(milliseconds: 400),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: isMating ? Colors.orange.shade100 : Colors.green.shade100,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      isMating ? 'Mating' : 'Litter',
      style: TextStyle(
        color: isMating ? Colors.orange.shade800 : Colors.green.shade800,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    ),
  );
}