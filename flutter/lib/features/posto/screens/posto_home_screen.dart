import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/notificacoes_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/sessao_usuario.dart';
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
      drawer: _buildDrawer(context, ref, sessao.valueOrNull),
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

  Widget _buildDrawer(BuildContext context, WidgetRef ref, SessaoUsuario? sessao) {
    final nomeEmpresa = sessao?.nomeEmpresa;
    // Fase FLT-2 — pedido do Daniel: seletor pra alternar entre os postos
    // da Rede de Postos (grupo econômico) a qualquer momento, não só no
    // gate inicial (ver "Camada 3" em app_router.dart) — só faz sentido
    // pra quem tem 2+ empresas vinculadas.
    final temMultiplasEmpresas = (sessao?.empresasIds.length ?? 0) > 1;
    // Fase FLT-7 — mesmas bolinhas de notificação da web, ver
    // notificacoes_provider.dart.
    final badges = ref.watch(notificacoesBadgesProvider).valueOrNull ?? NotificacoesBadges.vazio;
    return Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Fase FLT-2 — pedido do Daniel: mesma identidade visual da
            // sidebar da web (src/app/(dashboard)/layout.tsx): fundo
            // `frota-950` (#0B1220, não o azul genérico usado antes), logo
            // dentro de um card branco 95% opaco com cantos arredondados
            // (a imagem `assets/logo_fni.png` agora é a MESMA
            // public/logo-fni.png da web — larga, com fundo transparente;
            // antes era um recorte diferente, quadrado, que ficava
            // minúsculo dentro da altura fixa) e o rótulo "POSTO" no ciano
            // `frota-500` (#0EA5E9), igual ao `cargoExibido` da web.
            // Achado real (correção): `DrawerHeader` impõe uma altura
            // MÍNIMA fixa (~160 + status bar) mas o Column de dentro tinha
            // `mainAxisSize.max` (o padrão) + `mainAxisAlignment: end` —
            // com o card do logo em largura cheia (mais alto que os 44px
            // antigos) o conteúdo passou dessa altura e "empurrou" tudo pra
            // baixo, vazando por cima da lista (Gestão/Dashboard). Trocado
            // por um `Container` comum (sem altura mínima imposta) dentro
            // do próprio `ListView`, com o Column em `mainAxisSize.min` —
            // a altura do cabeçalho agora é sempre exatamente o que o
            // conteúdo precisa, sem overflow.
            Container(
              width: double.infinity,
              color: const Color(0xFF0B1220),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0B1220).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: AspectRatio(
                          aspectRatio: 1132 / 441,
                          child: Image.asset('assets/logo_fni.png', fit: BoxFit.contain),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        nomeEmpresa ?? 'Posto',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'POSTO',
                        style: TextStyle(
                          color: Color(0xFF0EA5E9),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                      if (temMultiplasEmpresas)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/selecionar-empresa');
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.swap_horiz, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text('Trocar posto',
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
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
            _item(context, Icons.confirmation_number, 'Chamados', '/posto/chamados', badge: badges.chamados),
            const Divider(),
            _grp('Operação'),
            _item(context, Icons.handshake, 'Negociações', '/posto/negociacoes', badge: badges.negociacoes),
            _item(context, Icons.local_gas_station, 'Abastecimentos', '/posto/abastecimentos', badge: badges.ajustesAbastecimento),
            _item(context, Icons.card_giftcard, 'Parcerias Locais', '/posto/parcerias-locais'),
            _item(context, Icons.business, 'Clientes', '/posto/clientes'),
            _item(context, Icons.sell, 'Meus Preços', '/posto/precos'),
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
  }

  Widget _grp(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
      );

  ListTile _item(BuildContext context, IconData icon, String label, String route, {int badge = 0}) => ListTile(
        dense: true,
        leading: Icon(icon, color: const Color(0xFF0D2D6B), size: 20),
        title: Text(label, style: const TextStyle(fontSize: 14)),
        // Fase FLT-7 (ajuste) — pedido do Daniel: a pílula com número
        // (Container com Text dentro) esticava a linha inteira do menu
        // verticalmente em alguns itens (o texto do Text virava uma coluna
        // de 1 letra por linha, achado real reportado com print). Trocado
        // por uma bolinha simples, sem texto dentro — tamanho fixo pequeno,
        // não tem como "esticar" a linha. Só aparece quando badge > 0.
        trailing: badge > 0
            ? Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
              )
            : null,
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
