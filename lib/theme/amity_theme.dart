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

    // 🔥 TEXT SYSTEM
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(fontSize: 14),
      bodySmall: TextStyle(fontSize: 12, color: Colors.grey),
    ),

    // 🔥 INPUT (Search bar upgrade)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),

    // 🔥 CHIP (filters upgrade)
    chipTheme: ChipThemeData(
      backgroundColor: Colors.grey.shade100,
      selectedColor: const Color(0xFF5F8D7A).withOpacity(0.15),

      labelStyle: const TextStyle(
        color: Colors.black87, // 🔥 FIXED CONTRAST
        fontWeight: FontWeight.w500,
      ),

      secondaryLabelStyle: const TextStyle(
        color: Colors.black87,
      ),

      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade300),
      ),
    ),

    // 🔥 CARD (matches your AppCard style)
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      color: Colors.white,
    ),

    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.black,
    ),
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