import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/app_user.dart';

final supabase = Supabase.instance.client;

Future<void> showAddLogModal(
  BuildContext context,
  Map litter, {
  String initialCategory = 'mum feed',
}) async {
  final noteController = TextEditingController();
  String category = initialCategory;
  DateTime selectedTime = DateTime.now();
  bool isSaving = false;

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
                const Text(
                  "Add Entry",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 12),

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
                    final label = c
                        .split(' ')
                        .map((w) => w[0].toUpperCase() + w.substring(1))
                        .join(' ');

                    return DropdownMenuItem(
                      value: c,
                      child: Text(label),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      category = val!;
                    });
                  },
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  autofocus: true,
                ),

                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setState(() {
                            isSaving = true;
                          });

                          await supabase.from('whelping_logs').insert({
                            'litter_id': litter['id'],
                            'litter_full_code': litter['litter_full_code'],
                            'ala_litter_number': litter['ala_litter_number'],
                            'short_litter_name': litter['short_litter_name'],
                            'event_time': selectedTime.toIso8601String(),
                            'note': noteController.text,
                            'category': category,
                            'created_by_name': AppUser.name,
                          });

                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Saved'),
                            ),
                          );
                        },
                  child: Text(isSaving ? "Saving..." : "Save"),
                ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      );
    },
  );
}
Future<void> showEditLogModal(
  BuildContext context,
  Map log,
) async {
  final noteController = TextEditingController(
    text: log['note'] ?? '',
  );

  String category = log['category'] ?? 'other';
  DateTime selectedTime = log['event_time'] != null
      ? DateTime.parse(log['event_time']).toLocal()
      : DateTime.now();

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
                const Text(
                  "Edit Entry",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 12),

                DropdownButton<String>(
                  value: category,
                  isExpanded: true,
                  items: [
                    'mum feed',
                    'pup feed',
                    'toilet',
                    'medication',
                    'other',
                  ].map((c) {
                    final label = c
                        .split(' ')
                        .map((w) => w[0].toUpperCase() + w.substring(1))
                        .join(' ');

                    return DropdownMenuItem(
                      value: c,
                      child: Text(label),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      category = val!;
                    });
                  },
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),

                //==========================
                //. Change time and date.   //
                //==========================
                const SizedBox(height: 16),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time),
                    title: const Text("Event Date & Time"),
                    subtitle: Text(
                      "${selectedTime.day}/${selectedTime.month}/${selectedTime.year} "
                      "${selectedTime.hour.toString().padLeft(2, '0')}:"
                      "${selectedTime.minute.toString().padLeft(2, '0')}",
                    ),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedTime,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );

                      if (pickedDate == null) return;

                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedTime),
                      );

                      if (pickedTime == null) return;

                      setState(() {
                        selectedTime = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    },
                  ),
                //=====================
                //. update button.   //
                //====================
     //         const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Delete Entry"),
                              content: const Text(
                                "Are you sure you want to delete this entry?"
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text("Cancel"),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: const Text("Delete"),
                                ),
                              ],
                            ),
                          );

                          if (confirm != true) return;

                          await Supabase.instance.client
                            .from('whelping_logs')
                            .delete()
                            .eq('id', log['id']);

                        Navigator.pop(context, true);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Deleted'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          "Delete",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await supabase
                              .from('whelping_logs')
                              .update({
                                'category': category,
                                'note': noteController.text,
                                'event_time': selectedTime.toIso8601String(),
                              })
                              .eq('id', log['id'])
                              .order('event_time', ascending: false);

                          Navigator.pop(context, true);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Updated'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text("Update"),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      );
    },
  );
}