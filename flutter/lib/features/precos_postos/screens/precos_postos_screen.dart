import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/precos_postos_provider.dart';

// Fase FLT-3 — Preços dos Postos Parceiros (cliente). Ver escopo em
// precos_postos_provider.dart.
class PrecosPostosScreen extends ConsumerWidget {
  const PrecosPostosScreen({super.key});

  String _dataHora(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    return DateFormat('dd/MM/yyyy HH:mm').format(d.toLocal());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postosAsync = ref.watch(precosPostosParceirosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Preços dos Postos Parceiros')),
      body: postosAsync.when(
        data: (postos) => _conteudo(context, postos),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
      ),
    );
  }

  Widget _conteudo(BuildContext context, List<PostoComPrecos> postos) {
    if (postos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Você ainda não tem negociação com nenhum posto — os preços aparecem aqui assim que houver pelo menos uma negociação.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Preços informados pelos postos com quem você tem alguma negociação, pendente ou fechada.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        for (final posto in postos) _cardPosto(posto),
      ],
    );
  }

  Widget _cardPosto(PostoComPrecos posto) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(posto.nome, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 10),
            if (posto.precos.isEmpty)
              Text('Este posto ainda não informou preços.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 34,
                  dataRowMinHeight: 34,
                  dataRowMaxHeight: 46,
                  columns: const [
                    DataColumn(label: Text('Combustível', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Preço/L', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Atualizado em', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Atualizado por', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                  ],
                  rows: posto.precos
                      .map((p) => DataRow(cells: [
                            DataCell(Text(p.combustivel, style: const TextStyle(fontSize: 12))),
                            DataCell(Text('R\$ ${p.preco.toStringAsFixed(3)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                            DataCell(Text(_dataHora(p.atualizadoEm), style: const TextStyle(fontSize: 11))),
                            DataCell(Text(p.atualizadoPor ?? '—', style: const TextStyle(fontSize: 11))),
                          ]))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
