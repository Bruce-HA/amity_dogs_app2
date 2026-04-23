import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pages/dog_details_page.dart';
import 'dog_create_page.dart';
import 'widgets/dog_list_card.dart';
import '../ui/spacing.dart';
import 'widgets/app_dog_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _spayPendingOnly = false;
  String? _selectedStatus;

  String? _myPeopleId;

  List<Map<String, dynamic>> _dogs = [];

  final List<String> _filters = [
    'All',
    'My Dogs',
    'Spay Pending',
    'Breeding',
    'Active',
    'Pending',
    'Guardian',
    'Pet',
    'Retired',
    'For Sale',
    'Deceased',
  ];

  // ONLY showing CHANGED / FIXED parts to keep this clean

@override
  void initState() {
    super.initState();
    _loadCurrentUserPeopleId();
    _scrollController.addListener(_scrollListener); // ✅ FIX
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

    setState(() {
      _myPeopleId = profile['people_id'];
      _initialLoad = false; // ✅ FIX
    });

    _fetchDogs(reset: true);

  }

  void _onSearchChanged(String value) {
    _debounce = Timer(const Duration(milliseconds: 300), () {

      _fetchDogs(reset: true);
    });
  }

  Future<void> _fetchDogs({bool reset = false}) async {
    if (_isLoading) return;
    if (_myPeopleId == null) return;

    setState(() {
      _isLoading = true;
      if (reset) {
        _offset = 0;
        _hasMore = true;
        _dogs.clear();
      }
    });

    try {
      final search = _searchController.text.trim();

      var query = _supabase
          .from('dogs_list_view_with_hero')
          .select('''
            id,
            dog_name,
            dog_ala,
            sex,
            microchip,
            status,
            spay_due,
            my_dogs,
            dob,
            hero
          ''');

      if (_myDogsOnly) {
        query = query.eq('my_dogs', true);
      }

      if (_spayPendingOnly) {
        query = query.not('spay_due', 'is', null);
      }

      if (_selectedStatus != null) {
        query = query.eq('status', _selectedStatus!);
      }

      if (search.isNotEmpty) {
        final s = search.replaceAll("'", "''");
        query = query.or(
          'dog_name.ilike.%$s%,dog_ala.ilike.%$s%,microchip.ilike.%$s%',
        );
      }

      final shouldSortBySpay =
        _spayPendingOnly;

      final response = await (shouldSortBySpay
          ? query.order('spay_due', ascending: true)
          : query.order('dob', ascending: false))
          .range(_offset, _offset + _limit - 1);

      setState(() {
        _dogs = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching dogs: $e');
      setState(() => _isLoading = false);
    }
  }


  Widget _buildFilterDropdown() {
    return DropdownButton<String>(
      value: _selectedStatus ?? 'All',
      items: _filters.map((filter) {
        return DropdownMenuItem(
          value: filter,
          child: Text(filter),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _myDogsOnly = false;
          _spayPendingOnly = false;
          _selectedStatus = null;

          if (value == 'My Dogs') {
            _myDogsOnly = true;
          } else if (value == 'Spay Pending') {
            _spayPendingOnly = true;
          } else if (value != 'All') {
            _selectedStatus = value;
          }
        });

        _fetchDogs(reset: true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dogs')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'Search dogs...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                _buildFilterDropdown(),
              ],
            ),
          ),
          Expanded(
            child: _dogs.isEmpty
                ? const Center(
                    child: Text("This will open on the last viewed dog."),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _dogs.length,
                    itemBuilder: (context, index) {
                      final dog = _dogs[index];

                      return DogListCard(
                        dog: dog,
                        onTap: () async {
                          await _saveLastViewedDog(dog['id']);

                          final refreshed = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DogDetailsPage(dogId: dog['id']),
                            ),
                          );

                          if (refreshed == true) {
                            _fetchDogs(reset: true);
                          }
                        },
                      );
                    },
                  ),
          ),
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

/*
  =============================
  Open Last Viewed
  =============================
  */

  Future<void> _saveLastViewedDog(String dogId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_viewed_dog_id', dogId);
  }

  Future<void> _openLastViewedDog() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDogId = prefs.getString('last_viewed_dog_id');

    if (lastDogId == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final refreshed = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DogDetailsPage(dogId: lastDogId),
        ),
      );

      if (refreshed == true) {
        _fetchDogs(reset: true);
        _openLastViewedDog();
      }
    });
  }
}