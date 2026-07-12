import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/chamados_provider.dart';

final _data = DateFormat('dd/MM/yyyy HH:mm');

String _fmtData(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    return _data.format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

const _corStatus = <String, Color>{
  'aberto': Color(0xFFB45309),
  'em_analise': Color(0xFF1D4ED8),
  'resolvido': Color(0xFF15803D),
  'fechado': Color(0xFF64748B),
};

// Fase FLT-2 — Gestão de Chamados (posto), porta com escopo reduzido (ver
// README) de chamados/page.tsx: indicadores + lista, sem o filtro de
// cliente (não se aplica — visão posto já é uma única empresa).
class ChamadosPostoScreen extends ConsumerStatefulWidget {
  const ChamadosPostoScreen({super.key});

  @override
  ConsumerState<ChamadosPostoScreen> createState() => _ChamadosPostoScreenState();
}

class _ChamadosPostoScreenState extends ConsumerState<ChamadosPostoScreen> {
  String? _filtroStatus;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(chamadosPostoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Chamados')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/posto/chamados/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Novo chamado'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Não deu pra carregar: $e')),
        data: (chamados) {
          final abertos = chamados.where((c) => c.status == 'aberto').length;
          final emAnalise = chamados.where((c) => c.status == 'em_analise').length;
          final resolvidos = chamados.where((c) => c.status == 'resolvido' || c.status == 'fechado').length;
          final naoVistos = chamados.where((c) => c.naoVisto).length;

          final filtrados =
              _filtroStatus == null ? chamados : chamados.where((c) => c.status == _filtroStatus).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(chamadosPostoProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.4,
                  children: [
                    _indicador('Abertos', abertos, const Color(0xFFB45309)),
                    _indicador('Em análise', emAnalise, const Color(0xFF1D4ED8)),
                    _indicador('Resolvidos', resolvidos, const Color(0xFF15803D)),
                    _indicador('Não vistos', naoVistos, const Color(0xFFB91C1C)),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: _filtroStatus == null,
                      onSelected: (_) => setState(() => _filtroStatus = null),
                    ),
                    ...statusTicket.entries.map((e) => ChoiceChip(
                          label: Text(e.value),
                          selected: _filtroStatus == e.key,
                          onSelected: (_) => setState(() => _filtroStatus = e.key),
                        )),
                  ],
                ),
                const SizedBox(height: 12),
                if (filtrados.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Nenhum chamado encontrado.', style: TextStyle(color: Colors.grey.shade600)),
                    ),
                  )
                else
                  ...filtrados.map((c) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: c.naoVisto ? const Color(0xFFFEF2F2) : null,
                        child: InkWell(
                          onTap: () => context.push('/posto/chamados/${c.id}'),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                if (c.naoVisto)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('#${c.numero} · ${c.titulo}',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      const SizedBox(height: 2),
                                      Text('${tiposTicket[c.tipo] ?? c.tipo} · ${_fmtData(c.criadoEm)}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (_corStatus[c.status] ?? Colors.grey).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    statusTicket[c.status] ?? c.status,
                                    style: TextStyle(
                                        fontSize: 11, color: _corStatus[c.status], fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _indicador(String label, int valor, Color cor) => Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$valor', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cor)),
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
}
