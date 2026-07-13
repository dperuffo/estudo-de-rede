import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../posto/providers/assinatura_provider.dart' show precosPlanosProvider, formatarPrecoPlano, PrecoPlano;
import '../../posto/services/assinatura_service.dart';
import '../providers/assinatura_cliente_provider.dart';

const _statusLabel = <String, String>{
  'trial': 'Em teste (trial)',
  'ativo': 'Ativo',
  'suspenso': 'Suspenso',
  'cancelado': 'Cancelado',
};

const _planoLabel = <String, String>{
  'gratuito': 'Gratuito',
  'basico': 'Básico',
  'profissional': 'Profissional',
  'enterprise': 'Enterprise',
};

// Fase FLT-3 — porta de assinatura/page.tsx pro shell Cliente (dimensiona
// por uso de usuários/veículos — ver assinatura_cliente_provider.dart pro
// porquê de não reaproveitar o provider do Posto, que dimensiona por
// tamanho da Rede de Postos). `AssinaturaService` (checkout/portal Stripe)
// e `precosPlanosProvider`/`formatarPrecoPlano` (preços reais via Edge
// Function) são 100% genéricos — importados direto do Posto, sem
// duplicar. Sem recomendação de plano automática (a web também não
// recomenda pra quem não é posto — só mostra uso vs. limite de cada
// plano) e sem o comprovante em PDF do Termo de Adesão (mesmo motivo já
// documentado em assinatura_service.dart).
class AssinaturaClienteScreen extends ConsumerStatefulWidget {
  const AssinaturaClienteScreen({super.key});

  @override
  ConsumerState<AssinaturaClienteScreen> createState() => _AssinaturaClienteScreenState();
}

class _AssinaturaClienteScreenState extends ConsumerState<AssinaturaClienteScreen> {
  bool _processando = false;

