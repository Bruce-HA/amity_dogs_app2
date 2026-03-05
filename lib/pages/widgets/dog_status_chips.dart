import 'package:flutter/material.dart';

class DogStatusChips extends StatelessWidget {
  final Map<String, dynamic> dog;

  const DogStatusChips({super.key, required this.dog});

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgets = [];

    widgets.add(_desexedChip());

    final spayWidget = _spayWidget();
    if (spayWidget != null) widgets.add(spayWidget);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _desexedChip() {
    final status = (dog['desexed'] ?? 'Unknown').toString();

    Color color;

    switch (status) {
      case 'Yes':
        color = Colors.blue;
        break;

      case 'Pending':
        color = Colors.green;
        break;

      case 'Breeding':
        color = Colors.orange;
        break;

      case 'No':
        color = Colors.grey;
        break;

      default:
        color = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Chip(
        label: Text('Desexed: $status'),

        backgroundColor: color.withOpacity(0.15),

        labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),

        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget? _spayWidget() {
    final spayStr = dog['spay_due'];

    if (spayStr == null || spayStr.toString().isEmpty) return null;

    final spayDate = DateTime.parse(spayStr);

    final now = DateTime.now();

    final days = spayDate.difference(now).inDays;

    Color color;

    if (days < 0) {
      color = Colors.red;
    } else if (days <= 30) {
      color = Colors.orange;
    } else {
      color = Colors.green;
    }

    final formatted =
        "${spayDate.day.toString().padLeft(2, '0')}/"
        "${spayDate.month.toString().padLeft(2, '0')}/"
        "${spayDate.year}";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Chip(
          label: const Text('Spay Due'),

          backgroundColor: color.withOpacity(0.15),

          labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),

          visualDensity: VisualDensity.compact,
        ),

        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Text(
            formatted,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
