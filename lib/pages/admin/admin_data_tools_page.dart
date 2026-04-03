import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/person_picker.dart';

class AdminDataToolsPage extends StatefulWidget {
  const AdminDataToolsPage({super.key});

  @override
  State<AdminDataToolsPage> createState() => _AdminDataToolsPageState();
}

class _AdminDataToolsPageState extends State<AdminDataToolsPage> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? masterPerson;
  List<Map<String, dynamic>> duplicates = [];

  bool loading = false;

  int breederCount = 0;
  int ownerCount = 0;

  /// 🔍 SCAN USAGE
  Future<void> scanUsage() async {
    if (duplicates.isEmpty) return;

    setState(() => loading = true);

    final ids = duplicates.map((e) => e['people_id']).toList();

    final breederRes = await supabase
        .from('dogs')
        .select('id')
        .inFilter('breeder_person_id', ids);

    final ownerRes = await supabase
        .from('dogs')
        .select('id')
        .inFilter('owner_person_id', ids);

    setState(() {
      breederCount = breederRes.length;
      ownerCount = ownerRes.length;
      loading = false;
    });
  }

  /// ➕ ADD DUPLICATE
  void addDuplicate(Map<String, dynamic> person) {
    final exists =
        duplicates.any((p) => p['people_id'] == person['people_id']);

    if (!exists) {
      setState(() => duplicates.add(person));
    }
  }

  /// ❌ REMOVE DUPLICATE
  void removeDuplicate(String id) {
    setState(() {
      duplicates.removeWhere((p) => p['people_id'] == id);
    });
  }

  String label(Map<String, dynamic> p) {
    final business = p['business_name'] ?? '';
    if (business.toString().isNotEmpty) return business;

    return "${p['first_name_1st'] ?? ''} ${p['last_name_1st'] ?? ''}";
  }

  @override
  Widget build(BuildContext context) {
    final canScan = masterPerson != null && duplicates.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🛠 Data Tools'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// 🟢 MASTER CARD
          _sectionCard(
            title: "Golden Record",
            child: PersonPicker(
              label: 'Select Master Person',
              useBusinessName: true,
              selectedPerson: masterPerson,
              onSelected: (p) => setState(() => masterPerson = p),
            ),
          ),

          const SizedBox(height: 16),

          /// 🔴 DUPLICATES CARD
          _sectionCard(
            title: "Duplicate Records",
            child: Column(
              children: [
                PersonPicker(
                  label: 'Add Duplicate',
                  useBusinessName: true,
                  selectedPerson: null,
                  onSelected: addDuplicate,
                ),

                const SizedBox(height: 12),

                if (duplicates.isEmpty)
                  const Text(
                    "No duplicates added yet",
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  Wrap(
                    spacing: 8,
                    children: duplicates.map((p) {
                      return Chip(
                        label: Text(label(p)),
                        deleteIcon: const Icon(Icons.close),
                        onDeleted: () =>
                            removeDuplicate(p['people_id']),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          /// 🔍 ACTION CARD
          _sectionCard(
            title: "Actions",
            child: Column(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text("Scan Usage"),
                  onPressed: canScan ? scanUsage : null,
                ),
                const SizedBox(height: 8),
                Text(
                  canScan
                      ? "Find where these people are used"
                      : "Select master + duplicates first",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          /// 📊 RESULTS
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (breederCount > 0 || ownerCount > 0)
            _sectionCard(
              title: "Usage Results",
              child: Column(
                children: [
                  _resultRow("Dogs (Breeder)", breederCount),
                  const SizedBox(height: 8),
                  _resultRow("Dogs (Owner)", ownerCount),
                ],
              ),
            ),

          const SizedBox(height: 16),

          /// 🚧 MERGE COMING
          if (canScan)
            Card(
              color: Colors.orange.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "🚧 Merge button coming next step",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 🧱 UI HELPERS

  Widget _sectionCard({
    required String title,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, int value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}