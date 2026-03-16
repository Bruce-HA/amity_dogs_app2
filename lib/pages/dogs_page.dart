import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pages/dog_details_page.dart';

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

  final List<String> _statuses = [
    'pending',
    'Pet',
    'Active',
    'Our Guardian',
    'Retired',
    'Deceased',
    'Forsale',
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

      var query = _supabase
          .from('dogs_list_view')
          .select('''
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

      // 🔹 APPLY FILTERS FIRST

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
        final filter =
            'dog_ala.ilike.%$search%,'
            'microchip.ilike.%$search%';
        query = query.or(filter);
      }

      // 🔹 APPLY ORDER LAST

      final response = await Supabase.instance.client
        .from('people_sorted')
        .select()
        .order('sort_name', ascending: true);

      final results =
          List<Map<String, dynamic>>.from(response);

      setState(() {
        _dogs.addAll(results);
        _offset += _limit;
        _hasMore = results.length == _limit;
        _initialLoad = false;
      });
    } catch (e) {
      debugPrint('Error fetching dogs: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading dogs: $e')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilterChip(
            label: const Text('My Dogs'),
            selected: _myDogsOnly,
            onSelected: (v) {
              setState(() => _myDogsOnly = v);
              _fetchDogs(reset: true);
            },
          ),
          FilterChip(
            label: const Text('Pending'),
            selected: _spayPendingOnly,
            onSelected: (v) {
              setState(() => _spayPendingOnly = v);
              _fetchDogs(reset: true);
            },
          ),
          DropdownButton<String>(
            value: _selectedStatus ?? 'All',
            items: [
              const DropdownMenuItem(
                value: 'All',
                child: Text('All'),
              ),
              ..._statuses.map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(s),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _selectedStatus = value == 'All' ? null : value;
              });
              _fetchDogs(reset: true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDogTile(Map<String, dynamic> dog) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final owner = dog['owner'];
    final dogName = dog['dog_name'];
    final alaName = dog['dog_ala'];
    final imageUrl = dog['hero_image_url'];

    final int? ageMonths = dog['age_months'];
    final String? spayDueRaw = dog['spay_due'];

    String formatAge(int? months) {
      if (months == null) return '';
      final years = months ~/ 12;
      final remainingMonths = months % 12;
      return "${years}y ${remainingMonths}m";
    }

    DateTime? safeParseDate(dynamic raw) {
      if (raw == null) return null;
      try {
        if (raw is DateTime) return raw;
        return DateTime.parse(raw.toString());
      } catch (_) {
        return null;
      }
    }

    String formatDate(dynamic raw) {
      final date = safeParseDate(raw);
      if (date == null) return '';
      return "${date.day}/${date.month}/${date.year}";
    }

    Color getSpayColor(dynamic raw) {
      final due = safeParseDate(raw);
      if (due == null) return colorScheme.outline;

      final now = DateTime.now();
      final difference = due.difference(now).inDays;

      if (difference <= 60) return colorScheme.error;
      if (difference <= 120) return Colors.orange;
      return colorScheme.primary;
    }

    final ageText = formatAge(ageMonths);
    final bool isSenior = ageMonths != null && ageMonths >= 60;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🐶 IMAGE
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: imageUrl != null && imageUrl.toString().isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: 95,
                      height: 95,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),

            const SizedBox(width: 16),

            // 📄 CONTENT
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // NAME
                    Text(
                      dogName != null && dogName.toString().isNotEmpty
                          ? dogName
                          : alaName ?? '',
                      style: theme.textTheme.titleMedium,
                    ),

                    if (dogName != null &&
                        dogName.toString().isNotEmpty &&
                        alaName != null)
                      Text(
                        alaName,
                        style: theme.textTheme.bodySmall,
                      ),

                    const SizedBox(height: 6),

                    Text(
                      'Microchip: ${dog['microchip'] ?? ''}',
                      style: theme.textTheme.bodyMedium,
                    ),

                    Text(
                      'Status: ${dog['status'] ?? ''}',
                      style: theme.textTheme.bodyMedium,
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        if (ageText.isNotEmpty)
                          Text(
                            ageText,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: isSenior
                                  ? Colors.orange
                                  : colorScheme.onSurface,
                            ),
                          ),

                        if (spayDueRaw != null) ...[
                          const SizedBox(width: 12),
                          Chip(
                            label: Text(
                              formatDate(spayDueRaw),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                            backgroundColor:
                                getSpayColor(spayDueRaw),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ],
                    ),

                    if (owner != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Owner: ${owner['first_name_1st']} ${owner['last_name_1st']}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dogs')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText:
                    'Search dog, microchip, owner, breeder...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          _buildFilters(),
          Expanded(
            child: _initialLoad
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    itemCount:
                        _dogs.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < _dogs.length) {
                        return _buildDogTile(_dogs[index]);
                      } else {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                              child:
                                  CircularProgressIndicator()),
                        );
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }
}