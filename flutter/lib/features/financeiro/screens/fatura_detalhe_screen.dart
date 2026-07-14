import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../posto/providers/fatura_posto_detalhe_provider.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _numero = NumberFormat.decimalPattern('pt_BR');

// Fase CICLOS-6 — 5 status agora: fechada (janela terminou, boleto ainda
// não gerado), a_vencer (boleto gerado, aguardando pagamento), vencida
// (derivado), paga, cancelada.
const _statusFaturaLabel = <String, String>{
  'fechada': 'Fechada',
  'a_vencer': 'A vencer',
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
  if (status == 'a_vencer' && vencimento != null) {
    final hoje = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (vencimento.substring(0, 10).compareTo(hoje) < 0) return 'vencida';
  }
  return status;
}

// Fase FLT-3 — pedido do Daniel: detalhamento de fatura na Cobrança em
// Aberto (visão Cliente). Reaproveita DIRETO `faturaPostoDetalheProvider`/
// `FaturaPostoDetalhe` (FLT-2) — a consulta já é genérica (busca por id,
// RLS decide quem pode ver), só muda o rótulo exibido: "Posto" em vez de
// "Cliente" (campo `postoNome`, adicionado ao provider nesta fase).
class FaturaDetalheScreen extends ConsumerWidget {
  final String id;
  const FaturaDetalheScreen({super.key, required this.id});

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
          // Fase CICLOS-6 — enquanto 'fechada', ainda não existe valor/boleto
          // de verdade (o robô só trava isso na 2ª fase, ver
          // data_geracao_boleto).
          final boletoJaGerado = f.status != 'fechada';
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
                        if (!boletoJaGerado)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'O ciclo já fechou, mas o boleto ainda não foi gerado — aguardando até '
                                '${_fmtData(f.dataGeracaoBoleto)} pra dar tempo das notas fiscais chegarem.',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text('Posto: ${f.postoNome ?? '—'}', style: const TextStyle(fontSize: 13)),
                        Text('Vencimento: ${_fmtData(f.vencimento)}', style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Volume total', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  Text(boletoJaGerado ? '${_numero.format(f.volumeTotal)} L' : '—',
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Valor total', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  Text(boletoJaGerado ? _moeda.format(f.valorTotal) : '—',
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
                if (!boletoJaGerado)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                          'Disponível quando o boleto for gerado (${_fmtData(f.dataGeracaoBoleto)}).',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ),
                  )
                else if (f.itens.isEmpty)
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
