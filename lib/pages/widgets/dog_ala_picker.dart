import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class DogAlaPicker extends StatefulWidget {
  final String label;
  final Map<String, dynamic>? selectedDog;
  final Function(Map<String, dynamic>) onSelected;

  const DogAlaPicker({
    super.key,
    required this.label,
    required this.selectedDog,
    required this.onSelected,
  });

  @override
  State<DogAlaPicker> createState() => _DogAlaPickerState();
}

class _DogAlaPickerState extends State<DogAlaPicker> {
  final controller = TextEditingController();
  List results = [];

  Future<void> search(String value) async {
    if (value.isEmpty) return;

    final res = await supabase
        .from('dogs')
        .select('id, dog_name, dog_ala')
        .ilike('dog_ala', '%$value%')
        .limit(10);

    setState(() {
      results = res;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: const TextStyle(fontWeight: FontWeight.w600)),

        TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Search by ALA...',
          ),
          onChanged: search,
        ),

        if (widget.selectedDog != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              "Selected: ${widget.selectedDog!['dog_name']} (${widget.selectedDog!['dog_ala']})",
              style: const TextStyle(fontSize: 12),
            ),
          ),

        ...results.map((dog) => ListTile(
              title: Text("${dog['dog_name']}"),
              subtitle: Text(dog['dog_ala']),
              onTap: () {
                widget.onSelected(dog);
                setState(() {
                  results = [];
                  controller.text = dog['dog_ala'];
                });
              },
            )),
      ],
    );
  }
}