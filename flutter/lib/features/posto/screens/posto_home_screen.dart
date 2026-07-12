import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/widgets/menu_button.dart';

// Fase FLT-1 — shell da visão Posto, espelhando a estrutura de menu de
// menuPostoGestao + menuPostoOperacao em src/app/(dashboard)/layout.tsx da
// web (mesma ordem/seções: "Gestão" primeiro, "Operação" depois). Cada item
// aqui ainda aponta pra uma tela placeholder (EmConstrucaoScreen) — as telas
// de verdade entram uma a uma na Fase FLT-2 (ver lista de tarefas).
class PostoHomeScreen extends ConsumerWidget {
  final Widget child;
  const PostoHomeScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).matchedLocation;
    final sessao = ref.watch(sessaoProvider);

    return Scaffold(
      key: rootScaffoldKey,
      drawer: _buildDrawer(context, ref, sessao.valueOrNull?.nomeEmpresa),
      appBar: AppBar(
        title: const Text('FNI — Posto'),
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx(loc),
        onDestinationSelected: (i) => _nav(context, i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Painel'),
          NavigationDestination(icon: Icon(Icons.handshake), label: 'Negoc.'),
          NavigationDestination(icon: Icon(Icons.local_gas_station), label: 'Abastec.'),
          NavigationDestination(icon: Icon(Icons.attach_money), label: 'Financ.'),
          NavigationDestination(icon: Icon(Icons.menu), label: 'Mais'),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref, String? nomeEmpresa) => Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF0D2D6B)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('FNI — Posto',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  if (nomeEmpresa != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(nomeEmpresa, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ),
                ],
              ),
            ),
            _grp('Gestão'),
            _item(context, Icons.dashboard, 'Dashboard', '/posto'),
            _item(context, Icons.place, 'Meu Posto', '/posto/meu-posto'),
            _item(context, Icons.hub, 'Rede de Postos', '/posto/rede-postos'),
            _item(context, Icons.smart_toy, 'Assistente FNI', '/posto/assistente'),
            _item(context, Icons.credit_card, 'Minha Assinatura', '/posto/assinatura'),
            _item(context, Icons.star, 'Avaliar Plataforma', '/posto/avaliar'),
            _item(context, Icons.attach_money, 'Financeiro', '/posto/financeiro'),
            _item(context, Icons.lock, 'Privacidade (LGPD)', '/posto/lgpd'),
            _item(context, Icons.account_balance, 'Meus Dados / PIX', '/posto/meus-dados'),
            _item(context, Icons.folder, 'Documentos', '/posto/documentos'),
            _item(context, Icons.people, 'Usuários', '/posto/usuarios'),
            const Divider(),
            _grp('Operação'),
            _item(context, Icons.handshake, 'Negociações', '/posto/negociacoes'),
            _item(context, Icons.local_gas_station, 'Abastecimentos', '/posto/abastecimentos'),
            _item(context, Icons.business, 'Clientes', '/posto/clientes'),
            _item(context, Icons.sell, 'Meus Preços', '/posto/precos'),
            _item(context, Icons.description, 'Notas Fiscais', '/posto/notas-fiscais'),
            _item(context, Icons.power, 'Integrações', '/posto/integracoes'),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sair', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await AuthService().signOut();
                ref.invalidate(sessaoProvider);
                ref.invalidate(empresaSelecionadaProvider);
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
      );

  Widget _grp(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
      );

  ListTile _item(BuildContext context, IconData icon, String label, String route) => ListTile(
        dense: true,
        leading: Icon(icon, color: const Color(0xFF0D2D6B), size: 20),
        title: Text(label, style: const TextStyle(fontSize: 14)),
        onTap: () {
          Navigator.pop(context);
          context.go(route);
        },
      );

  int _idx(String loc) {
    if (loc.startsWith('/posto/negociacoes')) return 1;
    if (loc.startsWith('/posto/abastecimentos')) return 2;
    if (loc.startsWith('/posto/financeiro')) return 3;
    if (loc == '/posto') return 0;
    return 4; // qualquer outra tela do drawer conta como "Mais"
  }

  void _nav(BuildContext ctx, int i) {
    switch (i) {
      case 0:
        ctx.go('/posto');
        break;
      case 1:
        ctx.go('/posto/negociacoes');
        break;
      case 2:
        ctx.go('/posto/abastecimentos');
        break;
      case 3:
        ctx.go('/posto/financeiro');
        break;
      case 4:
        rootScaffoldKey.currentState?.openDrawer();
        break;
    }
  }
}
