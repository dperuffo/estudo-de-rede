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
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/barra_atalhos_favoritos.dart';
import '../../../core/widgets/menu_button.dart';
import '../../insights_ia/providers/insights_ia_provider.dart';
import '../../../core/widgets/sino_avisos.dart';

// Fase Acesso-Rápido-Favoritos (04/08/2026, pedido do Daniel: "mecanismo de
// acesso rápido... favoritos... usar inteligência artificial pra posicionar
// as abas mais utilizadas") — lista achatada (href -> ícone/rótulo) de TODO
// item de menu deste shell, na mesma ideia de TODOS_ITENS_MENU/
// MAPA_ITENS_MENU em layout.tsx (web): serve pra (a) resolver os hrefs
// favoritados em label/ícone pra desenhar a barra de atalhos, e (b) saber
// quais rotas são "rastreáveis" (contam acesso pra frecência). Como aqui os
// itens do Drawer são montados via chamadas inline (`_item(...)`, não um
// array de dados reutilizável como na web), esta lista é mantida em
// paralelo — precisa acompanhar manualmente qualquer item novo/removido do
// Drawer abaixo.
const List<({String href, String label, IconData icon})> _itensMenuCliente = [
  (href: '/dashboard', label: 'Dashboard', icon: Icons.dashboard),
  (href: '/torre-de-controle', label: 'Torre de Controle', icon: Icons.radar),
  (
    href: '/indicadores-frota',
    label: 'Indicadores da Frota',
    icon: Icons.speed
  ),
  (
    href: '/jornada-motoristas',
    label: 'Jornada dos Motoristas',
    icon: Icons.timer_outlined
  ),
  (
    href: '/acoes-sugeridas',
    label: 'Ações Sugeridas',
    icon: Icons.auto_awesome
  ),
  (href: '/clientes', label: 'Clientes', icon: Icons.business),
  (
    href: '/grupo-economico',
    label: 'Grupo Econômico',
    icon: Icons.account_tree
  ),
  (href: '/usuarios', label: 'Usuários', icon: Icons.people),
  (href: '/motoristas', label: 'Motoristas', icon: Icons.badge),
  (href: '/veiculos', label: 'Veículos', icon: Icons.directions_car),
  (href: '/pneus', label: 'Gestão de Pneus', icon: Icons.tire_repair),
  (href: '/centros-custo', label: 'Centros de Custo', icon: Icons.receipt_long),
  (
    href: '/postos',
    label: 'Postos Revendedores',
    icon: Icons.local_gas_station
  ),
  (
    href: '/postos-internos',
    label: 'Postos Internos',
    icon: Icons.garage_outlined
  ),
  (href: '/roteirizacao', label: 'Roteirização', icon: Icons.route),
  (href: '/rotograma', label: 'Rotograma', icon: Icons.shield_outlined),
  (href: '/planos-viagem', label: 'Planos de Viagem', icon: Icons.card_travel),
  (
    href: '/abastecimentos',
    label: 'Abastecimentos',
    icon: Icons.local_gas_station
  ),
  (
    href: '/abastecimentos/aprovacao',
    label: 'Pendentes de Aprovação',
    icon: Icons.fact_check_outlined
  ),
  (
    href: '/conferencia-precos',
    label: 'Conferência de Preços',
    icon: Icons.price_check
  ),
  (href: '/parametros-uso', label: 'Parâmetros de Uso', icon: Icons.tune),
  (href: '/notas-fiscais', label: 'Notas Fiscais', icon: Icons.description),
  (
    href: '/apuracao-tributaria',
    label: 'Apuração de Crédito Tributário',
    icon: Icons.balance
  ),
  (href: '/combustivel-ideal', label: 'Combustível Ideal', icon: Icons.eco),
  (
    href: '/precos-postos',
    label: 'Preços dos Postos Parceiros',
    icon: Icons.sell
  ),
  (
    href: '/negociacoes',
    label: 'Negociações com Postos',
    icon: Icons.handshake
  ),
  (href: '/parametros-nf', label: 'Parâmetros de NF', icon: Icons.receipt_long),
  (href: '/fretes', label: 'Fretes', icon: Icons.local_shipping),
  (href: '/programacao', label: 'Programação', icon: Icons.calendar_month),
  (href: '/cotacoes', label: 'Cotações', icon: Icons.calculate_outlined),
  (
    href: '/tabelas-frete',
    label: 'Tabelas de Frete',
    icon: Icons.rule_folder_outlined
  ),
  (
    href: '/faturas-fretes',
    label: 'Faturas de Frete',
    icon: Icons.receipt_long
  ),
  (
    href: '/bolsa-fretes',
    label: 'Bolsa de Fretes do Grupo',
    icon: Icons.location_on_outlined
  ),
  (
    href: '/agendamentos-patio',
    label: 'Agendamento de Pátio',
    icon: Icons.calendar_month
  ),
  (href: '/crm-comercial', label: 'CRM Comercial', icon: Icons.work_outline),
  (
    href: '/motoristas-parceiros',
    label: 'Motoristas Parceiros',
    icon: Icons.handshake_outlined
  ),
  (href: '/pisos-antt', label: 'Piso Mínimo ANTT', icon: Icons.price_check),
  (
    href: '/manutencao-preditiva',
    label: 'Manutenção Preditiva',
    icon: Icons.build
  ),
  (href: '/estoque-pecas', label: 'Estoque de Peças', icon: Icons.inventory_2),
  (href: '/tco', label: 'TCO / Custo por Veículo', icon: Icons.attach_money),
  (href: '/patrimonio', label: 'Patrimônio', icon: Icons.account_balance),
  (
    href: '/checklist-veiculos',
    label: 'Checklist de Inspeção',
    icon: Icons.fact_check
  ),
  (href: '/sinistros', label: 'Sinistros', icon: Icons.warning_amber),
  (
    href: '/apolices-seguro',
    label: 'Apólices de Seguro',
    icon: Icons.shield_outlined
  ),
  (
    href: '/fidelidade-motoristas',
    label: 'Fidelidade dos Motoristas',
    icon: Icons.card_giftcard
  ),
  (href: '/multas', label: 'Multas', icon: Icons.gavel),
  (
    href: '/oficinas',
    label: 'Rede de Oficinas',
    icon: Icons.build_circle_outlined
  ),
  (href: '/financeiro', label: 'Painel Financeiro', icon: Icons.attach_money),
  (href: '/fiscal', label: 'Fiscal (CT-e/MDF-e)', icon: Icons.receipt_long),
  (
    href: '/central-regras',
    label: 'Central de Regras & Alertas',
    icon: Icons.rule
  ),
  (href: '/aprovacoes', label: 'Aprovações', icon: Icons.check_circle_outline),
  (
    href: '/central-avisos/gerenciar',
    label: 'Meus Avisos',
    icon: Icons.campaign_outlined
  ),
  (
    href: '/treinamento',
    label: 'Central de Treinamento',
    icon: Icons.school_outlined
  ),
  (
    href: '/conciliacao-bancaria',
    label: 'Conciliação Bancária',
    icon: Icons.compare_arrows
  ),
  (href: '/relatorios', label: 'Relatórios', icon: Icons.bar_chart),
  (href: '/pegada-carbono', label: 'Pegada de Carbono', icon: Icons.public),
  (href: '/inteligencia-rede', label: 'Inteligência de Rede', icon: Icons.hub),
  (
    href: '/parcerias-locais',
    label: 'Parcerias Locais',
    icon: Icons.card_giftcard
  ),
  (href: '/assistente', label: 'Assistente FNI', icon: Icons.smart_toy),
  (href: '/assinatura', label: 'Minha Assinatura', icon: Icons.credit_card),
  (href: '/avaliar', label: 'Avaliar Plataforma', icon: Icons.star),
  (href: '/chamados', label: 'Chamados', icon: Icons.confirmation_number),
  (href: '/documentos', label: 'Documentos', icon: Icons.folder),
  (href: '/lgpd', label: 'Privacidade (LGPD)', icon: Icons.lock),
  (href: '/permissoes', label: 'Permissões', icon: Icons.vpn_key),
  (href: '/avisos', label: 'Avisos', icon: Icons.notifications_outlined),
];
final List<String> _hrefsRastreaveisCliente =
    _itensMenuCliente.map((i) => i.href).toList();

