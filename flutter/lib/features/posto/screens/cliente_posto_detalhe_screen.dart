import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/cliente_posto_detalhe_provider.dart';
import '../providers/clientes_posto_provider.dart';
import '../providers/negociacoes_provider.dart' show statusNegociacaoLabel;

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _numero = NumberFormat.decimalPattern('pt_BR');

const _statusFaturaLabel = <String, String>{
  'aberta': 'Em aberto',
  'vencida': 'Vencida',
  'paga': 'Paga',
  'cancelada': 'Cancelada',
};

String _fmtData(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final d = DateTime.parse(iso);
    return DateFormat('dd/MM/yyyy').format(d);
  } catch (_) {
    return iso;
  }
}

String _statusFaturaExibicao(String status, String? vencimento) {
  if (status == 'aberta' && vencimento != null) {
    final hoje = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (vencimento.substring(0, 10).compareTo(hoje) < 0) return 'vencida';
  }
  return status;
}

// Fase FLT-2 — detalhe de UM cliente da visão Posto: cadastro + ciclo em
// andamento + faturas + negociações. Porta com escopo reduzido (ver
// README) de clientes-posto/[clienteId]/page.tsx +
// CicloAbastecimentoPagamento.tsx.
class ClientePostoDetalheScreen extends ConsumerWidget {
  final String id;
  const ClientePostoDetalheScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(clientePostoDetalheProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cliente'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/posto/clientes'),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Não deu pra carregar: $e')),
        data: (d) {
          if (d.cliente == null) {
            return const Center(child: Text('Cliente não encontrado.'));
          }
          final c = d.cliente!;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(clientePostoDetalheProvider(id)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('CNPJ: ${formatarCnpj(c.cnpj)}', style: const TextStyle(fontSize: 13)),
                        if (c.municipio != null)
                          Text('Cidade/UF: ${c.municipio}/${c.uf ?? ''}', style: const TextStyle(fontSize: 13)),
                        if (c.segmentoTransporte != null)
                          Text('Segmento: ${c.segmentoTransporte}', style: const TextStyle(fontSize: 13)),
                        if (c.porte != null) Text('Porte: ${c.porte}', style: const TextStyle(fontSize: 13)),
                        if (c.telefoneContato != null)
                          Text('Telefone: ${c.telefoneContato}', style: const TextStyle(fontSize: 13)),
                        if (c.emailContato != null)
                          Text('E-mail: ${c.emailContato}', style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Ciclo em andamento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (d.cicloAtual == null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Nenhum ciclo em andamento agora.', style: TextStyle(color: Colors.grey.shade600)),
                    ),
                  )
                else
                  Card(
                    child: InkWell(
                      onTap: () => context.push('/posto/ciclos-abertos/${d.cicloAtual!.negociacaoId}'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                      '${_fmtData(d.cicloAtual!.periodoInicio)} — ${_fmtData(d.cicloAtual!.periodoFimPrevisto)}',
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                              ],
                            ),
                            Text('Vencimento previsto: ${_fmtData(d.cicloAtual!.vencimentoPrevisto)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            const SizedBox(height: 8),
                            Text('${_numero.format(d.cicloAtual!.quantidadeAbastecimentos)} abastecimentos · '
                                '${_numero.format(d.cicloAtual!.volumeAcumulado.round())} L · '
                                '${_moeda.format(d.cicloAtual!.valorAcumulado)}'),
                            if (d.cicloAtual!.quantidadePendenteNfe > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${d.cicloAtual!.quantidadePendenteNfe} sem NF-e ainda (${_moeda.format(d.cicloAtual!.valorPendenteNfe)}, fora do acumulado)',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
                const Text('Faturas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (d.faturas.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Nenhuma fatura ainda.', style: TextStyle(color: Colors.grey.shade600)),
                    ),
                  )
                else
                  ...d.faturas.map((f) => _linhaFatura(context, f)),

                const SizedBox(height: 20),
                const Text('Negociações', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (d.negociacoes.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Nenhuma negociação com este cliente.', style: TextStyle(color: Colors.grey.shade600)),
                    ),
                  )
                else
                  ...d.negociacoes.map((n) => _linhaNegociacao(context, n)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _linhaFatura(BuildContext context, FaturaDoCliente f) {
    final statusExib = _statusFaturaExibicao(f.status, f.vencimento);
    final cor = switch (statusExib) {
      'paga' => const Color(0xFF15803D),
      'vencida' => const Color(0xFFB91C1C),
      'cancelada' => Colors.grey,
      _ => const Color(0xFF92400E),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.push('/posto/faturas/${f.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_fmtData(f.periodoInicio)} — ${_fmtData(f.periodoFim)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('Vencimento: ${_fmtData(f.vencimento)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_moeda.format(f.valorTotal), style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(_statusFaturaLabel[statusExib] ?? statusExib,
                      style: TextStyle(fontSize: 11, color: cor, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linhaNegociacao(BuildContext context, NegociacaoDoCliente n) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: () => context.push('/posto/negociacoes/${n.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.combustivel ?? '—', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      if (n.vigenciaInicio != null)
                        Text('${_fmtData(n.vigenciaInicio)} — ${_fmtData(n.vigenciaFim)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                  child: Text(statusNegociacaoLabel[n.status] ?? n.status, style: const TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
              ],
            ),
          ),
        ),
      );
}
