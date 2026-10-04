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

  // ---- Modo escuro (03/10/2026, pedido do Daniel: mesmo padrão claro /
  // escuro / automático do painel web). `dark` é atualizado por TemaHost
  // (theme/tema_host.dart) e força rebuild geral; os tokens abaixo trocam de
  // valor conforme ele — por isso são getters, não `const`.
  static bool dark = false;
  static Color _c(Color claro, Color escuro) => dark ? escuro : claro;

  static Color get glassTexto => _c(const Color(0xFF1E293B), const Color(0xFFE2E8F0)); // slate-800
  static Color get glassTextoMuted => _c(const Color(0xFF64748B), const Color(0xFF94A3B8)); // slate-500
  static Color get glassIcone => _c(const Color(0xFF64748B), const Color(0xFF94A3B8));
  static const Color glassAcento = _accent; // laranja

  static Color get superficie => _c(Colors.white, const Color(0xFF1E293B)); // card/input
  static Color get superficieAlt => _c(const Color(0xFFF1F5F9), const Color(0xFF273449));
  static Color get bordaSuave => _c(const Color(0xFFE2E8F0), const Color(0xFF334155));
  static Color get bordaForte => _c(const Color(0xFFCBD5E1), const Color(0xFF475569));
  static Color get tintErro => _c(const Color(0xFFFEF2F2), const Color(0xFF3B1D1F));
  static Color get tintOk => _c(const Color(0xFFDCFCE7), const Color(0xFF14301F));
  static Color get tintAviso => _c(const Color(0xFFFEF3C7), const Color(0xFF3A2E10));
  static Color get tintInfo => _c(const Color(0xFFEFF6FF), const Color(0xFF172A4A));
  static Color get fgErro => _c(const Color(0xFFB91C1C), const Color(0xFFFCA5A5));
  static Color get fgOk => _c(const Color(0xFF15803D), const Color(0xFF86EFAC));
  static Color get fgAviso => _c(const Color(0xFF92400E), const Color(0xFFFCD34D));
  static Color get fgInfo => _c(const Color(0xFF1D4ED8), const Color(0xFF93C5FD));
  // Escala de cinza (Colors.grey.shadeN) invertida no escuro, em tons slate.
  static Color get grey50 => _c(Colors.grey.shade50, const Color(0xFF1E293B));
  static Color get grey100 => _c(Colors.grey.shade100, const Color(0xFF1E293B));
  static Color get grey200 => _c(Colors.grey.shade200, const Color(0xFF334155));
  static Color get grey300 => _c(Colors.grey.shade300, const Color(0xFF475569));
  static Color get grey400 => _c(Colors.grey.shade400, const Color(0xFF64748B));
  static Color get grey500 => _c(Colors.grey, const Color(0xFF94A3B8));
  static Color get grey600 => _c(Colors.grey.shade600, const Color(0xFFA3B1C6));
  static Color get grey700 => _c(Colors.grey.shade700, const Color(0xFFCBD5E1));
  static Color get grey800 => _c(Colors.grey.shade800, const Color(0xFFE2E8F0));
  static Color get grey900 => _c(Colors.grey.shade900, const Color(0xFFF1F5F9));

  static const Color accento = _accent;
  static const Color accentoLight = Color(0xFFF0997B); // era 0xFFC9A788 (taupe claro)
  static const Color accentoDark = Color(0xFFB84917); // novo — accento.dark do web

  static Gradient get glassNavGradient {
    final c = _c(_menu, const Color(0xFF0F172A));
    return LinearGradient(colors: [c, c]);
  }

  static Color get glassPillClaro => superficie;
  static Color get glassPillEscuro => superficie;
  static Color get glassTextoAtivo => _c(_primary, const Color(0xFFE2E8F0));

  static LinearGradient get glassPillGradient =>
      LinearGradient(colors: [glassPillClaro, glassPillEscuro]);

  // Radius único usado em card/botão/input no design atual do web
  // (tailwind.config.ts `borderRadius.xl = 14px`) — era 4px.
  static const double radius = 14;

  static ThemeData get light => _montar(Brightness.light);
  static ThemeData get dark_ => _montar(Brightness.dark);

  static ThemeData _montar(Brightness b) {
    final e = b == Brightness.dark;
    final fundo = e ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final menu = e ? const Color(0xFF0F172A) : _menu;
    final card = e ? const Color(0xFF1E293B) : Colors.white;
    final borda = e ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final bordaInput = e ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
    final primaria = e ? const Color(0xFF94A3B8) : _primary;
    final texto = e ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primary,
        secondary: _accent,
        brightness: b,
        surface: e ? card : null,
      ),
      scaffoldBackgroundColor: fundo,
      canvasColor: fundo,
      dividerColor: borda,
      appBarTheme: AppBarTheme(
        backgroundColor: menu,
        foregroundColor: primaria,
        elevation: 0,
      ),
      drawerTheme: DrawerThemeData(backgroundColor: menu),
      dialogTheme: DialogThemeData(backgroundColor: card, surfaceTintColor: Colors.transparent),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: card, surfaceTintColor: Colors.transparent),
      textTheme: ThemeData(brightness: b).textTheme.apply(bodyColor: texto, displayColor: texto),
      // Fase Design-ProFrotas-Divergencias (10/09/2026) — espelha `.card`
      // do globals.css web: cantos arredondados (14px) e sombra suave.
      cardTheme: CardThemeData(
        elevation: e ? 0 : 2,
        color: card,
        surfaceTintColor: Colors.transparent,
        shadowColor: _primary.withOpacity(0.16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: borda),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: bordaInput),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: primaria, width: 2),
        ),
        filled: true,
        fillColor: card,
      ),
    );
  }
}
