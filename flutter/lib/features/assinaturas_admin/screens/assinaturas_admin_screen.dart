import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/assinaturas_admin_provider.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _data = DateFormat('dd/MM/yyyy');
const _mesesLabel = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

// Fase FLT-4 — Assinaturas (admin): indicadores financeiros da FNI (MRR,
// faturamento, churn) + tabela de clientes, porta de assinaturas/page.tsx.
// Ver escopo em assinaturas_admin_provider.dart.
class AssinaturasAdminScreen extends ConsumerWidget {
  const AssinaturasAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessaoProvider).valueOrNull;
    final ehAdmin = sessao?.ehAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Assinaturas')),
      body: !ehAdmin ? _acessoRestrito() : _conteudo(ref),
    );
  }

  Widget _acessoRestrito() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Acesso restrito', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              SizedBox(height: 8),
              Text(
                'Esta tela é exclusiva do time interno (perfil administrador). Fale com um '
                'administrador se você precisa desses dados.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conteudo(WidgetRef ref) {
    final dadosAsync = ref.watch(assinaturasAdminProvider);
    return dadosAsync.when(
      data: (d) => _lista(d),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
    );
  }

  Widget _lista(IndicadoresFinanceirosFni d) {
    final agora = DateTime.now();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Indicadores financeiros da FNI — planos, cobrança e MRR (não é o painel de custo do cliente, '
          'que fica em Painel Financeiro).',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.0,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            _indicador('Total de clientes', '${d.totalClientes}'),
            _indicador('Em trial', '${d.totalTrial}'),
            _indicador('Ativos', '${d.totalAtivos}'),
            _indicador('Suspensos', '${d.totalSuspensos}'),
            _indicador('Cancelados', '${d.totalCancelados}'),
            _indicador('MRR estimado', _moeda.format(d.mrrCents / 100)),
          ],
        ),
        const SizedBox(height: 16),

        Text('FATURAMENTO — ${_mesesLabel[agora.month - 1].toUpperCase()} DE ${agora.year}',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.0,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            _indicador('Faturado no mês', _moeda.format(d.faturamentoMesCents / 100)),
            _indicador('Inadimplência no mês', '${_moeda.format(d.inadimplenciaMesCents / 100)} (${d.qtdInvoicesFalhas})',
                destaque: d.qtdInvoicesFalhas > 0 ? _Cor.negativo : _Cor.neutro),
            _indicador('Novos assinantes', '${d.novosAssinantesDoMes}', destaque: d.novosAssinantesDoMes > 0 ? _Cor.positivo : _Cor.neutro),
            _indicador('Churn (cancelados)', '${d.churnDoMes.length}', destaque: d.churnDoMes.isNotEmpty ? _Cor.negativo : _Cor.neutro),
          ],
        ),
        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Taxa de conversão (ativos / total)', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                const SizedBox(height: 4),
                Text('${d.taxaConversao}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (d.trialsEmRisco.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
            child: Text(
              '${d.trialsEmRisco.length} trial(s) expirando em até 3 dias sem plano contratado: '
              '${d.trialsEmRisco.map((e) => e.nome).join(", ")}.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (d.churnDoMes.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
            child: Text(
              '${d.churnDoMes.length} cliente(s) cancelaram este mês: ${d.churnDoMes.map((e) => e.nome).join(", ")}.',
              style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
            ),
          ),
          const SizedBox(height: 16),
        ],

        Text('CLIENTES (${d.empresas.length})', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        if (d.empresas.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Nenhum cliente cadastrado ainda.', style: TextStyle(color: Colors.grey.shade500))),
          )
        else
          ...d.empresas.map(_cardEmpresa),
      ],
    );
  }

  Widget _indicador(String label, String valor, {_Cor destaque = _Cor.neutro}) {
    final cor = switch (destaque) {
      _Cor.positivo => const Color(0xFF15803D),
      _Cor.negativo => const Color(0xFFDC2626),
      _Cor.neutro => Colors.black87,
    };
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(valor, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cor), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _cardEmpresa(EmpresaAssinatura e) {
    final corStatus = switch (e.status) {
      'ativo' => const Color(0xFF15803D),
      'trial' => const Color(0xFF1D4ED8),
      'suspenso' => const Color(0xFFB45309),
      _ => const Color(0xFF64748B),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(e.nome, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: corStatus.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Text(statusEmpresaLabel[e.status] ?? e.status, style: TextStyle(fontSize: 10, color: corStatus, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(planoLabel[e.plano] ?? e.plano, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 2,
              children: [
                if (e.trialEndsAt != null) Text('Trial até ${_data.format(DateTime.parse(e.trialEndsAt!))}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                Text(e.stripeCustomerId != null ? 'Stripe conectado' : 'Sem Stripe', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                if (e.createdAt != null) Text('Desde ${_data.format(DateTime.parse(e.createdAt!))}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _Cor { positivo, negativo, neutro }
