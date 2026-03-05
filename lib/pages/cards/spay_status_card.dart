import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SpayStatusCard extends StatefulWidget {
  final Map<String, dynamic> dog;
  final Function onUpdated;

  const SpayStatusCard({super.key, required this.dog, required this.onUpdated});

  @override
  State<SpayStatusCard> createState() => _SpayStatusCardState();
}

class _SpayStatusCardState extends State<SpayStatusCard> {
  final supabase = Supabase.instance.client;

  bool get canHaveSpayDue {
    return widget.dog['dog_type'] == 'Pet' &&
        (widget.dog['desexed'] == 'No' || widget.dog['desexed'] == 'Unknown');
  }

  Future pickDueDate() async {
    final picked = await showDatePicker(
      context: context,

      initialDate: DateTime.now(),

      firstDate: DateTime(2020),

      lastDate: DateTime(2035),
    );

    if (picked == null) return;

    await supabase
        .from('dogs')
        .update({
          'spay_due_date': picked.toIso8601String(),
          'spay_status': 'Due',
        })
        .eq('id', widget.dog['id']);

    widget.onUpdated();
  }

  Future markCompleted() async {
    await supabase
        .from('dogs')
        .update({
          'spay_completed_date': DateTime.now().toIso8601String(),
          'spay_due_date': null,
          'spay_status': 'Completed',
          'desexed': 'Yes',
        })
        .eq('id', widget.dog['id']);

    widget.onUpdated();
  }

  Future clearSpay() async {
    await supabase
        .from('dogs')
        .update({
          'spay_due_date': null,
          'spay_completed_date': null,
          'spay_status': 'Unknown',
        })
        .eq('id', widget.dog['id']);

    widget.onUpdated();
  }

  String formatDate(String? date) {
    if (date == null) return "Not set";

    final dt = DateTime.tryParse(date);

    if (dt == null) return "Invalid";

    return DateFormat('d MMM yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    if (!canHaveSpayDue) return const SizedBox();

    final dueDate = widget.dog['spay_due_date'];

    final completedDate = widget.dog['spay_completed_date'];

    final status = widget.dog['spay_status'] ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.only(top: 8),

      child: Padding(
        padding: const EdgeInsets.all(12),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text(
              "Spay Status",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text("Status: $status"),

            const SizedBox(height: 4),

            Text("Due Date: ${formatDate(dueDate)}"),

            Text("Completed: ${formatDate(completedDate)}"),

            const SizedBox(height: 8),

            Wrap(
              spacing: 8,

              children: [
                ElevatedButton.icon(
                  onPressed: pickDueDate,

                  icon: const Icon(Icons.event),

                  label: const Text("Set Due Date"),
                ),

                ElevatedButton.icon(
                  onPressed: markCompleted,

                  icon: const Icon(Icons.check),

                  label: const Text("Mark Completed"),
                ),

                OutlinedButton.icon(
                  onPressed: clearSpay,

                  icon: const Icon(Icons.clear),

                  label: const Text("Clear"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
