import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/menu_button.dart';

class HomeScreen extends StatelessWidget {
  final Widget child;
  const HomeScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    return Scaffold(
      key: rootScaffoldKey,
      drawer: _buildDrawer(context),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx(loc),
        onDestinationSelected: (i) => _nav(context, i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard),         label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.local_gas_station), label: 'Abastec.'),
          NavigationDestination(icon: Icon(Icons.directions_car),    label: 'Frota'),
          NavigationDestination(icon: Icon(Icons.attach_money),      label: 'Financeiro'),
          NavigationDestination(icon: Icon(Icons.support_agent),     label: 'Suporte'),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) => Drawer(
    child: ListView(padding: EdgeInsets.zero, children: [
      const DrawerHeader(
        decoration: BoxDecoration(color: Color(0xFF0D2D6B)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.local_shipping, color: Colors.white, size: 36),
            SizedBox(height: 8),
            Text('FNI Gestao de Frotas',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      _grp('Gestao da Frota'),
      _item(context, Icons.dashboard,         'Dashboard',          '/'),
      _item(context, Icons.local_gas_station, 'Abastecimentos',     '/abastecimentos'),
      _item(context, Icons.directions_car,    'Frota',              '/frota'),
      _item(context, Icons.build,             'Manutencao',         '/manutencao'),
      _item(context, Icons.attach_money,      'Financeiro',         '/financeiro'),
      _item(context, Icons.business,          'Centros de Custo',   '/centros-custo'),
      _item(context, Icons.handshake,         'Acordos de Preco',   '/acordos'),
      const Divider(),
      _grp('Analise e Inteligencia'),
      _item(context, Icons.psychology,        'Inteligencia',       '/inteligencia'),
      _item(context, Icons.trending_up,       'Variacao de Precos', '/precos'),
      _item(context, Icons.description,       'Relatorios',         '/relatorios'),
      _item(context, Icons.smart_toy,         'Assistente IA',      '/assistente'),
      const Divider(),
      _grp('Rede de Postos'),
      _item(context, Icons.route,             'Roteirizacao',       '/roteirizacao'),
      const Divider(),
      _item(context, Icons.support_agent,     'Suporte',            '/tickets'),
      _item(context, Icons.admin_panel_settings, 'Admin',           '/admin'),
      const Divider(),
      ListTile(
        leading: const Icon(Icons.logout, color: Colors.red),
        title: const Text('Sair', style: TextStyle(color: Colors.red)),
        onTap: () async {
          await AuthService().signOut();
          if (context.mounted) context.go('/login');
        },
      ),
    ]),
  );

  Widget _grp(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
  );

  ListTile _item(BuildContext context, IconData icon, String label, String route) => ListTile(
    dense: true,
    leading: Icon(icon, color: const Color(0xFF0D2D6B), size: 20),
    title: Text(label, style: const TextStyle(fontSize: 14)),
    onTap: () { Navigator.pop(context); context.go(route); },
  );

  int _idx(String loc) {
    if (loc.startsWith('/abastecimentos')) return 1;
    if (loc.startsWith('/frota'))          return 2;
    if (loc.startsWith('/financeiro'))     return 3;
    if (loc.startsWith('/tickets'))        return 4;
    return 0;
  }

  void _nav(BuildContext ctx, int i) {
    switch (i) {
      case 0: ctx.go('/');               break;
      case 1: ctx.go('/abastecimentos'); break;
      case 2: ctx.go('/frota');          break;
      case 3: ctx.go('/financeiro');     break;
      case 4: ctx.go('/tickets');        break;
    }
  }
}
