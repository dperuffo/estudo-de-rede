import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/notas_fiscais_provider.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _numero = NumberFormat.decimalPattern('pt_BR');
final _dataBr = DateFormat('dd/MM/yyyy');

String _fmtData(String iso) {
  try {
    return _dataBr.format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

// Fase FLT-3 — detalhe de NF-e (cliente), porta de notas-fiscais/[notaId]/
// page.tsx. Sem o botão "Baixar PDF" (a web monta o PDF via jsPDF em
// memória — fora do escopo v1 mobile, ver comentário em
// notas_fiscais_provider.dart).
class NotaFiscalDetalheScreen extends ConsumerWidget {
  final String notaId;
  const NotaFiscalDetalheScreen({super.key, required this.notaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notaFiscalDetalheProvider(notaId));

    return Scaffold(
      appBar: AppBar(title: const Text('NF-e')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (nota) {
          if (nota == null) return const Center(child: Text('Nota fiscal não encontrada.'));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('NF-e Nº ${nota.numeroNf.toString().padLeft(6, '0')}',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Série ${nota.serieNf} · Emitida em ${_fmtData(nota.dataEmissao)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _cardParte('Emitente (posto)', nota.nomeEmitente, nota.cnpjEmitente)),
                  const SizedBox(width: 10),
                  Expanded(child: _cardParte('Destinatário (cliente)', nota.nomeDestinatario, nota.cnpjDestinatario)),
                ],
              ),
              const SizedBox(height: 16),
              Text('Item de combustível', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nota.produtoNomeXml, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('Código ANP: ${nota.produtoCodigoAnp} — ${nota.produtoDescricaoAnp}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const Divider(height: 20),
                      _linha('Litros', '${_numero.format(nota.quantidade)} L'),
                      _linha('Preço/L', _moeda.format(nota.valorUnitario)),
                      _linha('Valor total', _moeda.format(nota.valorTotal), destaque: true),
                    ],
                  ),
                ),
              ),
              if (nota.abastecimentoData != null || nota.veiculoPlaca != null || nota.motoristaNome != null) ...[
                const SizedBox(height: 16),
                Text('Abastecimento vinculado', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (nota.abastecimentoData != null) _linha('Data', _fmtData(nota.abastecimentoData!)),
                        if (nota.veiculoPlaca != null) _linha('Placa', nota.veiculoPlaca!),
                        if (nota.motoristaNome != null) _linha('Motorista', nota.motoristaNome!),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text('Chave de acesso: ${nota.chaveAcesso}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          );
        },
      ),
    );
  }

  Widget _cardParte(String rotulo, String nome, String cnpj) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rotulo.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(nome, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 2),
            Text('CNPJ: $cnpj', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _linha(String rotulo, String valor, {bool destaque = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(rotulo, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(valor,
              style: TextStyle(fontSize: 13, fontWeight: destaque ? FontWeight.bold : FontWeight.w500)),
        ],
      ),
    );
  }
}
