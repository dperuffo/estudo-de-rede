import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/selecionar_empresa_screen.dart';
import '../../features/mfa/screens/mfa_pendente_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/posto/screens/posto_home_screen.dart';
import '../../features/posto/screens/posto_dashboard_screen.dart';
import '../../features/posto/screens/meu_posto_screen.dart';
import '../../features/posto/screens/negociacoes_screen.dart';
import '../../features/posto/screens/negociacao_detalhe_screen.dart';
import '../../features/posto/screens/criar_negociacao_screen.dart';
import '../../features/posto/screens/abastecimentos_posto_screen.dart';
import '../../features/posto/screens/abastecimento_detalhe_screen.dart';
import '../../features/posto/screens/clientes_posto_screen.dart';
import '../../features/posto/screens/cliente_posto_detalhe_screen.dart';
import '../../features/posto/screens/fatura_posto_detalhe_screen.dart';
import '../../features/posto/screens/ciclo_aberto_detalhe_screen.dart';
import '../../features/posto/screens/precos_posto_screen.dart';
import '../../features/posto/screens/rede_postos_screen.dart';
import '../../features/posto/screens/nova_rede_screen.dart';
import '../../features/posto/screens/assistente_screen.dart';
import '../../features/posto/screens/assinatura_screen.dart';
import '../../features/posto/screens/avaliar_screen.dart';
import '../../features/posto/screens/financeiro_posto_screen.dart';
import '../../features/posto/screens/lgpd_screen.dart';
import '../../features/posto/screens/meus_dados_screen.dart';
import '../../features/posto/screens/documentos_screen.dart';
import '../../features/posto/screens/usuarios_screen.dart';
import '../../features/posto/screens/usuario_novo_screen.dart';
import '../../features/posto/screens/usuario_editar_screen.dart';
import '../../features/posto/screens/chamados_posto_screen.dart';
import '../../features/posto/screens/chamado_novo_screen.dart';
import '../../features/posto/screens/chamado_detalhe_screen.dart';
import '../widgets/em_construcao_screen.dart';
import '../services/auth_service.dart';
import '../services/sessao_provider.dart';

