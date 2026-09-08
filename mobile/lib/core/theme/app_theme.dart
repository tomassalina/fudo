import 'package:flutter/material.dart';

/// Placeholder dark theme — real visual design comes from a Claude Design
/// prototype, not yet shared. This is a minimal dark + violet accent theme
/// so the scaffold screens are usable while the final UI is defined.
class AppTheme {
  AppTheme._();

  static const Color _background = Color(0xFF0A0A0C);
  static const Color _surface = Color(0xFF16161A);
  static const Color _violetAccent = Color(0xFF8B5CF6);

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _violetAccent,
      brightness: Brightness.dark,
      surface: _surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _background,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _surface,
        selectedItemColor: _violetAccent,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
