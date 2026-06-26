import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  final Widget child;
  const HomeScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx(loc),
        onDestinationSelected: (i) => _nav(context, i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.local_gas_station), label: 'Abastec.'),
          NavigationDestination(icon: Icon(Icons.directions_car),    label: 'Frota'),
          NavigationDestination(icon: Icon(Icons.build),             label: 'Manutenção'),
          NavigationDestination(icon: Icon(Icons.attach_money),      label: 'Financeiro'),
          NavigationDestination(icon: Icon(Icons.support_agent),     label: 'Suporte'),
        ],
      ),
    );
  }

  int _idx(String loc) {
    if (loc.startsWith('/frota'))      return 1;
    if (loc.startsWith('/manutencao')) return 2;
    if (loc.startsWith('/financeiro')) return 3;
    if (loc.startsWith('/tickets'))    return 4;
    return 0;
  }

  void _nav(BuildContext ctx, int i) {
    switch (i) {
      case 0: ctx.go('/');            break;
      case 1: ctx.go('/frota');       break;
      case 2: ctx.go('/manutencao');  break;
      case 3: ctx.go('/financeiro');  break;
      case 4: ctx.go('/tickets');     break;
    }
  }
}
