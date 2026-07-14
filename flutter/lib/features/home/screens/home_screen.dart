import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/sessao_usuario.dart';
import '../../../core/widgets/menu_button.dart';

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

    return Scaffold(
      key: rootScaffoldKey,
      drawer: _buildDrawer(context, ref, sessao.valueOrNull),
      appBar: AppBar(title: const Text('FNI — Gestão de Frotas')),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx(loc),
        onDestinationSelected: (i) => _nav(context, i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Painel'),
          NavigationDestination(icon: Icon(Icons.local_gas_station), label: 'Abastec.'),
          NavigationDestination(icon: Icon(Icons.directions_car), label: 'Veículos'),
          NavigationDestination(icon: Icon(Icons.attach_money), label: 'Financ.'),
          NavigationDestination(icon: Icon(Icons.menu), label: 'Mais'),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref, SessaoUsuario? sessao) {
    final nomeEmpresa = sessao?.nomeEmpresa;
    final temMultiplasEmpresas = (sessao?.empresasIds.length ?? 0) > 1;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Mesmo cabeçalho da visão Posto (identidade visual da web:
          // fundo frota-950, card branco com a logo, rótulo do perfil em
          // ciano frota-500) — ver posto_home_screen.dart pro histórico do
          // porquê desse formato (DrawerHeader trocado por Container
          // simples pra não ter altura mínima forçada / overflow).
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
                      nomeEmpresa ?? 'Minha empresa',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'FROTA',
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
                              Text('Trocar empresa',
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
          _item(context, Icons.dashboard, 'Dashboard', '/dashboard'),
          _item(context, Icons.smart_toy, 'Assistente FNI', '/assistente'),
          _item(context, Icons.credit_card, 'Minha Assinatura', '/assinatura'),
          _item(context, Icons.star, 'Avaliar Plataforma', '/avaliar'),
          _item(context, Icons.attach_money, 'Painel Financeiro', '/financeiro'),
          _item(context, Icons.folder, 'Documentos', '/documentos'),
          _item(context, Icons.hub, 'Inteligência de Rede', '/inteligencia-rede'),
          _item(context, Icons.lock, 'Privacidade (LGPD)', '/lgpd'),
          _item(context, Icons.confirmation_number, 'Chamados', '/chamados'),
          const Divider(),
          _grp('Cadastros'),
          _item(context, Icons.business, 'Clientes', '/clientes'),
          _item(context, Icons.account_tree, 'Grupo Econômico', '/grupo-economico'),
          _item(context, Icons.people, 'Usuários', '/usuarios'),
          _item(context, Icons.badge, 'Motoristas', '/motoristas'),
          _item(context, Icons.directions_car, 'Veículos', '/veiculos'),
          _item(context, Icons.receipt_long, 'Centros de Custo', '/centros-custo'),
          _item(context, Icons.local_gas_station, 'Postos Revendedores', '/postos'),
          const Divider(),
          _grp('Operação'),
          _item(context, Icons.local_gas_station, 'Abastecimentos', '/abastecimentos'),
          _item(context, Icons.description, 'Notas Fiscais', '/notas-fiscais'),
          _item(context, Icons.warning_amber, 'Anomalias', '/anomalias'),
          _item(context, Icons.route, 'Roteirização', '/roteirizacao'),
          _item(context, Icons.shield_outlined, 'Rotograma', '/rotograma'),
          _item(context, Icons.card_travel, 'Planos de Viagem', '/planos-viagem'),
          _item(context, Icons.handshake, 'Negociações com Postos', '/negociacoes'),
          _item(context, Icons.sell, 'Preços dos Postos Parceiros', '/precos-postos'),
          _item(context, Icons.build, 'Manutenção Preditiva', '/manutencao-preditiva'),
          _item(context, Icons.tune, 'Parâmetros de Uso', '/parametros-uso'),
          _item(context, Icons.bar_chart, 'Relatórios', '/relatorios'),
          const Divider(),
          // Fase FLT-4 — pro admin, esta MESMA rota (/permissoes) edita o
          // padrão GLOBAL do sistema em vez da empresa escolhida (ver
          // permissoes_provider.dart) — rótulo avisa a diferença, já que é
          // literalmente a mesma tela pros dois casos.
          _grp((sessao?.ehAdmin ?? false) ? 'Administração' : 'Configurações'),
          _item(context, Icons.vpn_key, (sessao?.ehAdmin ?? false) ? 'Permissões (padrão global)' : 'Permissões', '/permissoes'),
          // Fase FLT-4 — Configurações do Sistema: exclusiva do admin (a
          // própria tela já mostra "Acesso restrito" pra quem não é, mas
          // nem faz sentido oferecer o item de menu nesse caso).
          if (sessao?.ehAdmin ?? false) _item(context, Icons.settings, 'Configurações do Sistema', '/configuracoes'),
          if (sessao?.ehAdmin ?? false) _item(context, Icons.star_outline, 'Avaliações dos Clientes', '/avaliacoes'),
          if (sessao?.ehAdmin ?? false) _item(context, Icons.credit_card, 'Assinaturas (todos os clientes)', '/assinaturas'),
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

  ListTile _item(BuildContext context, IconData icon, String label, String route) => ListTile(
        dense: true,
        leading: Icon(icon, color: const Color(0xFF0D2D6B), size: 20),
        title: Text(label, style: const TextStyle(fontSize: 14)),
        onTap: () {
          Navigator.pop(context);
          context.go(route);
        },
      );

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
