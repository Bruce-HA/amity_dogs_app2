import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pages/dog_details_page.dart';
import 'dog_create_page.dart';

import 'widgets/dog_list_card.dart';
import '../ui/spacing.dart';
class DogsPage extends StatefulWidget {
  const DogsPage({super.key});

  @override
  State<DogsPage> createState() => _DogsPageState();
}

class _DogsPageState extends State<DogsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _debounce;

  final int _limit = 25;
  int _offset = 0;

  bool _isLoading = false;
  bool _hasMore = true;
  bool _initialLoad = true;

  bool _myDogsOnly = false;
  bool _spayPendingOnly = true;
  String? _selectedStatus;

  String? _myPeopleId;

  List<Map<String, dynamic>> _dogs = [];

  final List<String> _statuses = [
    'Pet',
    'Active',
    'Pending',
    'Guardian',
    'Retired',
    'Deceased',
    'For Sale',
    'Sold',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUserPeopleId();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _fetchDogs();
    }
  }

  Future<void> _loadCurrentUserPeopleId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final profile = await _supabase
        .from('profiles')
        .select('people_id')
        .eq('user_id', user.id)
        .single();

    _myPeopleId = profile['people_id'];
    _fetchDogs(reset: true);
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchDogs(reset: true);
    });
  }

  Future<void> _fetchDogs({bool reset = false}) async {
    if (_isLoading || _myPeopleId == null) return;

    setState(() {
      _isLoading = true;
      if (reset) {
        _offset = 0;
        _hasMore = true;
        _dogs.clear();
        _initialLoad = true;
      }
    });

    try {
      final search = _searchController.text.trim();

      var query = _supabase.from('dogs_list_view').select('''
        id,
        dog_name,
        dog_ala,
        microchip,
        status,
        spay_due,
        my_dogs,
        dob,
        age_months,
        hero_image_url,
        owner:people!owner_person_id (
          people_id,
          first_name_1st,
          last_name_1st,
          phone_1st
        ),
        breeder:people!breeder_person_id (
          people_id,
          first_name_1st,
          last_name_1st,
          phone_1st
        )
      ''');

      if (_myDogsOnly) {
        query = query.eq('my_dogs', true);
      }

      if (_selectedStatus != null) {
        query = query.eq('status', _selectedStatus!);
      }

      if (_spayPendingOnly) {
        query = query.not('spay_due', 'is', null);
      }

      if (search.isNotEmpty) {
        query = query.or(
          'dog_name.ilike.%$search%,dog_ala.ilike.%$search%,microchip.ilike.%$search%',
        );
      }

      final response = await query
          .order('age_months', ascending: true)
          .range(_offset, _offset + _limit - 1);

      final results = List<Map<String, dynamic>>.from(response);

      setState(() {
        _dogs.addAll(results);
        _offset += _limit;
        _hasMore = results.length == _limit;
        _initialLoad = false;
      });
    } catch (e) {
      debugPrint('Error fetching dogs: $e');
    }

    setState(() => _isLoading = false);
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔍 FILTER ROW
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSegmentChip(
                  label: 'My Dogs',
                  selected: _myDogsOnly,
                  onTap: () {
                    setState(() => _myDogsOnly = !_myDogsOnly);
                    _fetchDogs(reset: true);
                  },
                ),

                const SizedBox(width: 8),

                _buildSegmentChip(
                  label: 'Spay Pending',
                  selected: _spayPendingOnly,
                  onTap: () {
                    setState(() => _spayPendingOnly = !_spayPendingOnly);
                    _fetchDogs(reset: true);
                  },
                ),

                const SizedBox(width: 8),

                _buildStatusDropdown(),
                
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDogTile(Map<String, dynamic> dog) {
    final imageUrl = dog['hero_image_url'];

    final safeUrl = (imageUrl != null &&
            imageUrl.toString().startsWith('http'))
        ? imageUrl
        : null;

    final owner = dog['owner'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DogDetailsPage(dogId: dog['id']),
            ),
          );
          _fetchDogs(reset: true);
        },
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: safeUrl != null
                  ? Image.network(
                      safeUrl,
                      width: 95,
                      height: 95,
                      fit: BoxFit.cover,
                    )
                  : _placeholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dog['dog_name'] ?? ''),
                  Text(dog['dog_ala'] ?? ''),
                  Text('Status: ${dog['status'] ?? ''}'),
                  if (owner != null)
                    Text(
                      'Owner: ${owner['first_name_1st']} ${owner['last_name_1st']}',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 95,
      height: 95,
      color: Colors.grey.shade300,
      child: const Icon(Icons.pets),
    );
  }
///
  Widget _buildSegmentChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.black87,
          ),
        ),
      ),
    );
  }
///////
  Widget _buildStatusDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButton<String>(
        value: _selectedStatus ?? 'All',
        underline: const SizedBox(),
        borderRadius: BorderRadius.circular(12),
        items: [
          const DropdownMenuItem(value: 'All', child: Text('All')),
          ..._statuses.map(
            (s) => DropdownMenuItem(value: s, child: Text(s)),
          ),
        ],
        onChanged: (value) {
          setState(() {
            _selectedStatus = value == 'All' ? null : value;
          });
          _fetchDogs(reset: true);
        },
      ),
    );
  }
///
///
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dogs')),
      body: Column(
        children: [
          Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search dogs...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        //. text field
         _buildFilters(),

        Expanded(
          child: ListView.separated(
            padding: AppSpacing.screenPadding,
            itemCount: _dogs.length,
            separatorBuilder: (_, __) => AppSpacing.hLg,
            itemBuilder: (context, index) {
              final dog = _dogs[index];

              return DogListCard(
                dog: dog,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DogDetailsPage(dogId: dog['id']),
                    ),
                  );
                },
              );
            },
          ),
        ),
          // ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const DogCreatePage(),
            ),
          );
          _fetchDogs(reset: true);
        },
      ),
    );
  }
}