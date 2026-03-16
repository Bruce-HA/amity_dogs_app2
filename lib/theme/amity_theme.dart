import 'package:flutter/material.dart';

enum AmityThemeType {
  eucalyptus,
  coastal,
  lavender,
}

class AmityTheme {
  static ThemeData getTheme(AmityThemeType type) {
    switch (type) {
      case AmityThemeType.coastal:
        return _coastalTheme;
      case AmityThemeType.lavender:
        return _lavenderTheme;
      case AmityThemeType.eucalyptus:
      default:
        return _eucalyptusTheme;
    }
  }

  // 🌿 EUCALYPTUS (Default)
  static final ThemeData _eucalyptusTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF5F8D7A),
      secondary: Color(0xFFA7C4BC),
      surface: Colors.white,
      background: Color(0xFFF7F9F8),
      error: Color(0xFFC8553D),
    ),
    scaffoldBackgroundColor: const Color(0xFFF7F9F8),
  );

  // 🌊 COASTAL
  static final ThemeData _coastalTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF2A9D8F),
      secondary: Color(0xFFE9C46A),
      surface: Colors.white,
      background: Color(0xFFF1FAEE),
      error: Color(0xFFE76F51),
    ),
    scaffoldBackgroundColor: const Color(0xFFF1FAEE),
  );

  // 💜 LAVENDER
  static final ThemeData _lavenderTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF7B6D8D),
      secondary: Color(0xFFD6CADD),
      surface: Colors.white,
      background: Color(0xFFF8F7FB),
      error: Color(0xFFC8553D),
    ),
    scaffoldBackgroundColor: const Color(0xFFF8F7FB),
  );
}