import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DebugAllDogsPage extends StatefulWidget {
  const DebugAllDogsPage({Key? key}) : super(key: key);

  @override
  State<DebugAllDogsPage> createState() => _DebugAllDogsPageState();
}

class _DebugAllDogsPageState extends State<DebugAllDogsPage> {
  final _client = Supabase.instance.client;

  List<Map<String, dynamic>> _dogs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDogs();
  }

  Future<void> _loadDogs() async {
    try {
      final response = await _client
          .from('dogs')
          .select('dog_name, dog_ala, sex, my_dogs')
          .order('dog_name');

      print("TOTAL DOGS: ${response.length}");

      final turkish = response.where(
        (d) => (d['dog_name'] ?? '').toString().contains('Turkish'),
      );

      print("TURKISH FOUND: $turkish");

      setState(() {
        _dogs = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      print("ERROR LOADING DOGS: $e");
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🐶 ALL DOGS DEBUG'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _dogs.length,
              itemBuilder: (context, index) {
                final dog = _dogs[index];

                return ListTile(
                  title: Text(dog['dog_name'] ?? 'No Name'),
                  subtitle: Text(
                    "${dog['dog_ala'] ?? ''} | ${dog['sex'] ?? ''} | my_dogs: ${dog['my_dogs']}",
                  ),
                );
              },
            ),
    );
  }
}