// Fase FLT-3 — shell da visão Cliente, reescrito do zero. Antes este era o
// "shell genérico" (cliente + admin misturados, sem gate de perfil — ver
// achado registrado no app_router.dart) com 18 telas que pareciam reais mas
// estavam TODAS quebradas: usavam um backend Python legado
// (api.fxgestaodefrotasonline.com) cujo token nunca é mais gravado desde
// que o login migrou pro Supabase Auth (Fase FLT-1) — qualquer chamada
// protegida respondia 401 em silêncio. Reconstruído seguindo o mesmo molde
// da Fase FLT-2 (visão Posto): menu espelhando exatamente as seções do
// menu cliente da web (src/app/(dashboard)/layout.tsx: Gestão/Cadastros/
// Operação/Configurações), cada rota como placeholder (EmConstrucaoScreen)
// até virar tela de verdade, uma de cada vez (ver lista de tarefas FLT-3).
// Descartadas (decisão do Daniel): telas antigas sem equivalente no menu
// cliente atual — Frota (`/frota`), Manutenção antiga (`/manutencao`,
// diferente de Manutenção Preditiva), Variação de Preços como página
// própria (`/precos`), Análise de Cliente (`/analise-cliente`) e Acordos
// de Preço (`/acordos`). A separação cliente x admin dentro deste shell
// (hoje qualquer perfil "não-posto" cai aqui, sem distinguir admin) segue
// fora de escopo por ora — mesma decisão registrada no app_router.dart.
class HomeScreen extends ConsumerWidget {
  final Widget child;
  const HomeScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).matchedLocation;
    final sessao = ref.watch(sessaoProvider);
    // Fase enforcement-permissoes (04/08/2026) — mesmo mapa usado pelo
    // bloqueio de rota em app_router.dart (Camada 5), aqui só pra esconder
    // do menu o que já seria bloqueado ao clicar (evita a pessoa navegar
    // pra tela, cair no redirect e achar que é bug). `bypass` cobre
    // admin/e-mail do Daniel, que sempre veem o menu completo.
    final perfilAtual = sessao.valueOrNull?.perfil;
    final bypassPermissao =
        ehBypassPermissao(perfilAtual, sessao.valueOrNull?.email);
    final mapaPermissoes = bypassPermissao
        ? const <String, bool>{}
        : ref.watch(permissoesMapaProvider(perfilAtual)).valueOrNull ??
            const <String, bool>{};

    // Fase Acesso-Rápido-Favoritos (04/08/2026) — registra 1 acesso (pra
    // frecência) toda vez que a rota atual muda pra uma rota "rastreável"
    // (item de algum menu). `addPostFrameCallback` evita disparar a
    // chamada durante o build (efeito colateral, best-effort, nunca deve
    // travar a navegação); `ultimaRotaRegistradaProvider` evita regravar a
    // mesma rota em rebuilds sem navegação real — mesma dedup de
    // RastreadorAcessoMenu.tsx (web), via `useRef` lá.
    if (_hrefsRastreaveisCliente.contains(loc)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(ultimaRotaRegistradaProvider) == loc) return;
        ref.read(ultimaRotaRegistradaProvider.notifier).state = loc;
        registrarAcessoMenu(loc);
      });
    }

    bool podeAcessar(String rota) =>
        bypassPermissao ||
        temAcesso(mapaPermissoes, resolverFuncionalidadeDaRota(rota));
    final favoritosHrefs =
        (ref.watch(favoritosMenuProvider).valueOrNull ?? const [])
            .map((f) => f.href)
            .toSet();
    final mapaItensFavoritos = {
      for (final i in _itensMenuCliente)
        if (podeAcessar(i.href))
          i.href: ItemAtalhoMenu(href: i.href, label: i.label, icon: i.icon),
    };

    return Scaffold(
      key: rootScaffoldKey,
      // Fase Pente-Fino-Performance (10/09/2026) — achado real: o Drawer
      // inteiro (~70 ListTiles + permissões + estrelas de favorito) era
      // reconstruído a cada rebuild desta shell, mesmo fechado. Como a shell
      // também escuta `notificacoesBadgesProvider`/`avisosNaoLidosProvider`
      // (que atualizam por polling), cada tick reconstruía o Drawer inteiro
      // só pra atualizar uma bolinha de badge — mesmo sem o usuário nunca
      // ter aberto o menu. Extraído pra `_HomeDrawer`, um ConsumerWidget
      // próprio que escuta esses providers sozinho: agora só o Drawer
      // reconstrói nesse caso, não a AppBar/bottomNav/conteúdo da rota atual.
      drawer: _HomeDrawer(
        sessao: sessao.valueOrNull,
        bypassPermissao: bypassPermissao,
        mapaPermissoes: mapaPermissoes,
        favoritosHrefs: favoritosHrefs,
      ),
      // Fase Liquid-Glass-PWA (20/08/2026) — mesma superfície bronze/champanhe
      // do menu (ver _buildDrawer), agora na barra do topo. `flexibleSpace` +
      // fundo transparente troca a cor sólida (frota-950) pelo gradiente,
      // com texto/ícone recolorido pra manter contraste (glassTexto/glassIcone).
      appBar: AppBar(
        title: const Text('FNI — Gestão de Frotas'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTheme.glassTexto,
        iconTheme: const IconThemeData(color: AppTheme.glassIcone),
        titleTextStyle: const TextStyle(
            color: AppTheme.glassTexto,
            fontSize: 18,
            fontWeight: FontWeight.w600),
        flexibleSpace: Container(
            decoration:
                const BoxDecoration(gradient: AppTheme.glassNavGradient)),
        actions: const [SinoAvisos()],
      ),
      body: Column(
        children: [
          BarraAtalhosFavoritos(mapaItens: mapaItensFavoritos),
          Expanded(
            child: Responsive.conteudoCentralizado(context, child),
          ),
        ],
      ),
      // Fase Auditoria-UX-Responsividade (08/09/2026) — a barra de abas
      // inferior faz sentido no celular (alcance do polegar), mas numa tela
      // de tablet/desktop ela fica sobrando embaixo de um monitor inteiro,
      // sem nenhum ganho de navegação (o Drawer completo já está sempre a 1
      // toque de distância pelo ícone de hambúrguer que o Scaffold desenha
      // sozinho na AppBar, em qualquer largura, só por existir `drawer:`
      // acima). Some só nesse tamanho — todo o resto do shell é idêntico.
      bottomNavigationBar: Responsive.isDesktop(context)
          ? null
          : Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.glassNavGradient,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  navigationBarTheme: NavigationBarThemeData(
                    backgroundColor: Colors.transparent,
                    indicatorColor: AppTheme.glassPillClaro,
                    iconTheme: MaterialStateProperty.resolveWith(
                      (states) => IconThemeData(
                        color: states.contains(MaterialState.selected)
                            ? AppTheme.glassTextoAtivo
                            : AppTheme.glassIcone,
                      ),
                    ),
                    labelTextStyle: MaterialStateProperty.resolveWith(
                      (states) => TextStyle(
                        fontSize: 11,
                        fontWeight: states.contains(MaterialState.selected)
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: states.contains(MaterialState.selected)
                            ? AppTheme.glassTextoAtivo
                            : AppTheme.glassTextoMuted,
                      ),
                    ),
                  ),
                ),
                child: NavigationBar(
                  selectedIndex: _idx(loc),
                  onDestinationSelected: (i) => _nav(context, i),
                  destinations: const [
                    NavigationDestination(
                        icon: Icon(Icons.dashboard), label: 'Painel'),
                    NavigationDestination(
                        icon: Icon(Icons.local_gas_station),
                        label: 'Abastec.'),
                    NavigationDestination(
                        icon: Icon(Icons.directions_car), label: 'Veículos'),
                    NavigationDestination(
                        icon: Icon(Icons.attach_money), label: 'Financ.'),
                    NavigationDestination(
                        icon: Icon(Icons.menu), label: 'Mais'),
                  ],
                ),
              ),
            ),
    );
  }

  int _idx(String loc) {
    if (loc.startsWith('/abastecimentos')) return 1;
    if (loc.startsWith('/veiculos')) return 2;
    if (loc.startsWith('/financeiro')) return 3;
    if (loc == '/dashboard' || loc == '/') return 0;
    return 4; // qualquer outra tela do drawer conta como "Mais"
  }

  void _nav(BuildContext ctx, int i) {
    switch (i) {
      case 0:
        ctx.go('/dashboard');
        break;
      case 1:
        ctx.go('/abastecimentos');
        break;
      case 2:
        ctx.go('/veiculos');
        break;
      case 3:
        ctx.go('/financeiro');
        break;
      case 4:
        rootScaffoldKey.currentState?.openDrawer();
        break;
    }
  }
}

