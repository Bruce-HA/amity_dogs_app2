import 'package:flutter/material.dart';

class LogCategory {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const LogCategory({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
}

const logCategories = [
  LogCategory(
    value: 'mum feed',
    label: 'Mum',
    icon: Icons.child_care,
    color: Colors.blue,
  ),
  LogCategory(
    value: 'pup feed',
    label: 'Pup',
    icon: Icons.pets,
    color: Colors.teal,
  ),
  LogCategory(
    value: 'toilet',
    label: 'Toilet',
    icon: Icons.water_drop,
    color: Colors.brown,
  ),
  LogCategory(
    value: 'medication',
    label: 'Meds',
    icon: Icons.medication,
    color: Colors.red,
  ),
  LogCategory(
    value: 'other',
    label: 'Other',
    icon: Icons.notes,
    color: Colors.grey,
  ),
];
LogCategory getCategory(String? value) {
  return logCategories.firstWhere(
    (c) => c.value == value,
    orElse: () => logCategories.last,
  );
}