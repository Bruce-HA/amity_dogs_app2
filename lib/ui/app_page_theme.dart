import 'package:flutter/material.dart';

class AppPageTheme {
  final Color primary;
  final Color dark;
  final Color light;
  final Color background;
  final IconData icon;

  const AppPageTheme({
    required this.primary,
    required this.dark,
    required this.light,
    required this.background,
    required this.icon,
  });
}

class AppPageThemes {
  static const flow = AppPageTheme(
    primary: Color(0xFF8E44AD),
    dark: Color(0xFF6C3483),
    light: Color(0xFFF3E5F5),
    background: Color(0xFFFFF8EA),
    icon: Icons.route,
  );

  static const dogs = AppPageTheme(
    primary: Color(0xFF5B2C83),
    dark: Color(0xFF3D1E59),
    light: Color(0xFFEDE7F6),
    background: Color(0xFFF8F5FB),
    icon: Icons.pets,
  );

  static const crm = AppPageTheme(
    primary: Colors.teal,
    dark: Color(0xFF00695C),
    light: Color(0xFFE0F2F1),
    background: Color(0xFFF1FAF9),
    icon: Icons.mark_email_unread,
  );
}