import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/app_user.dart';

final supabase = Supabase.instance.client;

Future<void> showAddLogModal(BuildContext context, Map litter) async {
  final noteController = TextEditingController();
  String category = 'mum feed';
  DateTime selectedTime = DateTime.now();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Add Entry"),

                DropdownButton<String>(
                  value: category,
                  isExpanded: true,
                  items: [
                    'mum feed',
                    'pup feed',
                    'toilet',
                    'medication',
                    'other'
                  ].map((c) {
                    String label = c.split(' ')
                        .map((w) => w[0].toUpperCase() + w.substring(1))
                        .join(' ');

                    return DropdownMenuItem(
                      value: c,
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(c),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Text(label),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      category = val!;
                    });
                  },
                ),

                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),

                ElevatedButton(
                  onPressed: () async {
                    await supabase.from('whelping_logs').insert({
                      'litter_id': litter['id'],
                      'litter_full_code': litter['litter_full_code'],
                      'ala_litter_number': litter['ala_litter_number'],
                      'short_litter_name': litter['short_litter_name'],
                      'event_time': selectedTime.toIso8601String(),
                      'note': noteController.text,
                      'category': category,
                    });

                    Navigator.pop(context);
                  },
                  child: const Text("Save"),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
Color _getCategoryColor(String? category) {
  switch (category) {
    case 'mum feed':
      return Colors.blue;
    case 'pup feed':
      return Colors.teal;
    case 'toilet':
      return Colors.brown;
    case 'medication':
      return Colors.red;
    default:
      return Colors.grey;
  }
}