// Fase Pente-Fino-Performance (10/09/2026) — ver comentário em
// `HomeScreen.build` sobre o porquê deste widget existir separado: isola o
// estado de alta frequência (badges/avisos não lidos, atualizados por
// polling) num ConsumerWidget próprio, então um `setState`/rebuild causado
// só por essas duas mudanças não reconstrói a shell inteira (AppBar, barra
// de favoritos, conteúdo da rota atual) — só este Drawer.
class _HomeDrawer extends ConsumerWidget {
  final SessaoUsuario? sessao;
  final bool bypassPermissao;
  final Map<String, bool> mapaPermissoes;
  final Set<String> favoritosHrefs;

  const _HomeDrawer({
    required this.sessao,
    required this.bypassPermissao,
    required this.mapaPermissoes,
    required this.favoritosHrefs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fase enforcement-permissoes (04/08/2026) — mesma checagem usada na
    // web (podeAcessarItem em layout.tsx): rota sem "aba_" mapeada
    // (resolverFuncionalidadeDaRota devolve null) fica sempre liberada.
    bool pode(String rota) =>
        bypassPermissao ||
        temAcesso(mapaPermissoes, resolverFuncionalidadeDaRota(rota));

    // Fase Acesso-Rápido-Favoritos (04/08/2026) — closure local (não mais
    // método de instância) só pra poder capturar `ref`/`favoritosHrefs` sem
    // precisar tocar em nenhuma das dezenas de chamadas `_item(...)` já
    // espalhadas pelo Drawer abaixo — cada uma continua exatamente igual,
    // só que agora ganha a estrela de fixar/desfixar (mesma ideia de
    // BotaoFavoritoMenu.tsx na web) desenhada a partir do próprio `route`.
    ListTile _item(
        BuildContext context, IconData icon, String label, String route,
        {int badge = 0}) {
      final favoritado = favoritosHrefs.contains(route);
      return ListTile(
        dense: true,
        leading: Icon(icon, color: AppTheme.glassIcone, size: 20),
        title: Text(label,
            style: const TextStyle(fontSize: 14, color: AppTheme.glassTexto)),
        // Fase FLT-7 (ajuste) — pedido do Daniel: a pílula com número
        // (Container com Text dentro) esticava a linha inteira do menu
        // verticalmente em alguns itens (o texto do Text virava uma coluna
        // de 1 letra por linha, achado real reportado com print). Trocado
        // por uma bolinha simples, sem texto dentro — tamanho fixo pequeno,
        // não tem como "esticar" a linha. Só aparece quando badge > 0.
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge > 0)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(
                    color: Color(0xFFEF4444), shape: BoxShape.circle),
              ),
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => alternarFavoritoMenu(ref, route, !favoritado),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  favoritado ? Icons.star : Icons.star_border,
                  size: 18,
                  color: favoritado
                      ? Colors.amber.shade400
                      : AppTheme.glassIcone.withOpacity(0.35),
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
    final temMultiplasEmpresas = (sessao?.empresasIds.length ?? 0) > 1;
    // Fase FLT-7 — as 7 bolinhas de notificação da web (ver comentário
    // completo em notificacoes_provider.dart). `valueOrNull` porque o
    // drawer não deve travar/piscar loading — enquanto carrega (ou se
    // falhar), simplesmente não mostra bolinha nenhuma.
    final badges = ref.watch(notificacoesBadgesProvider).valueOrNull ??
        NotificacoesBadges.vazio;
    // Fase Central-Avisos (28/07/2026, achado real) — na web o AvisosSino
    // fica no rodapé do menu lateral, junto de Central de Ajuda/Sair (ver
    // layout.tsx). Aqui no PWA o sino só existia como ícone na AppBar
    // (sino_avisos.dart) — sem item no Drawer o Daniel não achava a "aba"
    // de Avisos (ele navega pelo menu, igual na web). Item adicionado
    // abaixo, na mesma posição relativa (perto de Sair).
    final avisosNaoLidos = ref.watch(avisosNaoLidosProvider);
    return Drawer(
      backgroundColor: Colors.transparent,
      // Fase Liquid-Glass-PWA (20/08/2026, pedido do Daniel: "implementar
      // estas mudanças nos PWAs cliente e motorista") — todo o Drawer (não
      // só o cabeçalho) vira uma única superfície bronze/champanhe contínua,
      // igual ao <aside> da web. O drawer do celular fica sobre um scrim
      // escuro (não sobre o conteúdo real da tela, que continua atrás dele
      // dimerizado) — por isso não há blur literal aqui: não há nada visível
      // atrás do painel pra desfocar, só a superfície em si com gradiente +
      // realce + sombra, mesma linguagem visual da web.
      child: Container(
        decoration: const BoxDecoration(gradient: AppTheme.glassNavGradient),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.glassTextoAtivo.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: AspectRatio(
                          aspectRatio: 1132 / 441,
                          child: Image.asset('assets/logo_fni.png',
                              fit: BoxFit.contain),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        nomeEmpresa ?? 'Minha empresa',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.glassTexto,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'FROTA',
                        style: TextStyle(
                          color: AppTheme.glassAcento,
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
                                Icon(Icons.swap_horiz,
                                    color: AppTheme.glassTexto, size: 16),
                                SizedBox(width: 4),
                                Text('Trocar empresa',
                                    style: TextStyle(
                                        color: AppTheme.glassTexto,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
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
            // uma sugestao de reorganizacao do menu" / "Organizacao de temas
            // iguais", implementada web + PWA cliente e posto — ver
            // comentário grande em src/app/(dashboard)/layout.tsx pro porquê
            // completo: a antiga Operação (29 itens numa lista só) tinha
            // crescido fase após fase até virar confusa demais) — mesmos 9
            // grupos temáticos da web, adaptados ao subconjunto de telas que
            // existe neste PWA (nem toda rota web tem equivalente aqui —
            // Integrações, por exemplo, continua só na web; a maior parte
            // do restante já foi equalizada nas fases FLT-* de 02-03/09/2026).
            _grp('Visão Geral'),
            if (pode('/dashboard'))
              _item(context, Icons.dashboard, 'Dashboard', '/dashboard'),
            if (pode('/torre-de-controle'))
              _item(context, Icons.radar, 'Torre de Controle',
                  '/torre-de-controle'),
            if (pode('/indicadores-frota'))
              _item(context, Icons.speed, 'Indicadores da Frota',
                  '/indicadores-frota'),
            if (pode('/jornada-motoristas'))
              _item(context, Icons.timer_outlined, 'Jornada dos Motoristas',
                  '/jornada-motoristas'),
            if (pode('/acoes-sugeridas'))
              _item(context, Icons.auto_awesome, 'Ações Sugeridas',
                  '/acoes-sugeridas',
                  badge: badges.acoesSugeridas),
            // Fase FLT-Insights-IA (02/09/2026) — porta de /insights-ia da
            // web: sinais cruzados gerados 1x/dia. Igual na web, além do
            // mapa de permissões padrão (aba_insights_ia), esse item só
            // aparece se a empresa tiver plano enterprise ou liberação
            // manual (acesso_insights_ia_liberado) — checagem dupla, único
            // item do menu com esse gate extra por plano.
            if (pode('/insights-ia') &&
                (ref.watch(insightsIaAcessoProvider).valueOrNull ?? false))
              _item(context, Icons.psychology_outlined, 'Insights de IA',
                  '/insights-ia'),
            // Fase FLT-Central-Regras (03/09/2026) — porta de
            // /central-regras da web: hub linkando pra Ações
            // Sugeridas/Antifraude/Avisos/Insights de IA + tela de
            // configuração dos 13 limiares numéricos usados nas detecções.
            if (pode('/central-regras'))
              _item(context, Icons.rule, 'Central de Regras & Alertas',
                  '/central-regras'),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            _grp('Cadastros'),
            if (pode('/clientes'))
              _item(context, Icons.business, 'Clientes', '/clientes',
                  badge: badges.acessosClientes),
            if (pode('/grupo-economico'))
              _item(context, Icons.account_tree, 'Grupo Econômico',
                  '/grupo-economico'),
            if (pode('/usuarios'))
              _item(context, Icons.people, 'Usuários', '/usuarios'),
            if (pode('/motoristas'))
              _item(context, Icons.badge, 'Motoristas', '/motoristas'),
            if (pode('/veiculos'))
              _item(context, Icons.directions_car, 'Veículos', '/veiculos'),
            // Fase FLT-Gestão-Pneus (02/09/2026) — porta de /pneus da web.
            if (pode('/pneus'))
              _item(context, Icons.tire_repair, 'Gestão de Pneus', '/pneus'),
            if (pode('/centros-custo'))
              _item(context, Icons.receipt_long, 'Centros de Custo',
                  '/centros-custo'),
            if (pode('/postos'))
              _item(context, Icons.local_gas_station, 'Postos Revendedores',
                  '/postos'),
            // Fase FLT-Postos-Internos (02/09/2026) — configuração
            // self-service da garagem/tanque próprio (matriz ou filial).
            if (pode('/postos-internos'))
              _item(context, Icons.garage_outlined, 'Postos Internos',
                  '/postos-internos'),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            _grp('Roteirização e Abastecimento'),
            if (pode('/roteirizacao'))
              _item(context, Icons.route, 'Roteirização', '/roteirizacao'),
            if (pode('/rotograma'))
              _item(context, Icons.shield_outlined, 'Rotograma', '/rotograma'),
            if (pode('/planos-viagem'))
              _item(context, Icons.card_travel, 'Planos de Viagem',
                  '/planos-viagem'),
            if (pode('/abastecimentos'))
              _item(context, Icons.local_gas_station, 'Abastecimentos',
                  '/abastecimentos',
                  badge: badges.ajustesAbastecimento),
            // Fase FLT-Aprovação-Manual (02/09/2026) — lançamentos manuais
            // do PWA Motorista (foto do cupom + OCR) esperando aprovação.
            if (pode('/abastecimentos/aprovacao'))
              _item(context, Icons.fact_check_outlined,
                  'Pendentes de Aprovação', '/abastecimentos/aprovacao',
                  badge: badges.pendentesAprovacaoManual),
            // Fase FLT-Conferência-Precos (02/09/2026) — compara preço
            // praticado x acordado com o posto + extrato diário.
            if (pode('/conferencia-precos'))
              _item(context, Icons.price_check, 'Conferência de Preços',
                  '/conferencia-precos'),
            // Fase reorganizacao-menu-2 (04/08/2026, pedido do Daniel) —
            // movida de "Sistema" pra cá: é regra de abastecimento, não
            // configuração geral. Icons.tune = web: SlidersHorizontal.
            if (pode('/parametros-uso'))
              _item(
                  context, Icons.tune, 'Parâmetros de Uso', '/parametros-uso'),
            if (pode('/notas-fiscais'))
              _item(context, Icons.description, 'Notas Fiscais',
                  '/notas-fiscais'),
            // Fase FLT-Apuração-Tributária (02/09/2026) — porta de
            // /apuracao-tributaria da web: crédito de ICMS monofásico
            // sobre combustível (LC 192/2022), a partir do que já vem
            // calculado no XML da NF-e do posto.
            if (pode('/apuracao-tributaria'))
              _item(context, Icons.balance, 'Apuração de Crédito Tributário',
                  '/apuracao-tributaria'),
            // Fase Onda-2 (benchmark TicketLog, item #6) — comparador de
            // combustível ideal por veículo/região.
            if (pode('/combustivel-ideal'))
              _item(context, Icons.eco, 'Combustível Ideal',
                  '/combustivel-ideal'),
            if (pode('/precos-postos'))
              _item(context, Icons.sell, 'Preços dos Postos Parceiros',
                  '/precos-postos'),
            if (pode('/negociacoes'))
              _item(context, Icons.handshake, 'Negociações com Postos',
                  '/negociacoes',
                  badge: badges.negociacoes),
            if (pode('/parametros-nf'))
              _item(context, Icons.receipt_long, 'Parâmetros de NF',
                  '/parametros-nf'),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            _grp('Fretes'),
            if (pode('/fretes'))
              _item(context, Icons.local_shipping, 'Fretes', '/fretes'),
            // Fase Programacao-Frota (03/08/2026, benchmark FNI vs
            // Rodopar/Datapar, Grupo 1 item 1) — Icons.calendar_month = PWA:
            // CalendarClock (web).
            if (pode('/programacao'))
              _item(
                  context, Icons.calendar_month, 'Programação', '/programacao'),
            // Fase agendamento-patio (04/08/2026, benchmark FNI vs KMM, Grupo
            // 2 item 8) — YMS leve. Icons.calendar_month = PWA: CalendarClock
            // (web, mesmo ícone de Programação lá também).
            if (pode('/agendamentos-patio'))
              _item(context, Icons.calendar_month, 'Agendamento de Pátio',
                  '/agendamentos-patio'),
            // Fase FLT-Cotações (02/09/2026) — porta de /cotacoes da web:
            // simulador de frete (tabela de frete + faixa de peso + piso
            // ANTT), com opção de converter em frete de verdade.
            if (pode('/cotacoes'))
              _item(context, Icons.calculate_outlined, 'Cotações', '/cotacoes'),
            // Fase FLT-Tabelas-Frete (02/09/2026) — porta de
            // /tabelas-frete da web: faixas de peso + adicionais usados
            // pelo simulador de Cotações.
            if (pode('/tabelas-frete'))
              _item(context, Icons.rule_folder_outlined, 'Tabelas de Frete',
                  '/tabelas-frete'),
            // Fase FLT-Faturas-Frete (02/09/2026) — porta de
            // /faturas-fretes da web: agrupa CT-es autorizados por tomador
            // pra gerar fatura, com marcar-como-paga/cancelar.
            if (pode('/faturas-fretes'))
              _item(context, Icons.receipt_long, 'Faturas de Frete',
                  '/faturas-fretes'),
            // Fase FLT-Bolsa-Fretes (02/09/2026) — porta de /bolsa-fretes
            // da web: capacidade ociosa própria + fretes disponíveis nas
            // empresas irmãs do mesmo Grupo Econômico (restrito, sem
            // preço/contato — RPC bolsa_fretes_grupo já limita no server).
            if (pode('/bolsa-fretes'))
              _item(context, Icons.location_on_outlined,
                  'Bolsa de Fretes do Grupo', '/bolsa-fretes'),
            // Fase Grupo 2 (Rodopar/Datapar, item 5, 03/08/2026) —
            // Icons.work_outline = PWA: Briefcase (web). Carteira de clientes
            // + funil de propostas (lê cotacoes) + histórico de relacionamento.
            if (pode('/crm-comercial'))
              _item(context, Icons.work_outline, 'CRM Comercial',
                  '/crm-comercial'),
            if (pode('/motoristas-parceiros'))
              _item(context, Icons.handshake_outlined, 'Motoristas Parceiros',
                  '/motoristas-parceiros'),
            // Fase Financeiro-ERP (26/07/2026, pedido do Daniel) — "Aba de
            // Piso mínimo ANTT tem que estar na visão do cliente, web e PWA".
            // Na web esta tabela vive dentro de /cotacoes (leitura); aqui
            // como não existe uma tela de Cotações própria, ganhou rota e
            // item de menu próprios — mesmo dado, entrega diferente.
            if (pode('/pisos-antt'))
              _item(context, Icons.price_check, 'Piso Mínimo ANTT',
                  '/pisos-antt'),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            _grp('Manutenção e Ativos'),
            if (pode('/manutencao-preditiva'))
              _item(context, Icons.build, 'Manutenção Preditiva',
                  '/manutencao-preditiva'),
            // Fase Grupo 1 Rodopar item 2 (03/08/2026, benchmark FNI vs
            // Rodopar/Datapar) — Icons.inventory_2 = PWA: Boxes (web).
            // Catálogo de peças com saldo/custo médio calculado a partir de um
            // ledger imutável, integrado à Manutenção (vincula saída à OS).
            if (pode('/estoque-pecas'))
              _item(context, Icons.inventory_2, 'Estoque de Peças',
                  '/estoque-pecas'),
            if (pode('/tco'))
              _item(context, Icons.attach_money, 'TCO / Custo por Veículo',
                  '/tco'),
            // Fase Grupo 2 (Rodopar, item 6, 03/08/2026) — Icons.account_balance
            // = PWA: Landmark (web). Depreciação contábil linha reta + correções
            // do ativo (reavaliação/melhoria/baixa).
            if (pode('/patrimonio'))
              _item(
                  context, Icons.account_balance, 'Patrimônio', '/patrimonio'),
            // Fase Indicadores-da-Frota C (30/07/2026) — Icons.fact_check =
            // PWA: ShieldCheck (web). Alimenta conformidade/TMRNC.
            if (pode('/checklist-veiculos'))
              _item(context, Icons.fact_check, 'Checklist de Inspeção',
                  '/checklist-veiculos'),
            // Fase Indicadores-da-Frota C (30/07/2026) — Icons.warning_amber =
            // PWA: AlertTriangle (web). Alimenta índice de sinistralidade.
            if (pode('/sinistros'))
              _item(context, Icons.warning_amber, 'Sinistros', '/sinistros'),
            // Fase FLT-Apólices-Seguro (02/09/2026) — porta de
            // /apolices-seguro da web: número, seguradora, vigência,
            // cobertura e franquia, com alerta de vencimento.
            if (pode('/apolices-seguro'))
              _item(context, Icons.shield_outlined, 'Apólices de Seguro',
                  '/apolices-seguro'),
            // Fase Onda-2 (benchmark TicketLog, item #4) — ciclo de multas:
            // captura, indicação de condutor, histórico, prazo de desconto.
            if (pode('/multas'))
              _item(context, Icons.gavel, 'Multas', '/multas',
                  badge: badges.multasPendentes),
            // Fase Onda-2 (benchmark TicketLog, item #5) — catálogo de
            // oficinas credenciadas + solicitação simples de orçamento.
            if (pode('/oficinas'))
              _item(context, Icons.build_circle_outlined, 'Rede de Oficinas',
                  '/oficinas'),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            _grp('Financeiro'),
            if (pode('/financeiro'))
              _item(context, Icons.attach_money, 'Painel Financeiro',
                  '/financeiro'),
            // Fase FLT-Conciliação-Bancária (02/09/2026) — porta de
            // /conciliacao-bancaria da web: import de extrato OFX/CSV +
            // matching automático (valor+data+fornecedor) contra
            // contas_pagar/contas_receber em aberto.
            if (pode('/conciliacao-bancaria'))
              _item(context, Icons.compare_arrows, 'Conciliação Bancária',
                  '/conciliacao-bancaria'),
            // Fase FLT-Fiscal (02/09/2026) — porta de /fiscal da web:
            // dados do emitente de CT-e/MDF-e (regime, série, ambiente).
            // Envio de certificado/teste de conexão continuam só na web.
            if (pode('/fiscal'))
              _item(context, Icons.receipt_long, 'Fiscal (CT-e/MDF-e)',
                  '/fiscal'),
            // Fase FLT-Aprovações (03/09/2026) — porta de /aprovacoes da
            // web: fluxo de aprovação multi-nível (sequencial — nível 2
            // exige perfil gestor_frota/admin, checado no servidor).
            if (pode('/aprovacoes'))
              _item(context, Icons.check_circle_outline, 'Aprovações',
                  '/aprovacoes'),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            _grp('Relatórios e Sustentabilidade'),
            if (pode('/relatorios'))
              _item(context, Icons.bar_chart, 'Relatórios', '/relatorios'),
            // Fase Onda-3 (benchmark TicketLog, item #10) — estimativa de CO2
            // emitido pela frota a partir dos litros já registrados.
            if (pode('/pegada-carbono'))
              _item(context, Icons.public, 'Pegada de Carbono',
                  '/pegada-carbono'),
            if (pode('/inteligencia-rede'))
              _item(context, Icons.hub, 'Inteligência de Rede',
                  '/inteligencia-rede'),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            _grp('Engajamento'),
            // Fase Parcerias Locais (17/07) — o cliente cria seus próprios
            // benefícios (treinamentos, marketplace, telemedicina etc.) no
            // catálogo de fidelidade.
            if (pode('/parcerias-locais'))
              _item(context, Icons.card_giftcard, 'Parcerias Locais',
                  '/parcerias-locais'),
            // Fase FLT-Fidelidade-Motoristas (02/09/2026) — porta de
            // /fidelidade-motoristas da web: indicadores de pontos/nível
            // por motorista + gestão de missões.
            if (pode('/fidelidade-motoristas'))
              _item(context, Icons.emoji_events_outlined,
                  'Fidelidade dos Motoristas', '/fidelidade-motoristas'),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            _grp('Conta e Ajuda'),
            if (pode('/assistente'))
              _item(context, Icons.smart_toy, 'Assistente FNI', '/assistente'),
            if (pode('/assinatura'))
              _item(context, Icons.credit_card, 'Minha Assinatura',
                  '/assinatura'),
            if (pode('/avaliar'))
              _item(context, Icons.star, 'Avaliar Plataforma', '/avaliar'),
            if (pode('/chamados'))
              _item(context, Icons.confirmation_number, 'Chamados', '/chamados',
                  badge: badges.chamados),
            // Fase FLT-Central-Avisos (03/09/2026) — porta de
            // /central-avisos/gerenciar da web ("Meus Avisos"): criar
            // avisos visíveis pra própria empresa e demais do mesmo grupo
            // econômico. Distinto do painel admin de broadcast
            // (/administracao/central-avisos), que não existe no PWA
            // Cliente.
            if (pode('/central-avisos/gerenciar'))
              _item(context, Icons.campaign_outlined, 'Meus Avisos',
                  '/central-avisos/gerenciar'),
            // Fase FLT-Treinamento (03/09/2026) — porta de /treinamento
            // da web: biblioteca de referência (módulo → lições com
            // texto/imagem/vídeo), sem progresso/conclusão (a web também
            // não tem isso). Sem gate de permissão — igual na web, a
            // rota fica de fora do mapa aba_* de propósito.
            if (pode('/treinamento'))
              _item(context, Icons.school_outlined, 'Central de Treinamento',
                  '/treinamento'),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            _grp('Sistema'),
            if (pode('/documentos'))
              _item(context, Icons.folder, 'Documentos', '/documentos'),
            if (pode('/lgpd'))
              _item(context, Icons.lock, 'Privacidade (LGPD)', '/lgpd'),
            // Fase FLT-4 — pro admin, esta MESMA rota (/permissoes) edita o
            // padrão GLOBAL do sistema em vez da empresa escolhida (ver
            // permissoes_provider.dart) — rótulo avisa a diferença, já que é
            // literalmente a mesma tela pros dois casos. Diferente da web,
            // aqui nunca existiu uma 2ª entrada de Permissões pro admin — só
            // esta, relabelada — então não precisa de exclusão extra.
            if (pode('/permissoes'))
              _item(
                  context,
                  Icons.vpn_key,
                  (sessao?.ehAdmin ?? false)
                      ? 'Permissões (padrão global)'
                      : 'Permissões',
                  '/permissoes'),
            // Fase FLT-4 — bloco exclusivo do admin (a própria tela de cada
            // uma já mostra "Acesso restrito" pra quem não é, mas nem faz
            // sentido oferecer o item de menu nesse caso).
            if (sessao?.ehAdmin ?? false) ...[
              const Divider(color: Color(0xFFE2E8F0), height: 1),
              _grp('Administração'),
              _item(context, Icons.settings, 'Configurações do Sistema',
                  '/configuracoes'),
              _item(context, Icons.star_outline, 'Avaliações dos Clientes',
                  '/avaliacoes',
                  badge: badges.avaliacoes),
              _item(context, Icons.credit_card,
                  'Assinaturas (todos os clientes)', '/assinaturas'),
              _item(context, Icons.folder_open, 'Aprovação de Documentos',
                  '/documentos-empresas',
                  badge: badges.documentosPendentes),
              _item(context, Icons.hub, 'Rede de Postos (todas)',
                  '/redes-postos'),
              _item(context, Icons.find_in_page, 'Possíveis Duplicados',
                  '/postos-duplicados'),
              _item(context, Icons.apartment, 'Clientes (todos)',
                  '/clientes-admin'),
              _item(context, Icons.account_tree, 'Grupo Econômico (todos)',
                  '/grupos-economicos'),
            ],
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            if (pode('/avisos'))
              _item(context, Icons.notifications_outlined, 'Avisos', '/avisos',
                  badge: avisosNaoLidos),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
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
      ),
    );
  }

  Widget _grp(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.glassTextoMuted)),
      );
}
