import 'package:flutter/material.dart';
import 'amity_theme.dart';

class ThemeProvider extends ChangeNotifier {
  AmityThemeType _currentTheme = AmityThemeType.eucalyptus;

  AmityThemeType get currentTheme => _currentTheme;

  ThemeData get themeData =>
      AmityTheme.getTheme(_currentTheme);

  void setTheme(AmityThemeType theme) {
    _currentTheme = theme;
    notifyListeners();
  }
}