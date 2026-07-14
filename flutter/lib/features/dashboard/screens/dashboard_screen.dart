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
            color: Theme.of(context).colorScheme.primary,
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
