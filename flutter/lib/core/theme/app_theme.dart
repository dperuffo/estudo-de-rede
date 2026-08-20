import 'package:flutter/material.dart';

class AppTheme {
  static const _primary = Color(0xFF0D2D6B);
  static const _accent = Color(0xFF00B4D8);
  // Achado real (reportado pelo Daniel): a barra do topo (AppBarTheme,
  // usada em toda tela) e o menu/drawer (cabeçalho em home_screen.dart)
  // usavam 2 navies diferentes — `_primary` (0xFF0D2D6B, mais "azul vivo")
  // na AppBar contra 0xFF0B1220 (mais escuro/preto-azulado) no cabeçalho do
  // drawer. Pedido do Daniel: a barra do topo tem que usar a MESMA cor do
  // menu — `_menu` abaixo é literalmente o mesmo valor hardcoded do
  // Container do cabeçalho do Drawer (ver home_screen.dart:69).
  static const _menu = Color(0xFF0B1220);

  // Fase Liquid-Glass-PWA (20/08/2026, pedido do Daniel: aplicar nos PWAs
  // cliente e motorista o mesmo liquid glass ja feito na web) - mesma
  // paleta do menu lateral web (ver globals.css: .glass-nav/.glass-nav-*/
  // .glass-tab-ativa). Diferente do CSS, o Flutter nao tem
  // "backdrop-filter" aplicavel via Theme a qualquer widget - o efeito
  // vidro aqui vem da combinacao gradiente + opacidade + borda clara +
  // sombra suave, sem desfoque literal. Mesma linguagem visual da web, sem
  // o blur que o framework nao oferece de graca nesses pontos.
  //
  // Fase Liquid-Glass-Anel (20/08/2026, pedido do Daniel: "o cinza anterior
  // nao ficou bom" - 3a imagem de referencia: fundo quase preto
  // azul-marinho, com um anel de luz azul-violeta brilhando so do lado
  // esquerdo, tipo borda de esfera/portal) - troca a paleta cinza da fase
  // anterior por esta nova, extraida por amostragem de pixel da imagem.
  // Nomes das constantes mantidos (glassBronze*) por estabilidade - so o
  // valor de cor mudou. O CSS da web usa varias camadas de
  // radial-gradient pro anel (background: layer1, layer2, ...), mas o
  // Flutter so aceita 1 gradient por BoxDecoration - por isso aqui e um
  // UNICO RadialGradient com centro fora da tela (Alignment(-1.8, 0)) e
  // paradas (stops) que criam transparent->brilho->transparent, o mesmo
  // truque de "buraco no meio" que faz so a BORDA do circulo aparecer.
  static const Color glassBronzeClaro = Color(0xFF2A2A45);
  static const Color glassBronzeMedio = Color(0xFF1C1B2F);
  static const Color glassBronzeEscuro = Color(0xFF10101F);
  static const Color glassBrilho = Color(0xFF999ED9);
  static const Color glassBrilhoMedio = Color(0xFF8D94CA);
  static const Color glassTexto = Color(0xFFF5F5FA);
  static const Color glassTextoMuted = Color(0xFFA5A6C4);
  static const Color glassIcone = Color(0xFFE8E9F5);
  static const Color glassAcento = Color(0xFFFFD9A0);
  // Mesmos tons do preenchimento "aba ativa" da web (.glass-tab-ativa:
  // linear-gradient(#a7ade0, #6b70a8), texto #14132a) - usado no indicador
  // das TabBar (Dashboard/Inteligencia de Rede) e no item selecionado da
  // NavigationBar inferior.
  static const Color glassPillClaro = Color(0xFFA7ADE0);
  static const Color glassPillEscuro = Color(0xFF6B70A8);
  static const Color glassTextoAtivo = Color(0xFF14132A);

  static const Gradient glassNavGradient = RadialGradient(
    center: Alignment(-1.8, 0.0),
    radius: 1.3,
    colors: [
      glassBronzeMedio,
      glassBronzeMedio,
      glassBrilhoMedio,
      glassBrilho,
      glassBronzeEscuro,
      glassBronzeClaro,
    ],
    stops: [0.0, 0.55, 0.6, 0.64, 0.7, 1.0],
  );

  static const LinearGradient glassPillGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [glassPillClaro, glassPillEscuro],
  );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme:
            ColorScheme.fromSeed(seedColor: _primary, secondary: _accent),
        appBarTheme: const AppBarTheme(
            backgroundColor: _menu,
            foregroundColor: Colors.white,
            elevation: 0),
        // Fase Liquid-Glass-PWA (20/08/2026) - Card e usado em dezenas de telas
        // (dashboard, indicadores, listas) sem nenhum estilo proprio (cada uma
        // so chamava `Card(child: ...)`, dependendo do visual padrao do
        // Material). Como e um unico ponto central (igual ao `.card` do
        // globals.css na web), da pra dar o efeito vidro (translucido + borda
        // clara + sombra suave) em TODA tela que usa Card de uma vez so, sem
        // editar arquivo por arquivo.
        cardTheme: CardThemeData(
          elevation: 1,
          color: Colors.white.withOpacity(0.82),
          surfaceTintColor: Colors.transparent,
          shadowColor: _menu.withOpacity(0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.white.withOpacity(0.7)),
          ),
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
