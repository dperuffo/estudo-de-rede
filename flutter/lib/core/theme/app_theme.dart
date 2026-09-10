import 'package:flutter/material.dart';

class AppTheme {
  // Fase Design-ProFrotas-Divergencias (10/09/2026, pedido do Daniel:
  // "Vamos atualizar os PWAs cliente e motorista com o mesmo design
  // aplicado na aplicacao web") — a web trocou de "Swiss Minimalism"
  // (off-black/branco/cinza + acento taupe, cantos quase retos) pra
  // "Design-ProFrotas-Divergencias" em 09/09/2026 (ver tailwind.config.ts/
  // globals.css do painel web): paleta slate (`frota`) + acento LARANJA
  // (`accento` = #de6024), cantos bem arredondados (radius 14, era 4) e
  // sombra suave difusa cor-de-ardósia (era sombra quase preta e chapada).
  // Nomes mantidos, só o valor muda — mesma convenção já usada aqui antes,
  // pra não precisar editar campo por campo nas ~150 telas que já
  // referenciam `AppTheme.accento`/`AppTheme.glass*`.
  static const _primary = Color(0xFF4E5D77); // frota-500/700 (slate) — era 0xFF171717 (off-black)
  static const _accent = Color(0xFFDE6024); // accento laranja — era 0xFFB38B6D (taupe)
  static const _menu = Color(0xFFF0F0F0); // frota-50 — era 0xFFF8FAFC

  static const Color glassTexto = Color(0xFF1E293B); // slate-800 (inalterado)
  static const Color glassTextoMuted = Color(0xFF64748B); // slate-500 (inalterado)
  static const Color glassIcone = Color(0xFF64748B); // slate-500 (inalterado)
  static const Color glassAcento = _accent; // laranja

  static const Color accento = _accent;
  static const Color accentoLight = Color(0xFFF0997B); // era 0xFFC9A788 (taupe claro)
  static const Color accentoDark = Color(0xFFB84917); // novo — accento.dark do web

  static const Gradient glassNavGradient = LinearGradient(
    colors: [_menu, _menu],
  );

  static const Color glassPillClaro = Colors.white;
  static const Color glassPillEscuro = Colors.white;
  static const Color glassTextoAtivo = _primary;

  static const LinearGradient glassPillGradient = LinearGradient(
    colors: [glassPillClaro, glassPillEscuro],
  );

  // Radius único usado em card/botão/input no design atual do web
  // (tailwind.config.ts `borderRadius.xl = 14px`) — era 4px.
  static const double radius = 14;

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme:
            ColorScheme.fromSeed(seedColor: _primary, secondary: _accent),
        appBarTheme: const AppBarTheme(
            backgroundColor: _menu,
            foregroundColor: _primary,
            elevation: 0),
        // Fase Design-ProFrotas-Divergencias (10/09/2026) — espelha `.card`
        // do globals.css web: cantos arredondados (14px, era 4px) e sombra
        // suave e difusa cor-de-ardósia (era `_primary.withOpacity(0.06)`,
        // quase preta e chapada — CSS `shadow-card: 0 12px 32px
        // rgba(78,93,119,.12)`; aqui aproximado com elevation + shadowColor,
        // já que Flutter não tem blur de sombra configurável por Card).
        cardTheme: CardThemeData(
          elevation: 2,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shadowColor: _primary.withOpacity(0.16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: const BorderSide(color: _primary, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      );
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
            seedColor: _primary,
            secondary: _accent,
            brightness: Brightness.dark),
      );
}
