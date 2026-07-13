import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/assinatura_provider.dart';
import '../services/assinatura_service.dart';
import 'termo_adesao_dialog.dart';

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

// Fase FLT-2 — porta de src/app/(dashboard)/assinatura/page.tsx, escopo
// reduzido ao caminho posto (ver assinatura_provider.dart). Sem o
// comprovante em PDF do Termo de Adesão (ver aviso em assinatura_service.dart).
class AssinaturaScreen extends ConsumerStatefulWidget {
  const AssinaturaScreen({super.key});

  @override
  ConsumerState<AssinaturaScreen> createState() => _AssinaturaScreenState();
}

class _AssinaturaScreenState extends ConsumerState<AssinaturaScreen> {
  bool _processando = false;

  Future<void> _assinar(String empresaId, String plano, String planoLabel, String precoLabel) async {
    final aceitou = await mostrarModalTermoAdesao(context, planoLabel: planoLabel, precoLabel: precoLabel);
    if (!aceitou || !mounted) return;

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
    final assinaturaAsync = ref.watch(assinaturaProvider);
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

  Widget _buildConteudo(BuildContext context, AssinaturaDetalhe dados, Map<String, PrecoPlano> precos) {
    final empresa = dados.empresa;
    int? diasRestantesTrial;
    if (empresa.status == 'trial' && empresa.trialEndsAt != null) {
      final fim = DateTime.tryParse(empresa.trialEndsAt!);
      if (fim != null) {
        diasRestantesTrial = (fim.difference(DateTime.now()).inHours / 24).ceil();
      }
    }
    final planoRecomendado = planoRecomendadoPorRede(dados.qtdPostosNaRede);

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
                _indicador('Postos na Rede', '${dados.qtdPostosNaRede}'),
                _indicador(
                  'Pagamento',
                  empresa.stripeCustomerId != null ? 'Configurado' : 'Não configurado',
                ),
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
            const SizedBox(height: 4),
            Text(
              'Sua rede tem ${dados.qtdPostosNaRede} posto${dados.qtdPostosNaRede == 1 ? '' : 's'} — recomendamos '
              'o plano ${_planoLabel[planoRecomendado]} (destacado abaixo).',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ...['basico', 'profissional', 'enterprise'].map((plano) {
              final ehAtual = empresa.plano == plano && empresa.status == 'ativo';
              final ehRecomendado = !ehAtual && plano == planoRecomendado;
              final precoLabel = formatarPrecoPlano(precos[plano]);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: ehAtual ? const Color(0xFFEFF6FF) : (ehRecomendado ? const Color(0xFFF8FAFC) : null),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: ehAtual ? const Color(0xFF1D4ED8) : Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (ehRecomendado)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D4ED8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Recomendado',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      Text(_planoLabel[plano]!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(precoLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D2D6B))),
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
                            onPressed: () => _assinar(empresa.id, plano, _planoLabel[plano]!, precoLabel),
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
              onTap: () => context.push('/posto/chamados/novo'),
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
