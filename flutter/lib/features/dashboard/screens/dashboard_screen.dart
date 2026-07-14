import 'package:flutter/material.dart';
import 'abas/aba_indicadores_avancados.dart';
import 'abas/aba_visao_geral.dart';

// Fase FLT-6 — Dashboard vira 2 abas: "Visão Geral" (o que já existia mais
// Ajustes de Abastecimento, Centro de Custo, Manutenção Preditiva e
// Primeiros Passos) e "Indicadores Avançados" (os 8 gráficos por
// período — seletor de mês próprio). Mesmo padrão de TabBar branca sobre
// AppBar azul já usado em Inteligência de Rede (ver comentário lá sobre o
// achado do Daniel: sem cores explícitas, a aba selecionada ficava cinza,
// baixo contraste).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            // Achado real (reportado pelo Daniel com print, mesmo problema
            // corrigido em inteligencia_rede_screen.dart): `colorScheme.primary`
            // vem de `ColorScheme.fromSeed()` (AppTheme) e NÃO é o mesmo tom
            // exato do navy usado no AppBar/menu — fixado com a cor literal
            // (AppTheme._primary, 0xFF0D2D6B) pra bater 100% com o resto do app.
            color: const Color(0xFF0D2D6B),
            child: const TabBar(
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(text: 'Visão Geral'),
                Tab(text: 'Indicadores Avançados'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                AbaVisaoGeral(),
                AbaIndicadoresAvancados(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
