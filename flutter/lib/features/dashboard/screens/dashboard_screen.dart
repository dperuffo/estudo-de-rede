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
            // Achado real (reportado pelo Daniel, 2 rodadas): 1ª causa
            // (`colorScheme.primary` vem de `ColorScheme.fromSeed()` e não é
            // o mesmo tom do navy do AppBar) corrigida com cor literal; 2ª
            // causa (pedido do Daniel: a barra do topo tem que usar a MESMA
            // cor do MENU) corrigida usando `AppTheme._menu` (0xFF0B1220 —
            // mesmo hex do cabeçalho do Drawer em home_screen.dart), que
            // agora também é o `appBarTheme.backgroundColor` padrão do app
            // inteiro (ver app_theme.dart).
            color: const Color(0xFF0B1220),
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
