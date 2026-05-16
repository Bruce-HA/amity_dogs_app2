import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dog_create_page.dart';
import 'dog_details_page.dart';
import 'widgets/dog_list_card.dart';

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

  bool _isLoading = false;
  bool _hasMore = true;
  bool _initialLoad = true;

  int _offset = 0;

  bool _myDogsOnly = false;
  bool _spayPendingOnly = false;

  String? _selectedStatus;
  String? _associationNumber;

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
    'For Sale',
    'Retired',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUserPeopleId();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 250 &&
        !_isLoading &&
        _hasMore) {
      _fetchDogs();
    }
  }

  Future<void> _loadCurrentUserPeopleId() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      setState(() => _initialLoad = false);
      _fetchDogs(reset: true);
      return;
    }

    try {
      final appUser = await _supabase
          .from('app_users')
          .select('company_profile_id')
          .eq('id', user.id)
          .maybeSingle();

      if (appUser?['company_profile_id'] != null) {
        final company = await _supabase
            .from('company_profile')
            .select('association_number')
            .eq('id', appUser!['company_profile_id'])
            .maybeSingle();

        _associationNumber = company?['association_number'];
      }
    } catch (e) {
      debugPrint('Dogs page profile load error: $e');
    }

    setState(() {
      _initialLoad = false;
    });

    _fetchDogs(reset: true);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchDogs(reset: true);
    });
  }

  Future<void> _fetchDogs({bool reset = false}) async {
    if (_isLoading) return;

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
            hero,
            ala_breeder,
            sale_status
          ''');

      if (_myDogsOnly && _associationNumber != null) {
        query = query.eq('ala_breeder', _associationNumber!);
      }

      if (_spayPendingOnly) {
        query = query.not('spay_due', 'is', null);
      }

      if (_selectedStatus != null) {
        if (_selectedStatus == 'For Sale') {
          query = query.eq('sale_status', 'For Sale');
        } else {
          query = query.eq('status', _selectedStatus!);
        }
      }

      if (search.isNotEmpty) {
        final s = search.replaceAll("'", "''");

        query = query.or(
          'dog_name.ilike.%$s%,dog_ala.ilike.%$s%,microchip.ilike.%$s%',
        );
      }

      final shouldSortBySpay = _spayPendingOnly;

      final response = await (shouldSortBySpay
              ? query.order('spay_due', ascending: true)
              : query.order('dob', ascending: false))
          .range(_offset, _offset + _limit - 1);

      final newDogs = List<Map<String, dynamic>>.from(response);

      setState(() {
        if (reset) {
          _dogs = newDogs;
        } else {
          _dogs.addAll(newDogs);
        }

        _offset += _limit;
        _hasMore = newDogs.length == _limit;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching dogs: $e');

      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final filter = _filters[index];

          final selected =
              (_myDogsOnly && filter == 'My Dogs') ||
              (_spayPendingOnly && filter == 'Spay Pending') ||
              (_selectedStatus == filter) ||
              (_selectedStatus == null &&
                  !_myDogsOnly &&
                  !_spayPendingOnly &&
                  filter == 'All');

          return GestureDetector(
            onTap: () {
              setState(() {
                _myDogsOnly = false;
                _spayPendingOnly = false;
                _selectedStatus = null;

                if (filter == 'My Dogs') {
                  _myDogsOnly = true;
                } else if (filter == 'Spay Pending') {
                  _spayPendingOnly = true;
                } else if (filter != 'All') {
                  _selectedStatus = filter;
                }
              });

              _fetchDogs(reset: true);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF7B4DFF)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF7B4DFF)
                      : Colors.grey.shade300,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF7B4DFF).withOpacity(0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? Colors.white
                        : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: _filters.length,
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
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
          bottom: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.18),
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.pets,
                  color: Colors.white,
                  size: 30,
                ),
              ),

              const SizedBox(width: 14),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dogs',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage breeding, pets, litters and guardians',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search dog name, ALA or microchip...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          _fetchDogs(reset: true);
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_initialLoad) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_dogs.isEmpty && !_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.pets_outlined,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 18),
              const Text(
                'No dogs found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try another filter or search term.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchDogs(reset: true);
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        itemCount: _dogs.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _dogs.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          final dog = _dogs[index];

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DogListCard(
              dog: dog,
              onTap: () async {
                await _saveLastViewedDog(dog['id']);

                final refreshed = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DogDetailsPage(
                      dogId: dog['id'],
                    ),
                  ),
                );

                if (refreshed == true) {
                  _fetchDogs(reset: true);
                }
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveLastViewedDog(String dogId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_viewed_dog_id', dogId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF7B4DFF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Dog',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
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
      body: Column(
      children: [
        _buildTopHeader(),

        const SizedBox(height: 14),

        _buildFilterChips(),

        const SizedBox(height: 10),

        Expanded(
          child: _buildBody(),
        ),
      ],
    ),
    );
  }
}