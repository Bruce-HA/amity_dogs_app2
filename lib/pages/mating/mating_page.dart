import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MatingPage extends StatefulWidget {
  final String matingId;

  const MatingPage({super.key, required this.matingId});

  @override
  State<MatingPage> createState() => _MatingPageState();
}

class _MatingPageState extends State<MatingPage> {
  Map<String, dynamic>? mating;

  @override
  void initState() {
    super.initState();
    _loadMating();
  }

  Future<void> _loadMating() async {
    final supabase = Supabase.instance.client;

    final data = await supabase
        .from('matings')
        .select()
        .eq('id', widget.matingId)
        .single();

    setState(() {
      mating = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (mating == null) {
      return Scaffold(
        appBar: AppBar(title: Text("Mating")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(mating!['mating_code'] ?? "Mating"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🐶 Dogs Row (placeholder)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(mating!['female_dog_ala'] ?? ""),
                Icon(Icons.favorite, color: Colors.red),
                Text(mating!['male_dog_ala'] ?? ""),
              ],
            ),

            SizedBox(height: 20),

            // 📅 Key Dates (placeholder)
            Text("Cycle Start: --"),
            Text("Ovulation: --"),

            SizedBox(height: 20),

            // 📜 Timeline placeholder
            Expanded(
              child: Center(
                child: Text("Timeline coming next…"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}