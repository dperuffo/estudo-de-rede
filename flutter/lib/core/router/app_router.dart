import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/abastecimentos/screens/abastecimentos_screen.dart';
import '../../features/frota/screens/frota_screen.dart';
import '../../features/financeiro/screens/financeiro_screen.dart';
import '../../features/tickets/screens/tickets_screen.dart';
import '../../features/manutencao/screens/manutencao_screen.dart';
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
        GoRoute(path: '/',            builder: (_, __) => const AbastecimentosScreen()),
        GoRoute(path: '/frota',       builder: (_, __) => const FrotaScreen()),
        GoRoute(path: '/manutencao',  builder: (_, __) => const ManutencaoScreen()),
        GoRoute(path: '/financeiro',  builder: (_, __) => const FinanceiroScreen()),
        GoRoute(path: '/tickets',     builder: (_, __) => const TicketsScreen()),
      ],
    ),
  ],
));