// Fase FLT-1 — pedido do Daniel: "dependendo de quem acessa o PWA será
// direcionado para o seu perfil". O redirect agora tem 3 camadas, na mesma
// ordem da web (ver src/app/(dashboard)/layout.tsx):
//   1. Sessão (logado ou não) — igual já existia.
//   2. MFA obrigatório (novo — mesmo gate do layout.tsx da web).
//   3. Perfil — "posto" vai pro shell próprio (/posto/...); qualquer outro
//      perfil logado (cliente ou admin) continua no shell genérico (/...).
//      A separação de admin/cliente DENTRO desse shell genérico (hoje
//      qualquer perfil "não-posto" vê o mesmo menu) segue fora de escopo
//      por ora — decisão do Daniel ao iniciar a Fase FLT-3, mesmo espírito
//      da decisão original aqui: só garantir que quem é posto NUNCA cai
//      nas telas de frota/cliente e vice-versa.
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

        // Camada 3 — empresa atual (achado real: Rede de Postos/grupo
        // econômico com 2+ empresas vinculadas não pode escolher sozinho
        // qual é "a atual" — ver comentário em sessao_provider.dart).
        final sessao = await ref.read(sessaoProvider.future);
        if (sessao.precisaEscolherEmpresa) {
          return loc == '/selecionar-empresa' ? null : '/selecionar-empresa';
        }
        // Pedido do Daniel — seletor de "trocar empresa" acessível a
        // qualquer momento (não só no gate inicial), pra quem tem 2+
        // postos na Rede de Postos poder alternar entre eles. Só bloqueia
        // acesso voluntário à tela quando não há nada pra escolher (conta
        // de 1 empresa só) — nesse caso não faz sentido a tela existir.
        // O `return null` (em vez de só deixar cair pra Camada 4) é
        // necessário: sem ele, a Camada 4 abaixo redireciona o posto de
        // volta pra /posto por essa rota não começar com "/posto".
        if (loc == '/selecionar-empresa') {
          return sessao.empresasIds.length <= 1 ? '/' : null;
        }

        // Camada 4 — perfil (posto x demais).
        final estaEmRotaPosto = loc.startsWith('/posto');
        if (sessao.ehPosto && !estaEmRotaPosto) return '/posto';
        if (!sessao.ehPosto && estaEmRotaPosto) return '/';

        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/mfa-pendente', builder: (_, __) => const MfaPendenteScreen()),
        GoRoute(path: '/selecionar-empresa', builder: (_, __) => const SelecionarEmpresaScreen()),

        // Fase FLT-3 — shell da visão Cliente, reescrito do zero (ver
        // comentário completo em home_screen.dart: as 18 telas antigas
        // usavam um backend Python legado com auth quebrada). "/" e
        // "/dashboard" apontam pro mesmo Dashboard real (a web não tem uma
        // landing separada tipo "Comece seu dia" pra cliente — cai direto
        // no /dashboard). Todo o resto é placeholder até virar tela de
        // verdade, uma de cada vez (ver lista de tarefas FLT-3).
        ShellRoute(
          builder: (c, s, child) => HomeScreen(child: child),
          routes: [
            GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
            GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
            GoRoute(path: '/assistente', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Assistente FNI')),
            GoRoute(path: '/assinatura', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Minha Assinatura')),
            GoRoute(path: '/avaliar', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Avaliar Plataforma')),
            GoRoute(path: '/financeiro', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Painel Financeiro')),
            GoRoute(path: '/documentos', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Documentos')),
            GoRoute(path: '/inteligencia-rede', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Inteligência de Rede')),
            GoRoute(path: '/lgpd', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Privacidade (LGPD)')),
            GoRoute(path: '/chamados', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Chamados')),
            GoRoute(path: '/clientes', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Clientes')),
            GoRoute(path: '/grupo-economico', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Grupo Econômico')),
            GoRoute(path: '/usuarios', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Usuários')),
            GoRoute(path: '/motoristas', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Motoristas')),
            GoRoute(path: '/veiculos', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Veículos')),
            GoRoute(path: '/centros-custo', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Centros de Custo')),
            GoRoute(path: '/postos', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Postos Revendedores')),
            GoRoute(path: '/abastecimentos', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Abastecimentos')),
            GoRoute(path: '/notas-fiscais', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Notas Fiscais')),
            GoRoute(path: '/anomalias', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Anomalias')),
            GoRoute(path: '/roteirizacao', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Roteirização')),
            GoRoute(path: '/rotograma', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Rotograma')),
            GoRoute(path: '/planos-viagem', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Planos de Viagem')),
            GoRoute(path: '/negociacoes', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Negociações com Postos')),
            GoRoute(path: '/precos-postos', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Preços dos Postos Parceiros')),
            GoRoute(path: '/manutencao-preditiva', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Manutenção Preditiva')),
            GoRoute(path: '/parametros-uso', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Parâmetros de Uso')),
            GoRoute(path: '/relatorios', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Relatórios')),
            GoRoute(path: '/integracoes', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Integrações')),
            GoRoute(path: '/permissoes', builder: (_, __) => const EmConstrucaoScreen(titulo: 'Permissões')),
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
            GoRoute(path: '/posto/meu-posto', builder: (_, __) => const MeuPostoScreen()),
            GoRoute(path: '/posto/rede-postos', builder: (_, __) => const RedePostosScreen()),
            GoRoute(path: '/posto/rede-postos/nova', builder: (_, __) => const NovaRedeScreen()),
            GoRoute(path: '/posto/assistente', builder: (_, __) => const AssistentePostoScreen()),
            GoRoute(path: '/posto/assinatura', builder: (_, __) => const AssinaturaScreen()),
            GoRoute(path: '/posto/avaliar', builder: (_, __) => const AvaliarScreen()),
            GoRoute(path: '/posto/financeiro', builder: (_, __) => const FinanceiroPostoScreen()),
            GoRoute(path: '/posto/lgpd', builder: (_, __) => const LgpdScreen()),
            GoRoute(path: '/posto/meus-dados', builder: (_, __) => const MeusDadosScreen()),
            GoRoute(path: '/posto/documentos', builder: (_, __) => const DocumentosScreen()),
            GoRoute(path: '/posto/usuarios', builder: (_, __) => const UsuariosScreen()),
            GoRoute(path: '/posto/usuarios/novo', builder: (_, __) => const UsuarioNovoScreen()),
            GoRoute(
              path: '/posto/usuarios/:email',
              builder: (_, state) =>
                  UsuarioEditarScreen(email: Uri.decodeComponent(state.pathParameters['email']!)),
            ),
            GoRoute(path: '/posto/negociacoes', builder: (_, __) => const NegociacoesScreen()),
            GoRoute(path: '/posto/negociacoes/novo', builder: (_, __) => const CriarNegociacaoScreen()),
            GoRoute(
              path: '/posto/negociacoes/:id',
              builder: (_, state) => NegociacaoDetalheScreen(id: state.pathParameters['id']!),
            ),
            GoRoute(path: '/posto/abastecimentos', builder: (_, __) => const AbastecimentosPostoScreen()),
            GoRoute(
              path: '/posto/abastecimentos/:chave',
              builder: (_, state) => AbastecimentoDetalheScreen(chave: state.pathParameters['chave']!),
            ),
            GoRoute(path: '/posto/clientes', builder: (_, __) => const ClientesPostoScreen()),
            GoRoute(
              path: '/posto/clientes/:id',
              builder: (_, state) => ClientePostoDetalheScreen(id: state.pathParameters['id']!),
            ),
            GoRoute(
              path: '/posto/faturas/:id',
              builder: (_, state) => FaturaPostoDetalheScreen(id: state.pathParameters['id']!),
            ),
            GoRoute(
              path: '/posto/ciclos-abertos/:negociacaoId',
              builder: (_, state) => CicloAbertoDetalheScreen(negociacaoId: state.pathParameters['negociacaoId']!),
            ),
            GoRoute(path: '/posto/precos', builder: (_, __) => const PrecosPostoScreen()),
            GoRoute(path: '/posto/chamados', builder: (_, __) => const ChamadosPostoScreen()),
            GoRoute(path: '/posto/chamados/novo', builder: (_, __) => const ChamadoNovoScreen()),
            GoRoute(
              path: '/posto/chamados/:id',
              builder: (_, state) => ChamadoDetalheScreen(id: state.pathParameters['id']!),
            ),
          ],
        ),
      ],
    ));
