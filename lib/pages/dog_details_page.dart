import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/date_utils.dart';
import '../tabs/dog_breeding_tab.dart';
import '../tabs/dog_photos_tab.dart';
import '../tabs/dog_files_tab.dart';
import '../tabs/dog_notes_tab.dart';
import '../tabs/genetics_tab.dart';
import 'dog_edit_page.dart';
import 'people_detail_page.dart';
import 'widgets/dog_card.dart';
import '../ui/spay_due_label.dart';
import '../../dev/dev_info_panel.dart';
import 'dna/dna_input_page.dart';

class DogDetailsPage extends StatefulWidget {
  final String dogId;

  const DogDetailsPage({
    super.key,
    required this.dogId,
  });

  @override
  State<DogDetailsPage> createState() => _DogDetailsPageState();
}

class _DogDetailsPageState extends State<DogDetailsPage> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? dog;
  Map<String, dynamic>? breeder;
  Map<String, dynamic>? owner;
  Map<String, dynamic>? mother;
  Map<String, dynamic>? father;

  String? heroUrl;

  int selectedTab = 0;

  int litterCount = 0;
  int puppyCount = 0;
  int maleCount = 0;
  int femaleCount = 0;

  bool _didChangeDog = false;

  List<String> getTabs() {
    if (dog == null) return [];

    final status = dog!['status']?.toString().toLowerCase();

    final tabs = [
      'Overview',
      'Photos',
      'Genetics',
      'Notes',
      'Files',
    ];

    if (status != 'pet') {
      tabs.insert(3, 'Breeding');
    }

    return tabs;
  }

  @override
  void initState() {
    super.initState();
    loadDog();
  }

  Future<void> loadDog() async {
    final dogResult = await supabase
        .from('dogs_with_hero')
        .select()
        .eq('id', widget.dogId)
        .maybeSingle();

    if (dogResult == null) return;

    String? newHeroUrl = dogResult['hero']?.toString();

    if (newHeroUrl == null || newHeroUrl.isEmpty) {
      final photos = await supabase
          .from('dog_photos')
          .select('url, is_hero')
          .eq('dog_id', widget.dogId);

      if (photos.isNotEmpty) {
        final hero = photos.firstWhere(
          (p) => p['is_hero'] == true,
          orElse: () => photos.first,
        );
        newHeroUrl = hero['url'];
      }
    }

    breeder = null;
    owner = null;
    mother = null;
    father = null;

    if (dogResult['breeder_person_id'] != null) {
      breeder = await supabase
          .from('people')
          .select()
          .eq('people_id', dogResult['breeder_person_id'])
          .maybeSingle();
    }

    if (dogResult['owner_person_id'] != null) {
      owner = await supabase
          .from('people')
          .select()
          .eq('people_id', dogResult['owner_person_id'])
          .maybeSingle();
    }

    if (dogResult['mother_ala'] != null) {
      final motherRes = await supabase
          .from('dogs_with_hero')
          .select()
          .eq('dog_ala', dogResult['mother_ala']);

      if (motherRes.isNotEmpty) mother = motherRes.first;
    }

    if (dogResult['father_ala'] != null) {
      final fatherRes = await supabase
          .from('dogs_with_hero')
          .select()
          .eq('dog_ala', dogResult['father_ala']);

      if (fatherRes.isNotEmpty) father = fatherRes.first;
    }

    setState(() {
      dog = dogResult;
      heroUrl = newHeroUrl;
    });

    await loadLitters();
  }

  Future<void> loadLitters() async {
    final dogAla = dog?['dog_ala'];
    if (dogAla == null) return;

    final pups = await supabase
        .from('dogs')
        .select('dog_ala, sex')
        .or('mother_ala.eq.$dogAla,father_ala.eq.$dogAla');

    final data = pups as List;

    int m = 0;
    int f = 0;
    final Set<String> litterSet = {};

    for (var pup in data) {
      final ala = pup['dog_ala']?.toString();
      final sexRaw = pup['sex']?.toString().toLowerCase();

      if (sexRaw != null) {
        if (sexRaw.startsWith('m')) m++;
        if (sexRaw.startsWith('f')) f++;
      }

      if (ala != null) {
        final parts = ala.split('-');
        if (parts.length >= 2) {
          litterSet.add('${parts[0]}-${parts[1]}');
        }
      }
    }

    if (!mounted) return;

    setState(() {
      litterCount = litterSet.length;
      maleCount = m;
      femaleCount = f;
      puppyCount = m + f;
    });
  }

  String _displayValue(dynamic value, {String fallback = '—'}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    if (text.isEmpty) return fallback;
    return text;
  }

  bool get _isPet {
    final status = dog?['status']?.toString().toLowerCase();
    return status == 'pet';
  }

  String _fullPersonName(Map<String, dynamic>? person) {
    if (person == null) return '';

    final first = person['first_name_1st']?.toString().trim() ?? '';
    final last = person['last_name_1st']?.toString().trim() ?? '';

    return '$first $last'.trim();
  }

  String? _resolvedHeroUrl() {
    final url = heroUrl;
    final dogAla = dog?['dog_ala'];

    if (url == null || url.isEmpty || dogAla == null) return null;

    if (url.startsWith('http')) return url;

    return supabase.storage
        .from('dog_files')
        .getPublicUrl('$dogAla/photos/$url');
  }

  Widget _placeholderHero() {
    return Image.asset(
      'assets/images/no_photo.png',
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.6),
    );
  }

  Widget _buildHeroImage() {
    final finalUrl = _resolvedHeroUrl();

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        height: 145,
        width: double.infinity,
        color: Colors.grey.shade200,
        child: finalUrl == null
            ? _placeholderHero()
            : Image.network(
                finalUrl,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.45),
                errorBuilder: (_, __, ___) => _placeholderHero(),
              ),
      ),
    );
  }

  Widget _buildDnaStatusBadge() {
    final hasDna = dog?['has_dna_summary'] == true;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () async {
        final updated = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DnaInputPage(
              dogId: widget.dogId,
              dogName: dog?['dog_name'],
            ),
          ),
        );

        if (updated == true) {
          _didChangeDog = true;
          await loadDog();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: hasDna ? Colors.green.shade50 : Colors.red.shade50,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: hasDna ? Colors.green.shade300 : Colors.red.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.biotech,
              size: 17,
              color: hasDna ? Colors.green.shade700 : Colors.red.shade700,
            ),
            const SizedBox(width: 6),
            Text(
              hasDna ? 'DNA Uploaded' : 'DNA Missing',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: hasDna ? Colors.green.shade800 : Colors.red.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final d = dog!;
    final name = _displayValue(d['dog_name'], fallback: 'Unnamed Dog');
    final ala = _displayValue(d['dog_ala']);
    final status = _displayValue(d['status']);
    final sex = _displayValue(d['sex']);
    final colour = _displayValue(d['colour']);
    final dob = d['dob'] != null ? calculateDogAge(d['dob'].toString()) : null;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF5B2EFF),
            Color(0xFF7B4DFF),
            Color(0xFF9C6BFF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(34),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _roundHeaderButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.pop(context, _didChangeDog),
                  ),
                  const Spacer(),
                  _roundHeaderButton(
                    icon: Icons.edit,
                    onTap: _openEditPage,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildHeroImage(),
              const SizedBox(height: 18),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                ala,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.82),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
        /*      const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _headerChip(status, Icons.flag),
                  _headerChip(sex, Icons.pets),
                  _headerChip(colour, Icons.palette),
                  if (dob != null && dob.isNotEmpty) _headerChip(dob, Icons.cake),
                ],
              ),
              if (!_isPet) ...[
                const SizedBox(height: 12),
                _buildDnaStatusBadge(),
              ],
  
              if (d['spay_due'] != null) ...[
                const SizedBox(height: 12),
                SpayDueLabel(spayDue: d['spay_due']),
              ],

          */    
            ],
          ),
        ),
      ),
    );
  }
