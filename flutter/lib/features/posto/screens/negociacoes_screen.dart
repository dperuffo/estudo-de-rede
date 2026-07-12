import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/negociacoes_provider.dart';

final _dataBr = DateFormat('dd/MM/yyyy');
final _dataHoraBr = DateFormat('dd/MM/yyyy HH:mm');

String _fmtData(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    return _dataBr.format(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
}

String _fmtDataHora(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    return _dataHoraBr.format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

const _filtroVigente = 'vigente';

// Fase FLT-2 — lista de negociações do posto, espelhando
// src/app/(dashboard)/negociacoes/page.tsx (lado posto). Indicadores e
// filtros calculados em memória sobre a mesma lista (até 500 registros,
// igual à web) — ver negociacoes_provider.dart.
class NegociacoesScreen extends ConsumerStatefulWidget {
  const NegociacoesScreen({super.key});

  @override
  ConsumerState<NegociacoesScreen> createState() => _NegociacoesScreenState();
}

class _NegociacoesScreenState extends ConsumerState<NegociacoesScreen> {
  String? _filtro; // null = todos

  @override
  Widget build(BuildContext context) {
    final listaAsync = ref.watch(negociacoesPostoProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(negociacoesPostoProvider),
      child: listaAsync.when(
        loading: () => const Center(
          child: Padding(padding: EdgeInsets.only(top: 80), child: CircularProgressIndicator()),
        ),
        error: (e, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [Text('Não deu pra carregar: $e', textAlign: TextAlign.center)],
        ),
        data: (lista) {
          final hojeIso = hojeIsoUtc();
          final totalVigentes = lista.where((n) => n.vigenteEm(hojeIso)).length;
          final pendentes = lista.where((n) => n.status == 'pendente_posto').length;
          final aceitas = lista.where((n) => n.status == 'aceita').length;

          final filtrada = switch (_filtro) {
            null => lista,
            _filtroVigente => lista.where((n) => n.vigenteEm(hojeIso)).toList(),
            final s => lista.where((n) => n.status == s).toList(),
          };

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text('Negociação com Clientes',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton(
                    onPressed: () => context.push('/posto/negociacoes/novo'),
                    child: const Text('+ Nova'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Propostas de fornecimento de combustível trocadas com seus clientes: vigência, '
                'volume mínimo e preço por litro.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: [
                  _indicador('Negociações', '${lista.length}'),
                  _indicador('Aguardando você', '$pendentes'),
                  _indicador('Aceitas', '$aceitas'),
                  _indicador('Vigentes agora', '$totalVigentes'),
                ],
              ),

              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('Todos', _filtro == null, () => setState(() => _filtro = null)),
                  _chip('Vigentes', _filtro == _filtroVigente, () => setState(() => _filtro = _filtroVigente)),
                  for (final s in statusNegociacao)
                    _chip(statusNegociacaoLabel[s] ?? s, _filtro == s, () => setState(() => _filtro = s)),
                ],
              ),

              const SizedBox(height: 16),
              if (filtrada.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text('Nenhuma negociação encontrada.', style: TextStyle(color: Colors.grey.shade600)),
                    ),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: filtrada
                        .map((n) => ListTile(
                              title: Text(n.clienteNome ?? '—'),
                              subtitle: Text(
                                '${statusNegociacaoLabel[n.status] ?? n.status}${n.vigenteEm(hojeIso) ? ' · Vigente' : ''}'
                                '\nRodada #${n.rodadaAtual} · ${_fmtData(n.vigenciaInicio)} – ${_fmtData(n.vigenciaFim)}'
                                '\nAtualizado em ${_fmtDataHora(n.atualizadoEm)}',
                              ),
                              isThreeLine: true,
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push('/posto/negociacoes/${n.id}'),
                            ))
                        .toList(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _indicador(String label, String valor) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(valor, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );

  Widget _chip(String label, bool selecionado, VoidCallback onTap) => ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selecionado,
        onSelected: (_) => onTap(),
      );
}
