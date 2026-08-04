import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/notificacoes_provider.dart';
import '../../../core/providers/avisos_provider.dart';
import '../../../core/providers/menu_favoritos_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/sessao_usuario.dart';
import '../../../core/services/permissoes_acesso.dart';
import '../../../core/widgets/barra_atalhos_favoritos.dart';
import '../../../core/widgets/menu_button.dart';
import '../../../core/widgets/sino_avisos.dart';

// Fase Acesso-Rápido-Favoritos (04/08/2026) — mesma ideia de
// _itensMenuCliente em home_screen.dart, aqui pro subconjunto de rotas do
// shell Posto. Ver comentário completo lá pro porquê da duplicação
// (Drawer monta itens via chamadas inline, não um array reutilizável).
const List<({String href, String label, IconData icon})> _itensMenuPosto = [
  (href: '/posto', label: 'Dashboard', icon: Icons.dashboard),
  (href: '/posto/meu-posto', label: 'Meu Posto', icon: Icons.place),
  (href: '/posto/rede-postos', label: 'Rede de Postos', icon: Icons.hub),
  (href: '/posto/usuarios', label: 'Usuários', icon: Icons.people),
  (href: '/posto/clientes', label: 'Clientes', icon: Icons.business),
  (href: '/posto/negociacoes', label: 'Negociações', icon: Icons.handshake),
  (href: '/posto/abastecimentos', label: 'Abastecimentos', icon: Icons.local_gas_station),
  (href: '/posto/parcerias-locais', label: 'Parcerias Locais', icon: Icons.card_giftcard),
  (href: '/posto/precos', label: 'Meus Preços', icon: Icons.sell),
  (href: '/posto/pre-pedidos', label: 'Pré-Pedidos', icon: Icons.checklist),
  (href: '/posto/financeiro', label: 'Financeiro', icon: Icons.attach_money),
  (href: '/posto/meus-dados', label: 'Meus Dados / PIX', icon: Icons.account_balance),
  (href: '/posto/assistente', label: 'Assistente FNI', icon: Icons.smart_toy),
  (href: '/posto/assinatura', label: 'Minha Assinatura', icon: Icons.credit_card),
  (href: '/posto/avaliar', label: 'Avaliar Plataforma', icon: Icons.star),
  (href: '/posto/chamados', label: 'Chamados', icon: Icons.confirmation_number),
  (href: '/posto/documentos', label: 'Documentos', icon: Icons.folder),
  (href: '/posto/lgpd', label: 'Privacidade (LGPD)', icon: Icons.lock),
  (href: '/posto/avisos', label: 'Avisos', icon: Icons.notifications_outlined),
];
final List<String> _hrefsRastreaveisPosto = _itensMenuPosto.map((i) => i.href).toList();

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
    // Fase enforcement-permissoes (04/08/2026) — mesmo raciocínio do
    // home_screen.dart (shell cliente): só esconde do menu o que o
    // app_router.dart (Camada 5) já bloquearia ao navegar.
    final perfilAtual = sessao.valueOrNull?.perfil;
    final bypassPermissao = ehBypassPermissao(perfilAtual, sessao.valueOrNull?.email);
    final mapaPermissoes = bypassPermissao
        ? const <String, bool>{}
        : ref.watch(permissoesMapaProvider(perfilAtual)).valueOrNull ?? const <String, bool>{};

    // Fase Acesso-Rápido-Favoritos (04/08/2026) — ver comentário completo
    // no HomeScreen (shell cliente); mesmo raciocínio aqui pro shell posto.
    if (_hrefsRastreaveisPosto.contains(loc)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(ultimaRotaRegistradaProvider) == loc) return;
        ref.read(ultimaRotaRegistradaProvider.notifier).state = loc;
        registrarAcessoMenu(loc);
      });
    }

    bool podeAcessar(String rota) => bypassPermissao || temAcesso(mapaPermissoes, resolverFuncionalidadeDaRota(rota));
    final favoritosHrefs = (ref.watch(favoritosMenuProvider).valueOrNull ?? const []).map((f) => f.href).toSet();
    final mapaItensFavoritos = {
      for (final i in _itensMenuPosto)
        if (podeAcessar(i.href)) i.href: ItemAtalhoMenu(href: i.href, label: i.label, icon: i.icon),
    };

    return Scaffold(
      key: rootScaffoldKey,
      drawer: _buildDrawer(context, ref, sessao.valueOrNull, bypassPermissao, mapaPermissoes, favoritosHrefs),
      appBar: AppBar(
        title: const Text('FNI — Posto'),
        actions: const [SinoAvisos()],
      ),
      body: Column(
        children: [
          BarraAtalhosFavoritos(mapaItens: mapaItensFavoritos),
          Expanded(child: child),
        ],
      ),
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

  Widget _buildDrawer(
    BuildContext context,
    WidgetRef ref,
    SessaoUsuario? sessao,
    bool bypassPermissao,
    Map<String, bool> mapaPermissoes,
    Set<String> favoritosHrefs,
  ) {
    bool pode(String rota) =>
        bypassPermissao || temAcesso(mapaPermissoes, resolverFuncionalidadeDaRota(rota));

    // Fase Acesso-Rápido-Favoritos (04/08/2026) — ver comentário completo
    // no HomeScreen (shell cliente): closure local pra capturar
    // `ref`/`favoritosHrefs` sem precisar tocar nas chamadas `_item(...)`
    // já espalhadas pelo Drawer abaixo.
    ListTile _item(BuildContext context, IconData icon, String label, String route, {int badge = 0}) {
      final favoritado = favoritosHrefs.contains(route);
      return ListTile(
        dense: true,
        leading: Icon(icon, color: const Color(0xFF0D2D6B), size: 20),
        title: Text(label, style: const TextStyle(fontSize: 14)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge > 0)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
              ),
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => alternarFavoritoMenu(ref, route, !favoritado),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  favoritado ? Icons.star : Icons.star_border,
                  size: 18,
                  color: favoritado ? Colors.amber.shade700 : Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.pop(context);
          context.go(route);
        },
      );
    }

    final nomeEmpresa = sessao?.nomeEmpresa;
    // Fase FLT-2 — pedido do Daniel: seletor pra alternar entre os postos
    // da Rede de Postos (grupo econômico) a qualquer momento, não só no
    // gate inicial (ver "Camada 3" em app_router.dart) — só faz sentido
    // pra quem tem 2+ empresas vinculadas.
    final temMultiplasEmpresas = (sessao?.empresasIds.length ?? 0) > 1;
    // Fase FLT-7 — mesmas bolinhas de notificação da web, ver
    // notificacoes_provider.dart.
    final badges = ref.watch(notificacoesBadgesProvider).valueOrNull ?? NotificacoesBadges.vazio;
    // Fase Central-Avisos (28/07/2026, achado real) — mesmo raciocínio do
    // home_screen.dart (cliente): sino só existia na AppBar, sem item no
    // Drawer. Rota é /posto/avisos (mesma AvisosScreen, ver app_router.dart).
    final avisosNaoLidos = ref.watch(avisosNaoLidosProvider);
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
            // Fase reorganizacao-menu (04/08/2026, pedido do Daniel: "Fazer
            // uma sugestao de reorganizacao do menu" / "Organizacao de
            // temas iguais", implementada web + PWA cliente e posto — ver
            // comentário grande em layout.tsx pro porquê completo) — mesmos
            // 6 grupos temáticos do menuPosto* da web, adaptados ao
            // subconjunto de telas que existe neste PWA (Notas Fiscais,
            // Central de Treinamento e Integrações continuam só na web;
            // "Meus Dados / PIX" aqui cobre o mesmo tema financeiro que
            // "Minha Empresa" cobre na web).
            _grp('Visão Geral'),
            if (pode('/posto')) _item(context, Icons.dashboard, 'Dashboard', '/posto'),
            if (pode('/posto/meu-posto')) _item(context, Icons.place, 'Meu Posto', '/posto/meu-posto'),
            if (pode('/posto/rede-postos')) _item(context, Icons.hub, 'Rede de Postos', '/posto/rede-postos'),
            const Divider(),
            _grp('Cadastros'),
            if (pode('/posto/usuarios')) _item(context, Icons.people, 'Usuários', '/posto/usuarios'),
            if (pode('/posto/clientes')) _item(context, Icons.business, 'Clientes', '/posto/clientes'),
            const Divider(),
            _grp('Operação'),
            if (pode('/posto/negociacoes')) _item(context, Icons.handshake, 'Negociações', '/posto/negociacoes', badge: badges.negociacoes),
            if (pode('/posto/abastecimentos')) _item(context, Icons.local_gas_station, 'Abastecimentos', '/posto/abastecimentos', badge: badges.ajustesAbastecimento),
            if (pode('/posto/parcerias-locais')) _item(context, Icons.card_giftcard, 'Parcerias Locais', '/posto/parcerias-locais'),
            if (pode('/posto/precos')) _item(context, Icons.sell, 'Meus Preços', '/posto/precos'),
            // Fase Pré-Pedido (28/07/2026) — consulta pro posto conferir
            // antes de liberar abastecimento (ver pre_pedidos_posto_screen.dart).
            if (pode('/posto/pre-pedidos')) _item(context, Icons.checklist, 'Pré-Pedidos', '/posto/pre-pedidos'),
            const Divider(),
            _grp('Financeiro'),
            if (pode('/posto/financeiro')) _item(context, Icons.attach_money, 'Financeiro', '/posto/financeiro'),
            if (pode('/posto/meus-dados')) _item(context, Icons.account_balance, 'Meus Dados / PIX', '/posto/meus-dados'),
            const Divider(),
            _grp('Conta e Ajuda'),
            if (pode('/posto/assistente')) _item(context, Icons.smart_toy, 'Assistente FNI', '/posto/assistente'),
            if (pode('/posto/assinatura')) _item(context, Icons.credit_card, 'Minha Assinatura', '/posto/assinatura'),
            if (pode('/posto/avaliar')) _item(context, Icons.star, 'Avaliar Plataforma', '/posto/avaliar'),
            if (pode('/posto/chamados')) _item(context, Icons.confirmation_number, 'Chamados', '/posto/chamados', badge: badges.chamados),
            const Divider(),
            _grp('Sistema'),
            if (pode('/posto/documentos')) _item(context, Icons.folder, 'Documentos', '/posto/documentos'),
            if (pode('/posto/lgpd')) _item(context, Icons.lock, 'Privacidade (LGPD)', '/posto/lgpd'),
            const Divider(),
            if (pode('/posto/avisos')) _item(context, Icons.notifications_outlined, 'Avisos', '/posto/avisos', badge: avisosNaoLidos),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sair', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await AuthService().signOut();
                ref.invalidate(sessaoProvider);
                ref.invalidate(empresaSelecionadaProvider);
                ref.invalidate(permissoesMapaProvider);
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
