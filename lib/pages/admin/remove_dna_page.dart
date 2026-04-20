import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RemoveDNAPage extends StatefulWidget {
  const RemoveDNAPage({super.key});

  @override
  State<RemoveDNAPage> createState() => _RemoveDNAPageState();
}

class _RemoveDNAPageState extends State<RemoveDNAPage> {
  final supabase = Supabase.instance.client;

  final TextEditingController alaController = TextEditingController();

  Map<String, dynamic>? dog;
  bool loading = false;
  bool deleting = false;

  // =========================
  // 🔍 LOOKUP DOG
  // =========================
  Future<void> _lookupDog() async {
    setState(() {
      loading = true;
      dog = null;
    });

    final ala = alaController.text.trim();

    final res = await supabase
        .from('dogs')
        .select()
        .eq('dog_ala', ala)
        .maybeSingle();

    setState(() {
      dog = res;
      loading = false;
    });
  }

  // =========================
  // ❌ REMOVE DNA
  // =========================
  Future<void> _removeDNA() async {
    if (dog == null) return;

    final dogId = dog!['id'];

    print("Deleting DNA for dog: $dogId"); // 👈 MOVE HERE

    setState(() => deleting = true);

    try {
      // 1️⃣ Get all reports (for file paths)
      final reports = await supabase
          .from('dna_reports')
          .select()
          .eq('dog_id', dogId);

      // 2️⃣ Delete storage files
      for (final r in reports) {
        final url = r['report_url'] as String?;

        if (url != null && url.contains('/dog_files/')) {
          final path = url.split('/dog_files/').last;

          await supabase.storage.from('dog_files').remove([path]);
        }
      }
      // Add count check
      final resultCount = await supabase
          .from('dna_results')
          .select('id')
          .eq('dog_id', dogId);

      print("DNA results count: ${resultCount.length}");


      // 3️⃣ Delete DB records
      // 🔥 DELETE ALL DNA TABLES (NEW STRUCTURE)
    await supabase.from('dna_bank').delete().eq('dog_id', dogId);
    final check = await supabase
        .from('dna_bank')
        .select()
        .eq('dog_id', dogId);

    print("AFTER DELETE dna_bank COUNT: ${check.length}");
    await supabase.from('dna_health').delete().eq('dog_id', dogId);
    await supabase.from('dna_summary').delete().eq('dog_id', dogId);

    // optional (keep if still used)
    await supabase.from('dna_reports').delete().eq('dog_id', dogId);

    // 🔥 REMOVE OLD TABLE COMPLETELY (if exists)
    await supabase.from('dna_results').delete().eq('dog_id', dogId);

      // 4️⃣ Reset flag
      await supabase.from('dogs').update({
        'has_dna_summary': false,
        // future-proof 👇
        // 'has_trait_certificate': false,
        // 'has_manual_dna': false,
      }).eq('id', dogId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🧬 DNA fully removed (all sources)'),
            backgroundColor: Colors.orange,
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Remove DNA error: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    if (mounted) setState(() => deleting = false);
  }

  // =========================
  // UI
  // =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Remove DNA")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Enter Dog ALA",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: alaController,
              decoration: const InputDecoration(
                labelText: "dog_ala",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: loading ? null : _lookupDog,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text("Find Dog"),
            ),

            const SizedBox(height: 24),

            if (dog != null) ...[
              Card(
                child: ListTile(
                  title: Text(dog!['dog_name'] ?? 'Unknown'),
                  subtitle: Text(dog!['dog_ala'] ?? ''),
                ),
              ),

              const SizedBox(height: 16),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: deleting ? null : _confirmDelete,
                child: deleting
                    ? const CircularProgressIndicator()
                    : const Text("Remove DNA"),
              ),
            ],

            if (!loading && dog == null && alaController.text.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  "Dog not found",
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // =========================
  // CONFIRM DIALOG
  // =========================

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm"),
        content: Text(
          "Remove DNA for ${dog!['dog_name']}?\n\nThis cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _removeDNA();

    }
  }
}