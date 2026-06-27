import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/comece_seu_dia/screens/comece_seu_dia_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/abastecimentos/screens/abastecimentos_screen.dart';
import '../../features/frota/screens/frota_screen.dart';
import '../../features/frota/screens/veiculos_screen.dart';
import '../../features/manutencao/screens/manutencao_screen.dart';
import '../../features/financeiro/screens/financeiro_screen.dart';
import '../../features/inteligencia/screens/inteligencia_screen.dart';
import '../../features/precos/screens/precos_screen.dart';
import '../../features/relatorios/screens/relatorios_screen.dart';
import '../../features/tickets/screens/tickets_screen.dart';
import '../../features/admin/screens/admin_screen.dart';
import '../../features/acordos/screens/acordos_screen.dart';
import '../../features/roteirizacao/screens/roteirizacao_screen.dart';
import '../../features/assistente/screens/assistente_screen.dart';
import '../../features/centros_custo/screens/centros_custo_screen.dart';
import '../services/auth_service.dart';

final appRouterProvider = Provider<GoRouter>((ref) => GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    final ok = await AuthService().isLoggedIn();
    if (!ok && state.matchedLocation != '/login') return '/login';
    if (ok  && state.matchedLocation == '/login') return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    ShellRoute(
      builder: (c, s, child) => HomeScreen(child: child),
      routes: [
        GoRoute(path: '/',                builder: (_, __) => const ComeceSeuDiaScreen()),
        GoRoute(path: '/dashboard',       builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/abastecimentos',  builder: (_, __) => const AbastecimentosScreen()),
        GoRoute(path: '/frota',           builder: (_, __) => const FrotaScreen()),
        GoRoute(path: '/veiculos',         builder: (_, __) => const VeiculosScreen()),
        GoRoute(path: '/manutencao',      builder: (_, __) => const ManutencaoScreen()),
        GoRoute(path: '/financeiro',      builder: (_, __) => const FinanceiroScreen()),
        GoRoute(path: '/inteligencia',    builder: (_, __) => const InteligenciaScreen()),
        GoRoute(path: '/precos',          builder: (_, __) => const PrecosScreen()),
        GoRoute(path: '/relatorios',      builder: (_, __) => const RelatoriosScreen()),
        GoRoute(path: '/tickets',         builder: (_, __) => const TicketsScreen()),
        GoRoute(path: '/admin',           builder: (_, __) => const AdminScreen()),
        GoRoute(path: '/acordos',         builder: (_, __) => const AcordosScreen()),
        GoRoute(path: '/roteirizacao',    builder: (_, __) => const RoteirizacaoScreen()),
        GoRoute(path: '/assistente',      builder: (_, __) => const AssistenteScreen()),
        GoRoute(path: '/centros-custo',   builder: (_, __) => const CentrosCustoScreen()),
      ],
    ),
  ],
));
