import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reports/basic_pedigree_report_page.dart';
import 'dog_details_page.dart';
import 'tools/simple_pedigree_page.dart';
import 'tools/pregnancy_calculator_page.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController searchController = TextEditingController();

  bool isSearching = false;
  Map<String, dynamic>? selectedDog;
  List<Map<String, dynamic>> dogResults = [];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> searchDogs(String value) async {
    final search = value.trim();

    if (search.isEmpty) {
      setState(() {
        dogResults = [];
        selectedDog = null;
      });
      return;
    }

    setState(() => isSearching = true);

    try {
      final res = await supabase
          .from('dogs')
          .select(
            'id, dog_name, pet_name, dog_ala, sex, status, dob, colour, color, microchip',
          )
          .or(
            'dog_name.ilike.%$search%,'
            'pet_name.ilike.%$search%,'
            'dog_ala.ilike.%$search%,'
            'microchip.ilike.%$search%',
          )
          .order('dog_name', ascending: true)
          .limit(20);

      setState(() {
        dogResults = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      debugPrint('Reports dog search error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not search dogs: $e')),
      );
    }

    if (mounted) {
      setState(() => isSearching = false);
    }
  }

  String _dogTitle(Map<String, dynamic> dog) {
    final name = (dog['dog_name'] ?? '').toString().trim();
    final petName = (dog['pet_name'] ?? '').toString().trim();

    if (name.isNotEmpty && petName.isNotEmpty) {
      return '$name “$petName”';
    }

    if (name.isNotEmpty) return name;
    if (petName.isNotEmpty) return petName;

    return 'Unnamed Dog';
  }

  String _dogSubtitle(Map<String, dynamic> dog) {
    final ala = (dog['dog_ala'] ?? '').toString();
    final sex = (dog['sex'] ?? '').toString();
    final status = (dog['status'] ?? '').toString();

    return [
      if (ala.isNotEmpty) ala,
      if (sex.isNotEmpty) sex,
      if (status.isNotEmpty) status,
    ].join(' • ');
  }

  bool get _selectedDogIsActiveFemale {
    final dog = selectedDog;
    if (dog == null) return false;

    final status = (dog['status'] ?? '').toString().toLowerCase();
    final sex = (dog['sex'] ?? '').toString().toLowerCase();

    return status == 'active' && sex.startsWith('f');
  }

  void _selectDog(Map<String, dynamic> dog) {
    setState(() {
      selectedDog = dog;
      dogResults = [];
      searchController.text = _dogTitle(dog);
    });
  }

  void _openDogDetails() {
    final dog = selectedDog;
    if (dog == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DogDetailsPage(
          dogId: dog['id'].toString(),
        ),
      ),
    );
  }

  void _openSimplePedigree() {
    final dog = selectedDog;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SimplePedigreePage(
          initialDogAla: dog?['dog_ala']?.toString(),
        ),
      ),
    );
  }

  void _openBasicPedigree() {
    final dog = selectedDog;
    if (dog == null) {
      debugPrint('Basic Pedigree: no dog selected');
      return;
    }

    final dogAla = dog['dog_ala']?.toString().trim();

    if (dogAla == null || dogAla.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This dog has no ALA number, so pedigree cannot load.'),
        ),
      );
      return;
    }

    debugPrint('Opening Basic Pedigree for ALA: $dogAla');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BasicPedigreeReportPage(
          dogAla: dogAla,
        ),
      ),
    );
  }
  void _openPregnancyCalculator() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PregnancyCalculatorPage(),
      ),
    );
  }

  void _comingSoon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title is next to wire.'),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
    IconData? icon,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 22),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    return _sectionCard(
      title: 'Find Dog',
      icon: Icons.search,
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: searchDogs,
            decoration: const InputDecoration(
              labelText: 'Search dog',
              hintText: 'Dog name, pet name, ALA, or microchip',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),

          if (isSearching) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator()),
          ],

          if (!isSearching && dogResults.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...dogResults.map((dog) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.pets),
                  title: Text(_dogTitle(dog)),
                  subtitle: Text(_dogSubtitle(dog)),
                  onTap: () => _selectDog(dog),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedDogCard() {
    final dog = selectedDog;
    if (dog == null) {
      return _sectionCard(
        title: 'Selected Dog',
        icon: Icons.pets,
        child: const Text(
          'Search for a dog above to unlock report options.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    final colour = (dog['colour'] ?? dog['color'] ?? '').toString();
    final microchip = (dog['microchip'] ?? '').toString();

    return _sectionCard(
      title: 'Selected Dog',
      icon: Icons.check_circle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _dogTitle(dog),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(_dogSubtitle(dog)),
          if (colour.isNotEmpty) Text('Colour: $colour'),
          if (microchip.isNotEmpty) Text('Microchip: $microchip'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _openDogDetails,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Dog Details'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    final enabled = onPressed != null;
    final buttonColor = color ?? Colors.deepPurple;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        height: 72,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: enabled ? buttonColor : Colors.grey.shade400,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          onPressed: onPressed,
          child: Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportsCard() {
    final hasDog = selectedDog != null;

    return _sectionCard(
      title: 'Report Options',
      icon: Icons.description,
      child: Column(
        children: [
          _reportButton(
            title: 'Basic Pedigree',
            subtitle: 'One-page PedPro-style pedigree',
            icon: Icons.account_tree,
            color: Colors.indigo,
            onPressed: hasDog ? _openBasicPedigree : null,
          ),
          _reportButton(
            title: 'Advanced Pedigree',
            subtitle: 'Detailed pedigree, split over two pages',
            icon: Icons.schema,
            color: Colors.deepPurple,
            onPressed: hasDog
                ? () => _comingSoon('Advanced Pedigree')
                : null,
          ),
          _reportButton(
            title: 'Breeding Plan',
            subtitle: 'View, print, or add a breeding plan',
            icon: Icons.favorite,
            color: Colors.teal,
            onPressed: hasDog
                ? () => _comingSoon('Breeding Plan')
                : null,
          ),
          _reportButton(
            title: 'Pregnancy Calculator',
            subtitle: _selectedDogIsActiveFemale
                ? 'Calculate X-ray, due date, 6 and 8 week dates'
                : 'Available for active females',
            icon: Icons.calendar_month,
            color: Colors.orange,
            onPressed: _selectedDogIsActiveFemale
                ? _openPregnancyCalculator
                : null,
          ),
          _reportButton(
            title: 'Simple Pedigree Viewer',
            subtitle: 'Search and view generations interactively',
            icon: Icons.visibility,
            color: Colors.brown,
            onPressed: _openSimplePedigree,
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return _sectionCard(
      title: 'Report Build Notes',
      icon: Icons.info_outline,
      child: const Text(
        'Next stage: wire Basic Pedigree PDF, split Advanced Pedigree over two pages, '
        'and connect Breeding Plan to existing breeding plan data.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _buildSearchCard(),
          _buildSelectedDogCard(),
          _buildReportsCard(),
          _buildNotesCard(),
        ],
      ),
    );
  }
}