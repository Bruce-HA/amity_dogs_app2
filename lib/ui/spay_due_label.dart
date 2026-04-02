import 'package:flutter/material.dart';

class SpayDueLabel extends StatelessWidget {
  final String? spayDue;

  const SpayDueLabel({super.key, required this.spayDue});

  @override
  Widget build(BuildContext context) {
    if (spayDue == null || spayDue!.isEmpty) {
      return const SizedBox();
    }

    final dueDate = DateTime.tryParse(spayDue!);
    if (dueDate == null) return const SizedBox();

    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;

    final months = difference / 30;

    Color color = Colors.grey;
    FontWeight weight = FontWeight.normal;
    double size = 12;

    if (difference < 0) {
      // OVERDUE
      color = Colors.red;
      weight = FontWeight.bold;
      size = 16;
    } else if (months <= 2) {
      color = Colors.red;
    } else if (months <= 5) {
      color = Colors.orange;
    } else if (months <= 12) {
      color = Colors.green;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        "Spay Due: ${_formatDate(dueDate)}",
        style: TextStyle(
          color: color,
          fontWeight: weight,
          fontSize: size,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}