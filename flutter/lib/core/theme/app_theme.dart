import 'package:flutter/material.dart';
class AppTheme {
  static const _primary = Color(0xFF0D2D6B);
  static const _accent  = Color(0xFF00B4D8);
  // Achado real (reportado pelo Daniel): a barra do topo (AppBarTheme,
  // usada em toda tela) e o menu/drawer (cabeçalho em home_screen.dart)
  // usavam 2 navies diferentes — `_primary` (0xFF0D2D6B, mais "azul vivo")
  // na AppBar contra 0xFF0B1220 (mais escuro/preto-azulado) no cabeçalho do
  // drawer. Pedido do Daniel: a barra do topo tem que usar a MESMA cor do
  // menu — `_menu` abaixo é literalmente o mesmo valor hardcoded do
  // Container do cabeçalho do Drawer (ver home_screen.dart:69).
  static const _menu = Color(0xFF0B1220);
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _primary, secondary: _accent),
    appBarTheme: const AppBarTheme(backgroundColor: _menu, foregroundColor: Colors.white, elevation: 0),
    cardTheme: CardThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  );
  static ThemeData get dark => ThemeData(
    useMaterial3: true, brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(seedColor: _primary, secondary: _accent, brightness: Brightness.dark),
  );
}