  Future<void> _assinar(String empresaId, String plano) async {
    setState(() => _processando = true);
    final resultado = await AssinaturaService().criarCheckout(empresaId: empresaId, plano: plano);
    if (!mounted) return;
    setState(() => _processando = false);

    if (resultado.erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resultado.erro!)));
      return;
    }
    await launchUrl(Uri.parse(resultado.url!), mode: LaunchMode.externalApplication);
  }

  Future<void> _abrirPortal(String empresaId) async {
    setState(() => _processando = true);
    final resultado = await AssinaturaService().abrirPortalPagamento(empresaId: empresaId);
    if (!mounted) return;
    setState(() => _processando = false);

    if (resultado.erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resultado.erro!)));
      return;
    }
    await launchUrl(Uri.parse(resultado.url!), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final assinaturaAsync = ref.watch(assinaturaClienteProvider);
    final precosAsync = ref.watch(precosPlanosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Minha Assinatura')),
      body: assinaturaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (dados) {
          if (dados == null) return const Center(child: Text('Nenhuma empresa selecionada.'));
          final precos = precosAsync.valueOrNull ?? {};
          return _buildConteudo(context, dados, precos);
        },
      ),
    );
  }

  Widget _buildConteudo(BuildContext context, AssinaturaClienteDetalhe dados, Map<String, PrecoPlano> precos) {
    final empresa = dados.empresa;
    int? diasRestantesTrial;
    if (empresa.status == 'trial' && empresa.trialEndsAt != null) {
      final fim = DateTime.tryParse(empresa.trialEndsAt!);
      if (fim != null) {
        diasRestantesTrial = (fim.difference(DateTime.now()).inHours / 24).ceil();
      }
    }
    final limites = limitesPlano[empresa.plano];

    return AbsorbPointer(
      absorbing: _processando,
      child: Opacity(
        opacity: _processando ? 0.6 : 1,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Plano atual, uso e histórico de cobrança.',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _indicador('Plano atual', _planoLabel[empresa.plano] ?? empresa.plano),
                _indicador('Status', _statusLabel[empresa.status] ?? empresa.status),
                _indicador('Usuários',
                    '${dados.qtdUsuarios} / ${limites != null && limites.maxUsuarios >= 0 ? limites.maxUsuarios : '∞'}'),
                _indicador('Veículos',
                    '${dados.qtdVeiculos} / ${limites != null && limites.maxVeiculos >= 0 ? limites.maxVeiculos : '∞'}'),
              ],
            ),
            if (diasRestantesTrial != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: diasRestantesTrial <= 3 ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  diasRestantesTrial > 0
                      ? 'Seu trial termina em $diasRestantesTrial dia${diasRestantesTrial == 1 ? '' : 's'}. Escolha um plano abaixo para continuar sem interrupção.'
                      : 'Seu trial expirou. Escolha um plano abaixo para reativar o acesso.',
                  style: TextStyle(
                    fontSize: 13,
                    color: diasRestantesTrial <= 3 ? const Color(0xFFB91C1C) : const Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Text('Planos disponíveis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ...['basico', 'profissional', 'enterprise'].map((plano) {
              final ehAtual = empresa.plano == plano && empresa.status == 'ativo';
              final limitesPlanoCard = limitesPlano[plano]!;
              final precoLabel = formatarPrecoPlano(precos[plano]);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: ehAtual ? const Color(0xFFEFF6FF) : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: ehAtual ? const Color(0xFF1D4ED8) : Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_planoLabel[plano]!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(precoLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D2D6B))),
                      const SizedBox(height: 4),
                      Text(
                        '${limitesPlanoCard.maxUsuarios < 0 ? 'Usuários ilimitados' : '${limitesPlanoCard.maxUsuarios} usuário(s)'} · '
                        '${limitesPlanoCard.maxVeiculos < 0 ? 'veículos ilimitados' : '${limitesPlanoCard.maxVeiculos} veículos'}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      if (ehAtual)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Plano atual',
                              style: TextStyle(color: Color(0xFF15803D), fontSize: 12, fontWeight: FontWeight.w600)),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => _assinar(empresa.id, plano),
                            child: Text('Assinar ${_planoLabel[plano]}'),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pagamento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          const Text(
                            'Gerencie forma de pagamento, baixe recibos ou cancele a assinatura direto pelo portal do Stripe.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (empresa.stripeCustomerId != null)
                      OutlinedButton(
                        onPressed: () => _abrirPortal(empresa.id),
                        child: const Text('Gerenciar'),
                      )
                    else
                      const Text('Assine um plano pago\npara gerenciar',
                          textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Histórico de faturas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            if (dados.invoices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Nenhuma fatura registrada ainda.', style: TextStyle(color: Colors.grey)),
              )
            else
              ...dados.invoices.map((inv) => Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      title: Text(_periodoFatura(inv.periodoInicio, inv.periodoFim)),
                      subtitle: Text(_dataFormatada(inv.criadoEm)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_valorFatura(inv.valorCents), style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(inv.status,
                              style: TextStyle(
                                fontSize: 11,
                                color: inv.status == 'pago' ? const Color(0xFF15803D) : Colors.grey,
                              )),
                        ],
                      ),
                    ),
                  )),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => context.push('/chamados'),
              child: const Text.rich(
                TextSpan(
                  text: 'Dúvidas sobre cobrança? ',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  children: [
                    TextSpan(text: 'Abra um chamado.', style: TextStyle(color: Color(0xFF1D4ED8))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _indicador(String label, String valor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(valor, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  String _periodoFatura(String? inicio, String? fim) {
    if (inicio == null || fim == null) return '—';
    final i = DateTime.tryParse(inicio);
    final f = DateTime.tryParse(fim);
    if (i == null || f == null) return '—';
    return '${_dataFormatada(inicio, curta: true)} – ${_dataFormatada(fim, curta: true)}';
  }

  String _dataFormatada(String iso, {bool curta = false}) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    final dia = d.day.toString().padLeft(2, '0');
    final mes = d.month.toString().padLeft(2, '0');
    return curta ? '$dia/$mes' : '$dia/$mes/${d.year}';
  }

  String _valorFatura(int? cents) {
    if (cents == null) return '—';
    final valor = cents / 100;
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }
}
