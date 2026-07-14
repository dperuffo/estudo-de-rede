import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../posto/providers/negociacoes_provider.dart' show statusNegociacao, statusNegociacaoLabel;
import '../providers/negociacoes_cliente_provider.dart';

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

// Fase FLT-3 — lista de negociações do cliente, espelhando
// src/app/(dashboard)/negociacoes/page.tsx (lado cliente) e a tela
// equivalente do posto (FLT-2, negociacoes_screen.dart em
// lib/features/posto/screens/).
class NegociacoesClienteScreen extends ConsumerStatefulWidget {
  const NegociacoesClienteScreen({super.key});

  @override
  ConsumerState<NegociacoesClienteScreen> createState() => _NegociacoesClienteScreenState();
}

class _NegociacoesClienteScreenState extends ConsumerState<NegociacoesClienteScreen> {
  String? _filtro;

  @override
  Widget build(BuildContext context) {
    final listaAsync = ref.watch(negociacoesClienteProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Negociação com Postos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/negociacoes/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Nova'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(negociacoesClienteProvider),
        child: listaAsync.when(
          loading: () => const Center(
            child: Padding(padding: EdgeInsets.only(top: 80), child: CircularProgressIndicator()),
          ),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [Text('Não deu pra carregar: $e', textAlign: TextAlign.center)],
          ),
          data: (lista) {
            final hojeIso = hojeIsoUtcCliente();
            final totalVigentes = lista.where((n) => n.vigenteEm(hojeIso)).length;
            final pendentes = lista.where((n) => n.status == 'pendente_cliente').length;
            final aceitas = lista.where((n) => n.status == 'aceita').length;

            final filtrada = switch (_filtro) {
              null => lista,
              _filtroVigente => lista.where((n) => n.vigenteEm(hojeIso)).toList(),
              final s => lista.where((n) => n.status == s).toList(),
            };

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                const Text(
                  'Vigência, combustível, volume mínimo e preço por litro negociados com os postos parceiros.',
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
                    _indicador('Aguardando sua resposta', '$pendentes'),
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
                                title: Text(n.postoNome ?? n.postoCnpj),
                                subtitle: Text(
                                  '${statusNegociacaoLabel[n.status] ?? n.status}${n.vigenteEm(hojeIso) ? ' · Vigente' : ''}'
                                  '\nRodada #${n.rodadaAtual} · ${_fmtData(n.vigenciaInicio)} – ${_fmtData(n.vigenciaFim)}'
                                  '\nAtualizado em ${_fmtDataHora(n.atualizadoEm)}',
                                ),
                                isThreeLine: true,
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.push('/negociacoes/${n.id}'),
                              ))
                          .toList(),
                    ),
                  ),
              ],
            );
          },
        ),
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
