import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../auth/screens/login_screen.dart';
import '../../../core/services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  final Widget child;
  const HomeScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    return Scaffold(
      appBar: null,
      drawer: _buildDrawer(context, loc),
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

  Widget _buildDrawer(BuildContext context, String loc) => Drawer(
    child: ListView(padding: EdgeInsets.zero, children: [
      const DrawerHeader(
        decoration: BoxDecoration(color: Color(0xFF0D2D6B)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
          Icon(Icons.local_shipping, color: Colors.white, size: 36),
          SizedBox(height: 8),
          Text('FNI Gestão de Frotas', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
      ),
      _drawerItem(context, Icons.dashboard,         'Dashboard',        '/'),
      _drawerItem(context, Icons.local_gas_station, 'Abastecimentos',   '/abastecimentos'),
      _drawerItem(context, Icons.directions_car,    'Frota',            '/frota'),
      _drawerItem(context, Icons.build,             'Manutenção',       '/manutencao'),
      _drawerItem(context, Icons.attach_money,      'Financeiro',       '/financeiro'),
      const Divider(),
      _drawerItem(context, Icons.psychology,        'Inteligência',     '/inteligencia'),
      _drawerItem(context, Icons.trending_up,       'Variação de Preços','/precos'),
      _drawerItem(context, Icons.description,       'Relatórios',       '/relatorios'),
      const Divider(),
      _drawerItem(context, Icons.support_agent,     'Suporte',          '/tickets'),
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

  ListTile _drawerItem(BuildContext context, IconData icon, String label, String route) => ListTile(
    leading: Icon(icon, color: const Color(0xFF0D2D6B)),
    title: Text(label),
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