//. moving the buttons
  Widget _buildScrollableBadges() {
    final d = dog!;
    final status = _displayValue(d['status']);
    final sex = _displayValue(d['sex']);
    final colour = _displayValue(d['colour']);
    final dob = d['dob'] != null ? calculateDogAge(d['dob'].toString()) : null;

    return Container(
      color: const Color(0xFFF5F7FB),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _softChip(status, Icons.flag),
              _softChip(sex, Icons.pets),
              _softChip(colour, Icons.palette),
              if (dob != null && dob.isNotEmpty) _softChip(dob, Icons.cake),
            ],
          ),

          if (!_isPet) ...[
            const SizedBox(height: 10),
            _buildDnaStatusBadge(),
          ],

          if (d['spay_due'] != null) ...[
            const SizedBox(height: 10),
            _softSpayChip(d['spay_due']),
          ],
        ],
      ),
    );
  }

  Widget _softChip(String label, IconData icon) {
    if (label == '—') return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF7B4DFF)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF4A4A4A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _softSpayChip(dynamic spayDue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Text(
        'Spay Due: $spayDue',
        style: const TextStyle(
          color: Color(0xFFE65100),
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _roundHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _headerChip(String label, IconData icon) {
    if (label == '—') return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditPage() async {
    if (dog == null) return;

    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DogEditPage(dog: dog!),
      ),
    );

    if (updated == true) {
      _didChangeDog = true;
      await loadDog();
    }
  }

  IconData getTabIcon(String tab) {
    switch (tab) {
      case 'Overview':
        return Icons.dashboard;
      case 'Photos':
        return Icons.photo;
      case 'Breeding':
        return Icons.pets;
      case 'Genetics':
        return Icons.biotech;
      case 'Notes':
        return Icons.note;
      case 'Files':
        return Icons.folder;
      default:
        return Icons.circle;
    }
  }

  Widget buildTabs() {
    final tabs = getTabs();

    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isSelected = selectedTab == index;

          return GestureDetector(
            onTap: () => setState(() => selectedTab = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF7B4DFF) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF7B4DFF)
                      : Colors.grey.shade300,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF7B4DFF).withOpacity(0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    getTabIcon(tab),
                    size: 16,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tab,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildTabContent() {
    final tabs = getTabs();

    if (tabs.isEmpty || selectedTab >= tabs.length) {
      return const SizedBox();
    }

    final tab = tabs[selectedTab];

    switch (tab) {
      case 'Overview':
        return _buildOverviewContent();

      case 'Photos':
        return DogPhotosTab(
          dogId: widget.dogId,
          dogAla: dog!['dog_ala'],
          onHeroChanged: () async {
            _didChangeDog = true;
            await loadDog();
          },
        );

      case 'Genetics':
        return GeneticsTab(dogId: widget.dogId);

      case 'Breeding':
        return DogBreedingTab(dogId: widget.dogId);

      case 'Notes':
        return DogNotesTab(dogId: widget.dogId);

      case 'Files':
        return DogFilesTab(
          dogId: widget.dogId,
          dogAla: dog!['dog_ala'],
        );

      default:
        return const SizedBox();
    }
  }

  Widget _buildOverviewContent() {
    final d = dog;

    if (d == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _statsRow(),
          const SizedBox(height: 14),
          _peopleSection(d),
          const SizedBox(height: 14),
          _quickInfoSection(d),
          if (!_isPet) ...[
            const SizedBox(height: 14),
            _breedingOverviewSection(d),
            const SizedBox(height: 14),
            _geneticsHealthSection(d),
          ],
          const SizedBox(height: 14),
          _identificationSection(d),
          if (mother != null || father != null) ...[
            const SizedBox(height: 14),
            _parentsSection(),
          ],
        ],
      ),
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Litters',
            value: litterCount.toString(),
            icon: Icons.favorite,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Pups',
            value: puppyCount.toString(),
            icon: Icons.pets,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Male',
            value: maleCount.toString(),
            icon: Icons.male,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Female',
            value: femaleCount.toString(),
            icon: Icons.female,
          ),
        ),
      ],
    );
  }

  Widget _peopleSection(Map<String, dynamic> d) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: (breeder != null || d['breeder_name'] != null)
              ? _PersonCard(
                  title: 'Breeder',
                  primary: breeder != null
                      ? _fullPersonName(breeder)
                      : _displayValue(d['breeder_name']),
                  secondary: breeder != null
                      ? _displayValue(breeder!['phone_1st'], fallback: '')
                      : _displayValue(d['breeder_kennel'], fallback: ''),
                  icon: Icons.pets,
                  onTap: () => _openPerson(breeder, d['breeder_name']),
                )
              : const SizedBox(),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: (owner != null || d['owner_name'] != null)
              ? _PersonCard(
                  title: 'Owner',
                  primary: owner != null
                      ? _fullPersonName(owner)
                      : _displayValue(d['owner_name']),
                  secondary: owner != null
                      ? _displayValue(owner!['phone_1st'], fallback: '')
                      : _displayValue(d['owner_kennel'], fallback: ''),
                  icon: Icons.person,
                  onTap: () => _openPerson(owner, d['owner_name']),
                )
              : const SizedBox(),
        ),
      ],
    );
  }

  Future<void> _openPerson(
    Map<String, dynamic>? linkedPerson,
    dynamic fallbackName,
  ) async {
    if (linkedPerson != null && linkedPerson['people_id'] != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PeopleDetailPage(
            personId: linkedPerson['people_id'],
          ),
        ),
      );
      return;
    }

    final name = fallbackName?.toString().trim();
    if (name == null || name.isEmpty) return;

    final res = await supabase
        .from('people')
        .select()
        .or('first_name_1st.ilike.%$name%,last_name_1st.ilike.%$name%')
        .limit(1)
        .maybeSingle();

    if (res != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PeopleDetailPage(personId: res['people_id']),
        ),
      );
    }
  }

  Widget _quickInfoSection(Map<String, dynamic> d) {
    return _SectionCard(
      title: 'Snapshot',
      icon: Icons.info_outline,
      children: [
        _infoRow('Status', d['status']),
        _infoRow('Sex', d['sex']),
        _infoRow('Colour', d['colour']),
        _infoRow('ALA Grade', d['ala_grade']),
        _infoRow('Size', d['size'] ?? d['zooeasy_raw']?['size']),
        _infoRow('Coat', d['coat_type'] ?? d['coat']),
      ],
    );
  }

  Widget _breedingOverviewSection(Map<String, dynamic> d) {
    return _SectionCard(
      title: 'Breeding Overview',
      icon: Icons.auto_graph,
      children: [
        _infoRow('Breed %', d['breed_percentage'] ?? d['zooeasy_raw']?['breed_percentage']),
        _infoRow('Inbreeding', d['inbreeding_coefficient'] ?? d['zooeasy_raw']?['inbreeding']),
        _infoRow('AVK', d['avk'] ?? d['zooeasy_raw']?['avk']),
        _infoRow('ECG', d['ecg'] ?? d['zooeasy_raw']?['ecg']),
        _infoRow('Generations', d['complete_generations'] ?? d['zooeasy_raw']?['complete_generations']),
        _infoRow('Litters as sire', d['litter_count_as_sire']),
        _infoRow('Litters as dam', d['litter_count_as_dam']),
      ],
    );
  }

  Widget _geneticsHealthSection(Map<String, dynamic> d) {
    return _SectionCard(
      title: 'Genetics & Health',
      icon: Icons.biotech,
      children: [
        _infoRow('DNA Result', d['dna_result']),
        _infoRow('Colour DNA', d['colour_dna']),
        _infoRow('PRA', d['pra_status'] ?? d['pra']),
        _infoRow('DMA', d['dma_status'] ?? d['dma']),
        _infoRow('Hip Score', d['hip_score']),
        _infoRow('Elbows', d['elbow_score'] ?? d['elbows']),
        _infoRow('PennHip', d['pennhip']),
        _infoRow('Weight', d['weight']),
      ],
    );
  }

  Widget _identificationSection(Map<String, dynamic> d) {
    return _SectionCard(
      title: 'Identification',
      icon: Icons.badge_outlined,
      children: [
        _infoRow('Dog ALA', d['dog_ala']),
        _infoRow('Microchip', d['microchip']),
        _infoRow('DOB', d['dob']),
        _infoRow('Mother ALA', d['mother_ala']),
        _infoRow('Father ALA', d['father_ala']),
      ],
    );
  }

  Widget _parentsSection() {
    return _SectionCard(
      title: 'Parents',
      icon: Icons.family_restroom,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: mother != null
                  ? DogCard(
                      dog: mother!,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DogDetailsPage(dogId: mother!['id']),
                          ),
                        );
                      },
                    )
                  : const SizedBox(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: father != null
                  ? DogCard(
                      dog: father!,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DogDetailsPage(dogId: father!['id']),
                          ),
                        );
                      },
                    )
                  : const SizedBox(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoRow(String label, dynamic value) {
    final text = _displayValue(value, fallback: '');
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (dog == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FB),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Column(
      children: [
        _buildHeader(),

        Expanded(
          child: selectedTab == 0
              ? ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildScrollableBadges(),
                    const SizedBox(height: 10),
                    buildTabs(),
                    const SizedBox(height: 8),
                    buildTabContent(),
                  ],
                )
              : Column(
                  children: [
                    _buildScrollableBadges(),
                    const SizedBox(height: 10),
                    buildTabs(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: buildTabContent(),
                    ),
                  ],
                ),
        ),
      ],
    ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final String title;
  final String primary;
  final String secondary;
  final IconData icon;
  final VoidCallback onTap;

  const _PersonCard({
    required this.title,
    required this.primary,
    required this.secondary,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF7B4DFF).withOpacity(0.10),
                  child: Icon(
                    icon,
                    size: 17,
                    color: const Color(0xFF7B4DFF),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              primary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (secondary.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                secondary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF7B4DFF),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B4DFF).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: const Color(0xFF7B4DFF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}