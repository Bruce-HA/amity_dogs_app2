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
  final TextEditingController alaController = TextEditingController();

  Map<String, dynamic>? masterPerson;
  List<Map<String, dynamic>> duplicates = [];

  bool loading = false;
  bool previewLoaded = false;

  int previewDogsTotal = 0;
  int previewDogsOwner = 0;
  int previewDogsBreeder = 0;
  int previewNotes = 0;
  int previewFiles = 0;
  int previewRoles = 0;

  /// 🔥 ALA TOOL
  String? alaPrefixInput;
  int alaPreviewCount = 0;
  bool alaLoading = false;

  /// 🔍 SCAN USAGE
  Future<void> scanUsage() async {
    if (duplicates.isEmpty) return;

    final ids = duplicates.map((e) => e['people_id']).toList();

    setState(() {
      loading = true;
      previewLoaded = false;
    });

    try {
      final dogs = await supabase
          .from('dogs')
          .select()
          .or(
            'owner_person_id.in.(${ids.join(',')}),'
            'breeder_person_id.in.(${ids.join(',')})',
          );

      final notes = await supabase
          .from('people_notes')
          .select()
          .inFilter('people_id', ids.cast<String>());

      final files = await supabase
          .from('people_files')
          .select()
          .inFilter('people_id', ids.cast<String>());

      final roles = await supabase
          .from('people_roles')
          .select()
          .inFilter('people_id', ids.cast<String>());

      setState(() {
        previewDogsTotal = dogs.length;

        previewDogsOwner = dogs
            .where((d) => ids.contains(d['owner_person_id']))
            .length;

        previewDogsBreeder = dogs
            .where((d) => ids.contains(d['breeder_person_id']))
            .length;

        previewNotes = notes.length;
        previewFiles = files.length;
        previewRoles = roles.length;

        previewLoaded = true;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Scan failed ❌: $e")),
      );
    }
  }

  /// ➕ ADD DUPLICATE
  void addDuplicate(Map<String, dynamic> person) {
    final id = person['people_id'];

    if (masterPerson != null && masterPerson!['people_id'] == id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot add master as duplicate")),
      );
      return;
    }

    final exists = duplicates.any((p) => p['people_id'] == id);
    if (exists) return;

    setState(() {
      duplicates.add(person);
    });
  }

  void removeDuplicate(String id) {
    setState(() {
      duplicates.removeWhere((p) => p['people_id'] == id);
    });
  }

  /// 🔀 MERGE
  Future<void> mergePeople() async {
    if (masterPerson == null || duplicates.isEmpty) return;

    final masterId = masterPerson!['people_id'];
    final duplicateIds =
        duplicates.map((e) => e['people_id']).toList();

    setState(() => loading = true);

    try {
      /// UPDATE REFERENCES
      await supabase
          .from('dogs')
          .update({'breeder_person_id': masterId})
          .inFilter('breeder_person_id', duplicateIds.cast<String>());

      await supabase
          .from('dogs')
          .update({'owner_person_id': masterId})
          .inFilter('owner_person_id', duplicateIds.cast<String>());

      await supabase
          .from('people_notes')
          .update({'people_id': masterId})
          .inFilter('people_id', duplicateIds.cast<String>());

      await supabase
          .from('people_files')
          .update({'people_id': masterId})
          .inFilter('people_id', duplicateIds.cast<String>());

      await supabase
          .from('people_roles')
          .update({'people_id': masterId})
          .inFilter('people_id', duplicateIds.cast<String>());

      /// SAFETY CHECK
      final ownerCheck = await supabase
          .from('dogs')
          .select('id')
          .inFilter('owner_person_id', duplicateIds.cast<String>());

      final breederCheck = await supabase
          .from('dogs')
          .select('id')
          .inFilter('breeder_person_id', duplicateIds.cast<String>());

      if (ownerCheck.isNotEmpty || breederCheck.isNotEmpty) {
        throw Exception("References still exist — merge blocked");
      }

      /// FIX FLAGS
      final allIds = [masterId, ...duplicateIds];

      final peopleData = await supabase
          .from('people')
          .select('is_breeder, is_owner')
          .inFilter('people_id', allIds.cast<String>());

      bool isBreeder = false;
      bool isOwner = false;

      for (final p in peopleData) {
        if (p['is_breeder'] == true) isBreeder = true;
        if (p['is_owner'] == true) isOwner = true;
      }

      await supabase.from('people').update({
        'is_breeder': isBreeder,
        'is_owner': isOwner,
      }).eq('people_id', masterId);

      /// DELETE DUPLICATES
      await supabase
          .from('people')
          .delete()
          .inFilter('people_id', duplicateIds.cast<String>());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Merge complete ✅")),
      );

      resetAll();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Merge failed: $e")),
      );
    }

    setState(() => loading = false);
  }

  /// 🔥 ALA PREVIEW
  Future<void> previewAlaFix() async {
    if (alaPrefixInput == null || masterPerson == null) return;

    setState(() => alaLoading = true);

    final res = await supabase
        .from('dogs')
        .select()
        .eq('ala_breeder', alaPrefixInput!);

    setState(() {
      alaPreviewCount = res.length;
      alaLoading = false;
    });
  }

  /// 🔥 APPLY ALA FIX
  Future<void> applyAlaFix() async {
    if (alaPrefixInput == null || masterPerson == null) return;

    final masterId = masterPerson!['people_id'];

    setState(() => alaLoading = true);

    await supabase
        .from('dogs')
        .update({'breeder_person_id': masterId})
        .eq('ala_breeder', alaPrefixInput!);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("ALA Fix applied ✅")),
    );

    setState(() => alaLoading = false);
  }

  void resetAll() {
    setState(() {
      masterPerson = null;
      duplicates.clear();
      previewLoaded = false;
      /// 🔥 ALA RESET
      alaPrefixInput = null;
      alaPreviewCount = 0;
      alaController.clear();
    });
  }

  String label(Map<String, dynamic> p) {
    return p['business_name'] ??
        "${p['first_name_1st'] ?? ''} ${p['last_name_1st'] ?? ''}";
  }

  @override
  Widget build(BuildContext context) {
    final canScan = masterPerson != null && duplicates.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('🛠 Data Tools')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(
            title: "Golden Record",
            child: PersonPicker(
              label: 'Select Master',
              useBusinessName: true,
              selectedPerson: masterPerson,
              onSelected: (p) => setState(() => masterPerson = p),
            ),
          ),

          const SizedBox(height: 16),

          _sectionCard(
            title: "Duplicates (${duplicates.length})",
            child: Column(
              children: [
                PersonPicker(
                  label: 'Add Duplicate',
                  useBusinessName: true,
                  selectedPerson: null,
                  onSelected: addDuplicate,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: duplicates.map((p) {
                    return Chip(
                      label: Text(label(p)),
                      onDeleted: () =>
                          removeDuplicate(p['people_id']),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          ElevatedButton(
            onPressed: canScan ? scanUsage : null,
            child: const Text("Scan Usage"),
          ),

          if (previewLoaded)
            _sectionCard(
              title: "Preview",
              child: Column(
                children: [
                  _row("Dogs (Owner)", previewDogsOwner),
                  _row("Dogs (Breeder)", previewDogsBreeder),
                  _row("Dogs (Unique)", previewDogsTotal),
                  const Divider(),
                  _row("Notes", previewNotes),
                  _row("Files", previewFiles),
                  _row("Roles", previewRoles),
                ],
              ),
            ),

          if (canScan)
            ElevatedButton(
              onPressed: loading ? null : mergePeople,
              child: const Text("Merge"),
            ),

          /// 🔥 ALA TOOL
          const SizedBox(height: 20),

          _sectionCard(
            title: "ALA Breeder Fix",
            child: Column(
              children: [
                TextField(
                  controller: alaController,
                  decoration:
                      const InputDecoration(labelText: "ALA Prefix"),
                  onChanged: (v) => alaPrefixInput = v,
                ),
                ElevatedButton(
                  onPressed: previewAlaFix,
                  child: const Text("Preview"),
                ),
                if (alaPreviewCount > 0)
                  Text("Dogs affected: $alaPreviewCount"),
                ElevatedButton(
                  onPressed: applyAlaFix,
                  child: const Text("Apply Fix"),
                ),
              ],
            ),
          ),

          ElevatedButton(
            onPressed: resetAll,
            child: const Text("Reset"),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, int value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value.toString()),
      ],
    );
  }
}