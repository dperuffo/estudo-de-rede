import 'package:flutter/material.dart';

class AppTheme {
  // Fase Design-System-Swiss-Minimalism (29/08/2026, pedido do Daniel:
  // "aplicar o mesmo design.md dos PWAs Motorista e Cliente, conforme
  // aplicado na web") — a web trocou de "Corporate Blue" (Dark Navy/Royal
  // Blue) pra "Minimalism & Swiss Style" em 27/08/2026 (ver
  // tailwind.config.ts/globals.css do painel web): off-black/branco/cinza
  // + acento taupe, cantos quase retos, superfícies lisas, SEM
  // blur/gradiente/glow. Mesmos valores já aplicados no PWA Motorista
  // (estrada-que-cuida/lib/core/theme/app_theme.dart) — nomes de
  // constante mantidos por estabilidade (usados em ~150 telas deste app,
  // que cobre as visões cliente/posto/admin), só o VALOR muda.
  static const _primary = Color(0xFF171717); // era 0xFF0D2D6B (navy)
  static const _accent = Color(0xFFB38B6D); // era 0xFF00B4D8 (ciano) — agora o taupe do design.md
  // A barra do topo e o cabeçalho do menu/drawer usam a MESMA cor
  // (decisão já tomada antes, mantida) — agora off-black em vez de
  // preto-azulado.
  static const _menu = Color(0xFF111111);

  // Nomes `glass*` datam da fase "vidro" (20/08/2026); mantidos por
  // estabilidade (usados em ~150 telas via `AppTheme.glass*`), mas o
  // VALOR agora segue a identidade Swiss Minimalism — texto/ícone claros
  // sobre o fundo off-black do menu, sem opacidade vidrada. Espelha
  // .glass-nav-texto/-texto-muted/-icone/-acento do globals.css web
  // (slate-100/slate-400/slate-300/accento).
  static const Color glassTexto = Color(0xFFF1F5F9); // slate-100
  static const Color glassTextoMuted = Color(0xFF94A3B8); // slate-400
  static const Color glassIcone = Color(0xFFCBD5E1); // slate-300
  static const Color glassAcento = _accent; // taupe

  // Único acento decorativo do tema (design.md: "Taupe — Extended
  // palette, decorative use") — alias com nome mais claro pra uso fora
  // do contexto do menu (ex.: indicador de tab ativa).
  static const Color accento = _accent;
  static const Color accentoLight = Color(0xFFC9A788);

  // Antes um RadialGradient "anel de luz"; a fase Swiss-Minimalism pede
  // fundo LISO, sem blur/glow — igual ao `.glass-nav` da web (sólido).
  // Mantido como `Gradient` (não `Color`) só pra não precisar editar as
  // ~150 telas que fazem `BoxDecoration(gradient: AppTheme.glassNavGradient)`:
  // um gradiente com as DUAS paradas na mesma cor renderiza idêntico a
  // uma cor sólida.
  static const Gradient glassNavGradient = LinearGradient(
    colors: [_menu, _menu],
  );

  // Antes um gradiente lilás (.glass-tab-ativa da fase vidro); a aba
  // ativa no Swiss Minimalism vira preenchimento BRANCO sólido com texto
  // quase-preto (mesmo `.glass-tab-ativa` da web já migrado: `bg-white
  // text-frota-600`). `glassPillGradient` continua `Gradient` pelo mesmo
  // motivo do `glassNavGradient` acima (não editar cada TabBar/indicador).
  static const Color glassPillClaro = Colors.white;
  static const Color glassPillEscuro = Colors.white;
  static const Color glassTextoAtivo = _menu; // texto quase-preto sobre o branco

  static const LinearGradient glassPillGradient = LinearGradient(
    colors: [glassPillClaro, glassPillEscuro],
  );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC), // slate-50, igual ao painel web
        colorScheme:
            ColorScheme.fromSeed(seedColor: _primary, secondary: _accent),
        appBarTheme: const AppBarTheme(
            backgroundColor: _menu,
            foregroundColor: Colors.white,
            elevation: 0),
        // Fase Design-System-Swiss-Minimalism (29/08/2026) — Card é usado em
        // dezenas de telas (dashboard, indicadores, listas) sem estilo
        // próprio (cada uma só chamava `Card(child: ...)`). Espelha `.card`
        // do globals.css web: superfície branca SÓLIDA (sem translucidez da
        // fase vidro anterior), 1px de borda cinza-clara, sombra suave,
        // cantos quase retos.
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shadowColor: _menu.withOpacity(0.06),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: Color(0xFFE2E8F0)), // slate-200
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)), // slate-300
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
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
