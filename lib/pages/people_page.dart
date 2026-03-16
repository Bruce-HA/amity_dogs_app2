import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'people_detail_page.dart';

class PeoplePage extends StatefulWidget {
  const PeoplePage({super.key});

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _debounce;

  final int _limit = 25;
  int _offset = 0;

  bool _isLoading = false;
  bool _hasMore = true;
  bool _initialLoad = true;

  // FILTERS
  bool filterBreeder = false;
  bool filterOwner = false;
  bool filterGuardian = false;
  bool filterSupplier = false;
  bool filterBuyer = false;
  bool filterProspect = false;

  List<Map<String, dynamic>> _people = [];

  @override
  void initState() {
    super.initState();
    _fetchPeople(reset: true);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _fetchPeople();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchPeople(reset: true);
    });
  }

  Future<void> _fetchPeople({bool reset = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (reset) {
        _offset = 0;
        _hasMore = true;
        _people.clear();
        _initialLoad = true;
      }
    });

    try {
      final search = _searchController.text.trim();

      var query = _supabase
          .from('people_sorted')
          .select();


      if (search.isNotEmpty) {
        final filter =
            'last_name_1st.ilike.%$search%,'
            'business_name.ilike.%$search%,'
            'email_1st.ilike.%$search%,'
            'phone_1st.ilike.%$search%,'
            'microchips.ilike.%$search%,'
            'dog_names.ilike.%$search%';

        query = query.or(filter);
      }

      // OR LOGIC for role filters (recommended)
      List<String> roleFilters = [];

      if (filterBreeder) roleFilters.add('is_breeder.eq.true');
      if (filterOwner) roleFilters.add('is_owner.eq.true');
      if (filterGuardian) roleFilters.add('is_guardian.eq.true');
      if (filterSupplier) roleFilters.add('is_supplier.eq.true');
      if (filterBuyer) roleFilters.add('is_buyer.eq.true');
      if (filterProspect) roleFilters.add('is_prospect.eq.true');

      if (roleFilters.isNotEmpty) {
        query = query.or(roleFilters.join(','));
      }

      final response = await query
          .order('sort_name', ascending: true)
          .range(_offset, _offset + _limit - 1);


      final results =
          List<Map<String, dynamic>>.from(response);

      setState(() {
        _people.addAll(results);
        _offset += _limit;
        _hasMore = results.length == _limit;
        _initialLoad = false;
      });
    } catch (e) {
      debugPrint('Error fetching people: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading people: $e')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  // MINI CHIPS

  Widget _miniRoleChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _miniAutoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
          color: color,
        ),
      ),
    );
  }

  Widget _buildFilterChip(
      String label, bool selected, Function(bool) onSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
        selectedColor: Colors.teal.withOpacity(.2),
        checkmarkColor: Colors.teal,
      ),
    );
  }

  Widget _buildPersonTile(Map<String, dynamic> person) {
    final businessName = person['business_name'];
    final firstName = person['first_name_1st'] ?? '';
    final lastName = person['last_name_1st'] ?? '';

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      title: businessName != null &&
              businessName.toString().isNotEmpty
          ? Text(
              businessName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            )
          : null,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$firstName $lastName'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (person['is_breeder'] == true)
                _miniRoleChip("Breeder", Colors.purple),

              if (person['is_breeder'] == false &&
                  person['has_bred_dogs'] == true)
                _miniAutoChip("Breeder (Auto)", Colors.purple),

              if (person['is_owner'] == true)
                _miniRoleChip("Owner", Colors.blue),

              if (person['is_owner'] == false &&
                  person['has_owned_dogs'] == true)
                _miniAutoChip("Owner (Auto)", Colors.blue),

              if (person['is_guardian'] == true)
                _miniRoleChip("Guardian", Colors.teal),

              if (person['is_supplier'] == true)
                _miniRoleChip("Supplier", Colors.orange),

              if (person['is_buyer'] == true)
                _miniRoleChip("Buyer", Colors.green),

              if (person['is_prospect'] == true)
                _miniRoleChip("Prospect", Colors.grey),
            ],
          ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PeopleDetailPage(personId: person['people_id']),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search last name, dog name, microchip...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _fetchPeople(reset: true);
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip("Breeder", filterBreeder, (v) {
                  setState(() => filterBreeder = v);
                  _fetchPeople(reset: true);
                }),
                _buildFilterChip("Owner", filterOwner, (v) {
                  setState(() => filterOwner = v);
                  _fetchPeople(reset: true);
                }),
                _buildFilterChip("Guardian", filterGuardian, (v) {
                  setState(() => filterGuardian = v);
                  _fetchPeople(reset: true);
                }),
                _buildFilterChip("Supplier", filterSupplier, (v) {
                  setState(() => filterSupplier = v);
                  _fetchPeople(reset: true);
                }),
                _buildFilterChip("Buyer", filterBuyer, (v) {
                  setState(() => filterBuyer = v);
                  _fetchPeople(reset: true);
                }),
                _buildFilterChip("Prospect", filterProspect, (v) {
                  setState(() => filterProspect = v);
                  _fetchPeople(reset: true);
                }),
              ],
            ),
          ),

          Expanded(
            child: _initialLoad
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    itemCount:
                        _people.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < _people.length) {
                        return _buildPersonTile(_people[index]);
                      } else {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                              child: CircularProgressIndicator()),
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