import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
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
          // Fase Liquid-Glass-PWA (20/08/2026, pedido do Daniel: "implementar
          // estas mudanças nos PWAs cliente e motorista") — mesma superfície
          // bronze/champanhe do menu, com a aba ativa virando um "pill" claro
          // (mesma receita do .glass-tab-ativa na web), em vez do sublinhado
          // branco sobre navy.
          Container(
            decoration: const BoxDecoration(gradient: AppTheme.glassNavGradient),
            child: Material(
              color: Colors.transparent,
              child: TabBar(
                indicator: BoxDecoration(
                  gradient: AppTheme.glassPillGradient,
                  borderRadius: BorderRadius.circular(999),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                labelColor: AppTheme.glassTextoAtivo,
                unselectedLabelColor: AppTheme.glassTextoMuted,
                tabs: const [
                  Tab(text: 'Visão Geral'),
                  Tab(text: 'Indicadores Avançados'),
                ],
              ),
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
