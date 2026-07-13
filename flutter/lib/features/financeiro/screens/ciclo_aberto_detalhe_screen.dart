import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../posto/providers/ciclo_aberto_detalhe_provider.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _numero = NumberFormat.decimalPattern('pt_BR');

String _fmtData(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    return DateFormat('dd/MM/yyyy').format(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
}

enum _FiltroNfe { todos, com, pendente }

// Fase FLT-3 — pedido do Daniel: detalhamento do ciclo em andamento na
// Cobrança em Aberto (visão Cliente). Reaproveita DIRETO
// `cicloAbertoDetalheProvider`/`CicloAbertoDetalhe` (FLT-2) — a RPC
// `ciclos_abertos_postos` já devolve posto_nome E cliente_nome, então não
// precisou de nenhum campo novo, só troca o rótulo exibido pra
// `c.postoNome`.
class CicloAbertoClienteDetalheScreen extends ConsumerStatefulWidget {
  final String negociacaoId;
  const CicloAbertoClienteDetalheScreen({super.key, required this.negociacaoId});

  @override
  ConsumerState<CicloAbertoClienteDetalheScreen> createState() => _CicloAbertoClienteDetalheScreenState();
}

class _CicloAbertoClienteDetalheScreenState extends ConsumerState<CicloAbertoClienteDetalheScreen> {
  _FiltroNfe _filtro = _FiltroNfe.todos;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(cicloAbertoDetalheProvider(widget.negociacaoId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ciclo em andamento'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Não deu pra carregar: $e')),
        data: (c) {
          if (c == null) return const Center(child: Text('Ciclo não encontrado (pode já ter sido fechado).'));

          final itensFiltrados = c.itens.where((i) {
            if (_filtro == _FiltroNfe.com) return i.temNfe;
            if (_filtro == _FiltroNfe.pendente) return !i.temNfe;
            return true;
          }).toList();
          final contagemCom = c.itens.where((i) => i.temNfe).length;
          final contagemPendente = c.itens.length - contagemCom;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(cicloAbertoDetalheProvider(widget.negociacaoId)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                  child: const Text(
                    'Período, vencimento e valor são PREVISTOS e podem mudar até o fechamento — o posto '
                    'fecha automaticamente quando o ciclo termina, virando uma fatura de verdade.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF)),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Posto: ${c.postoNome ?? '—'}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('${_fmtData(c.periodoInicio)} — ${_fmtData(c.periodoFimPrevisto)} (previsto)',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                        Text('Vencimento previsto: ${_fmtData(c.vencimentoPrevisto)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        const SizedBox(height: 12),
                        Text('${_numero.format(c.quantidadeAbastecimentos)} abastecimentos · '
                            '${_numero.format(c.volumeAcumulado.round())} L · '
                            '${_moeda.format(c.valorAcumulado)}'),
                        if (c.quantidadePendenteNfe > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${c.quantidadePendenteNfe} pendente(s) de NF-e '
                            '(${_moeda.format(c.valorPendenteNfe)}, fora do acumulado)',
                            style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Detalhamento do abastecimento (${c.itens.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('Todos (${c.itens.length})'),
                      selected: _filtro == _FiltroNfe.todos,
                      onSelected: (_) => setState(() => _filtro = _FiltroNfe.todos),
                    ),
                    ChoiceChip(
                      label: Text('Com NF-e ($contagemCom)'),
                      selected: _filtro == _FiltroNfe.com,
                      onSelected: (_) => setState(() => _filtro = _FiltroNfe.com),
                    ),
                    ChoiceChip(
                      label: Text('Pendente NF-e ($contagemPendente)'),
                      selected: _filtro == _FiltroNfe.pendente,
                      onSelected: (_) => setState(() => _filtro = _FiltroNfe.pendente),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (itensFiltrados.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        c.itens.isEmpty
                            ? 'Nenhum abastecimento registrado neste ciclo ainda.'
                            : 'Nenhum abastecimento com este filtro de NF-e.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  )
                else
                  ...itensFiltrados.map((i) => _linhaItem(i)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _linhaItem(ItemExtratoCiclo i) => Card(
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (i.valorTotal != null)
                    Text(_moeda.format(i.valorTotal), style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: i.temNfe ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      i.temNfe ? 'Com NF-e' : 'Pendente NF-e',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: i.temNfe ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
