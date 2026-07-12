import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/mfa/screens/mfa_pendente_screen.dart';
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
import '../../features/analise_cliente/screens/analise_cliente_screen.dart';
import '../../features/tickets/screens/tickets_screen.dart';
import '../../features/admin/screens/admin_screen.dart';
import '../../features/avaliacao/screens/avaliacao_screen.dart';
import '../../features/acordos/screens/acordos_screen.dart';
import '../../features/roteirizacao/screens/roteirizacao_screen.dart';
import '../../features/assistente/screens/assistente_screen.dart';
import '../../features/centros_custo/screens/centros_custo_screen.dart';
import '../../features/posto/screens/posto_home_screen.dart';
import '../../features/posto/screens/posto_dashboard_screen.dart';
import '../widgets/em_construcao_screen.dart';
import '../services/auth_service.dart';
import '../services/sessao_provider.dart';

// Fase FLT-1 — pedido do Daniel: "dependendo de quem acessa o PWA será
// direcionado para o seu perfil". O redirect agora tem 3 camadas, na mesma
// ordem da web (ver src/app/(dashboard)/layout.tsx):
//   1. Sessão (logado ou não) — igual já existia.
//   2. MFA obrigatório (novo — mesmo gate do layout.tsx da web).
//   3. Perfil — "posto" vai pro shell próprio (/posto/...); qualquer outro
//      perfil logado (cliente ou admin) continua no shell genérico que já
//      existia (/...). A separação de admin/cliente dentro desse shell
//      genérico fica pra uma fase futura (FLT-3) — por ora só garantimos
//      que quem é posto NUNCA cai nas telas de frota/cliente e vice-versa.
final appRouterProvider = Provider<GoRouter>((ref) => GoRouter(
      initialLocation: '/',
      redirect: (context, state) async {
        final loc = state.matchedLocation;
        final loggedIn = AuthService().isLoggedIn;

        if (!loggedIn) {
          return loc == '/login' ? null : '/login';
        }
        if (loc == '/login') return '/';

        // Camada 2 — MFA.
        final precisaMfa = await AuthService().precisaConfigurarOuVerificarMfa();
        if (precisaMfa) {
          return loc == '/mfa-pendente' ? null : '/mfa-pendente';
        }
        if (loc == '/mfa-pendente') return '/';

        // Camada 3 — perfil (posto x demais).
        final sessao = await ref.read(sessaoProvider.future);
        final estaEmRotaPosto = loc.startsWith('/posto');
        if (sessao.ehPosto && !estaEmRotaPosto) return '/posto';
        if (!sessao.ehPosto && estaEmRotaPosto) return '/';

        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/mfa-pendente', builder: (_, __) => const MfaPendenteScreen()),

        // Shell genérico (cliente/admin) — inalterado nesta fase, além da
        // proteção de rota acima.
        ShellRoute(
          builder: (c, s, child) => HomeScreen(child: child),
          routes: [
            GoRoute(path: '/', builder: (_, __) => const ComeceSeuDiaScreen()),
            GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
            GoRoute(path: '/abastecimentos', builder: (_, __) => const AbastecimentosScreen()),
            GoRoute(path: '/frota', builder: (_, __) => const FrotaScreen()),
            GoRoute(path: '/veiculos', builder: (_, __) => const VeiculosScreen()),
            GoRoute(path: '/manutencao', builder: (_, __) => const ManutencaoScreen()),
            GoRoute(path: '/financeiro', builder: (_, __) => const FinanceiroScreen()),
            GoRoute(path: '/inteligencia', builder: (_, __) => const InteligenciaScreen()),
            GoRoute(path: '/precos', builder: (_, __) => const PrecosScreen()),
            GoRoute(path: '/relatorios', builder: (_, __) => const RelatoriosScreen()),
            GoRoute(path: '/analise-cliente', builder: (_, __) => const AnaliseClienteScreen()),
            GoRoute(path: '/tickets', builder: (_, __) => const TicketsScreen()),
            GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
            GoRoute(path: '/avaliacao', builder: (_, __) => const AvaliacaoScreen()),
            GoRoute(path: '/acordos', builder: (_, __) => const AcordosScreen()),
            GoRoute(path: '/roteirizacao', builder: (_, __) => const RoteirizacaoScreen()),
            GoRoute(path: '/assistente', builder: (_, __) => const AssistenteScreen()),
            GoRoute(path: '/centros-custo', builder: (_, __) => const CentrosCustoScreen()),
          ],
        ),

        // Fase FLT-1 — shell da visão Posto (novo). Telas ainda placeholder
        // (EmConstrucaoScreen) — cada uma vira uma tela de verdade na Fase
        // FLT-2, uma por vez (ver lista de tarefas). Fase FLT-2: /posto
        // (Dashboard) já é real — ver posto_dashboard_screen.dart.
        ShellRoute(
          builder: (c, s, child) => PostoHomeScreen(child: child),
          routes: [
            GoRoute(path: '/posto', builder: (_, __) => const PostoDashboardScreen()),
            GoRoute(path: '/posto/meu-posto', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Meu Posto')),
            GoRoute(path: '/posto/rede-postos', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Rede de Postos')),
            GoRoute(path: '/posto/assistente', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Assistente FNI')),
            GoRoute(path: '/posto/assinatura', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Minha Assinatura')),
            GoRoute(path: '/posto/avaliar', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Avaliar Plataforma')),
            GoRoute(path: '/posto/financeiro', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Financeiro')),
            GoRoute(path: '/posto/lgpd', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Privacidade (LGPD)')),
            GoRoute(path: '/posto/meus-dados', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Meus Dados / PIX')),
            GoRoute(path: '/posto/documentos', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Documentos')),
            GoRoute(path: '/posto/usuarios', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Usuários')),
            GoRoute(path: '/posto/negociacoes', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Negociações')),
            GoRoute(path: '/posto/abastecimentos', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Abastecimentos')),
            GoRoute(path: '/posto/clientes', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Clientes')),
            GoRoute(path: '/posto/precos', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Meus Preços')),
            GoRoute(path: '/posto/notas-fiscais', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Notas Fiscais')),
            GoRoute(path: '/posto/integracoes', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Integrações')),
          ],
        ),
      ],
    ));
