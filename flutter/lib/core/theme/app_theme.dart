import 'package:flutter/material.dart';
class AppTheme {
  static const _primary = Color(0xFF0D2D6B);
  static const _accent  = Color(0xFF00B4D8);
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _primary, secondary: _accent),
    appBarTheme: const AppBarTheme(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0),
    cardTheme: CardThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  );
  static ThemeData get dark => ThemeData(
    useMaterial3: true, brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(seedColor: _primary, secondary: _accent, brightness: Brightness.dark),
  );
}