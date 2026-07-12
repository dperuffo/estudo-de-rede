import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/fatura_posto_detalhe_provider.dart';

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
    return DateFormat('dd/MM/yyyy').format(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
}

String _statusExibicao(String status, String? vencimento) {
  if (status == 'aberta' && vencimento != null) {
    final hoje = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (vencimento.substring(0, 10).compareTo(hoje) < 0) return 'vencida';
  }
  return status;
}

// Fase FLT-2 — detalhe/extrato de uma fatura, porta com escopo reduzido
// (ver README) de faturas-postos/[id]/page.tsx. Sem boleto/PDF/PIX — só
// leitura do período, valor e do detalhamento dos abastecimentos.
class FaturaPostoDetalheScreen extends ConsumerWidget {
  final String id;
  const FaturaPostoDetalheScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(faturaPostoDetalheProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fatura'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Não deu pra carregar: $e')),
        data: (f) {
          if (f == null) return const Center(child: Text('Fatura não encontrada.'));
          final statusExib = _statusExibicao(f.status, f.vencimento);
          final cor = switch (statusExib) {
            'paga' => const Color(0xFF15803D),
            'vencida' => const Color(0xFFB91C1C),
            'cancelada' => Colors.grey,
            _ => const Color(0xFF92400E),
          };
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(faturaPostoDetalheProvider(id)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (f.numeroFatura != null)
                          Text('Fatura nº ${f.numeroFatura.toString().padLeft(6, '0')}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('${_fmtData(f.periodoInicio)} — ${_fmtData(f.periodoFim)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Cliente: ${f.clienteNome ?? '—'}', style: const TextStyle(fontSize: 13)),
                        Text('Vencimento: ${_fmtData(f.vencimento)}', style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Volume total', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  Text('${_numero.format(f.volumeTotal)} L',
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Valor total', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  Text(_moeda.format(f.valorTotal),
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Status', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                Text(_statusFaturaLabel[statusExib] ?? statusExib,
                                    style: TextStyle(fontWeight: FontWeight.w600, color: cor)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Detalhamento do abastecimento (${f.quantidadeAbastecimentos})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Abastecimentos que justificam o valor total cobrado.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                if (f.itens.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Nenhum abastecimento encontrado neste período.',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ),
                  )
                else
                  ...f.itens.map((i) => _linhaItem(i)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _linhaItem(ItemExtratoAbastecimento i) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_fmtData(i.data)} · ${i.combustivel ?? '—'}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('${i.motorista ?? '—'} · ${i.placa ?? '—'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    if (i.litros != null)
                      Text(
                          '${_numero.format(i.litros)} L'
                          '${i.precoUnitario != null ? ' · ${_moeda.format(i.precoUnitario)}/L' : ''}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              if (i.valorTotal != null)
                Text(_moeda.format(i.valorTotal), style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}
