import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/notas_fiscais_provider.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _dataBr = DateFormat('dd/MM/yyyy');

String _fmtData(String iso) {
  try {
    return _dataBr.format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

// Interpola vermelho -> âmbar -> verde conforme o percentual sobe — mesma
// lógica de corDoPercentual() (IndicadorNotasFiscais.tsx / RecolhaPorCiclo.tsx).
Color _corDoPercentual(double p) {
  final pc = p.clamp(0, 100);
  const vermelho = Color(0xFFDC2626);
  const ambar = Color(0xFFD97706);
  const verde = Color(0xFF16A34A);
  if (pc <= 50) return Color.lerp(vermelho, ambar, pc / 50)!;
  return Color.lerp(ambar, verde, (pc - 50) / 50)!;
}

const _statusLabel = <String, String>{
  'aberto': 'Ciclo aberto',
  'fechada': 'Fechada',
  'a_vencer': 'A vencer',
  'vencida': 'Vencida',
  'paga': 'Paga',
  'cancelada': 'Cancelada',
};

const _statusCor = <String, Color>{
  'aberto': Color(0xFF1D4ED8),
  'fechada': Color(0xFF64748B),
  'a_vencer': Color(0xFFB45309),
  'vencida': Color(0xFFB91C1C),
  'paga': Color(0xFF15803D),
  'cancelada': Color(0xFF94A3B8),
};

class NotasFiscaisScreen extends ConsumerStatefulWidget {
  const NotasFiscaisScreen({super.key});

  @override
  ConsumerState<NotasFiscaisScreen> createState() => _NotasFiscaisScreenState();
}

class _NotasFiscaisScreenState extends ConsumerState<NotasFiscaisScreen> {
  final _buscaCtrl = TextEditingController();
  String? _status;
  String _buscaAplicada = '';
  // Fase NFE-1 — ciclo escolhido pelo card selecionado (null = ainda não
  // escolheu, cai no primeiro card assim que a lista de ciclos carregar).
  CicloNfe? _cicloEscolhido;

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ciclosAsync = ref.watch(ciclosNfeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notas Fiscais')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ciclosNfeProvider);
        },
        child: ciclosAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.only(top: 80), child: CircularProgressIndicator())),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [Text('Erro ao carregar ciclos: $e')],
          ),
          data: (ciclos) {
            final cicloAtivo = _cicloEscolhido ?? (ciclos.isNotEmpty ? ciclos.first : null);
            final filtros = cicloAtivo == null
                ? null
                : FiltrosNotasFiscais(
                    negociacaoId: cicloAtivo.negociacaoId,
                    periodoInicio: cicloAtivo.periodoInicio,
                    periodoFim: cicloAtivo.periodoFim,
                    status: _status,
                    busca: _buscaAplicada.isEmpty ? null : _buscaAplicada,
                  );
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Recolha de notas fiscais por ciclo', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                if (ciclos.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Nenhum ciclo de faturamento encontrado ainda.',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ),
                  )
                else
                  ...ciclos.map((c) => _cardCiclo(c, selecionado: cicloAtivo?.negociacaoId == c.negociacaoId && cicloAtivo?.periodoInicio == c.periodoInicio && cicloAtivo?.periodoFim == c.periodoFim)),
                const SizedBox(height: 16),
                TextField(
                  controller: _buscaCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por ID, placa, posto ou cliente...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: _buscaCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _buscaCtrl.clear();
                              setState(() => _buscaAplicada = '');
                            },
                          ),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) => setState(() => _buscaAplicada = v.trim()),
                ),
                const SizedBox(height: 10),
                if (cicloAtivo != null)
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text('Todos (${cicloAtivo.total})'),
                        selected: _status == null,
                        onSelected: (_) => setState(() => _status = null),
                      ),
                      ChoiceChip(
                        label: Text('Emitida (${cicloAtivo.comNota})'),
                        selected: _status == 'emitida',
                        onSelected: (_) => setState(() => _status = 'emitida'),
                      ),
                      ChoiceChip(
                        label: Text('Rejeitada (${cicloAtivo.rejeitadas})'),
                        selected: _status == 'rejeitada',
                        onSelected: (_) => setState(() => _status = 'rejeitada'),
                      ),
                      ChoiceChip(
                        label: Text('Pendente (${cicloAtivo.pendentes})'),
                        selected: _status == 'pendente',
                        onSelected: (_) => setState(() => _status = 'pendente'),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                if (cicloAtivo != null)
                  Text(
                    'Abastecimentos do ciclo (${_fmtData(cicloAtivo.periodoInicio)} – ${_fmtData(cicloAtivo.periodoFim)})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                const SizedBox(height: 8),
                if (filtros == null)
                  const SizedBox.shrink()
                else
                  Consumer(builder: (context, ref, _) {
                    final linhasAsync = ref.watch(linhasNotasFiscaisProvider(filtros));
                    return linhasAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Text('Erro ao carregar: $e'),
                      data: (linhas) {
                        if (linhas.isEmpty) {
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text('Nenhum abastecimento encontrado neste ciclo.',
                                  style: TextStyle(color: Colors.grey.shade600)),
                            ),
                          );
                        }
                        return Column(children: linhas.map(_cardLinha).toList());
                      },
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _cardCiclo(CicloNfe c, {required bool selecionado}) {
    final percentual = c.percentual ?? 0;
    final cor = _corDoPercentual(percentual);
    final statusCor = _statusCor[c.status] ?? Colors.grey;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: selecionado
          ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: const BorderSide(color: Color(0xFF0EA5E9), width: 2))
          : null,
      child: InkWell(
        onTap: () => setState(() {
          _cicloEscolhido = c;
          _status = null;
          _buscaCtrl.clear();
          _buscaAplicada = '';
        }),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(c.clienteNome ?? c.postoNome ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: statusCor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                    child: Text(_statusLabel[c.status] ?? c.status,
                        style: TextStyle(fontSize: 11, color: statusCor, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${_fmtData(c.periodoInicio)} – ${_fmtData(c.periodoFim)} · vencimento ${_fmtData(c.vencimento)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              if (c.total == 0)
                Text('Sem abastecimentos neste ciclo ainda.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${c.comNota} de ${c.total} com NF-e'
                        '${c.rejeitadas > 0 ? ' · ${c.rejeitadas} rejeitada${c.rejeitadas == 1 ? '' : 's'}' : ''}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    Text('${percentual.toStringAsFixed(1)}%',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cor)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (percentual.clamp(0, 100)) / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(cor),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardLinha(LinhaNotaFiscal l) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: l.notaId != null ? () => context.push('/notas-fiscais/${l.notaId}') : null,
        title: Text(
          [
            if (l.codigoAbastecimento != null) '#${l.codigoAbastecimento}',
            _fmtData(l.dataAbastecimento),
          ].join(' · '),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                if (l.postoNome != null) l.postoNome!,
                if (l.veiculoPlaca != null) l.veiculoPlaca!,
                if (l.itemNome != null) l.itemNome!,
                if (l.itemValorTotal != null) _moeda.format(l.itemValorTotal),
              ].join(' · '),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            _badgeStatus(l),
          ],
        ),
        isThreeLine: true,
        trailing: l.notaId != null ? const Icon(Icons.chevron_right, size: 18) : null,
      ),
    );
  }

  Widget _badgeStatus(LinhaNotaFiscal l) {
    if (l.notaId != null) {
      return _chip('Emitida${l.notaNumero != null ? ' · Nº ${l.notaNumero}' : ''}', const Color(0xFF16A34A));
    }
    if (l.pendenciaMotivo != null) {
      final detalhe = l.pendenciaMotivo == 'erro_leitura_xml' && l.pendenciaDetalheTexto != null
          ? l.pendenciaDetalheTexto!
          : mensagemMotivoPendencia(l.pendenciaMotivo);
      final extra = [
        if (l.pendenciaNomeArquivo != null) 'Arquivo: ${l.pendenciaNomeArquivo}',
        if (l.pendenciaCnpjEmitente != null) 'CNPJ emitente ${l.pendenciaCnpjEmitente}',
        if (l.pendenciaProdutoNomeXml != null) l.pendenciaProdutoNomeXml!,
      ].join(' · ');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chip('Rejeitada', const Color(0xFFDC2626)),
          const SizedBox(height: 3),
          Text(detalhe, style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
          if (extra.isNotEmpty) Text(extra, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      );
    }
    return _chip('Pendente', const Color(0xFFD97706));
  }

  Widget _chip(String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(texto, style: TextStyle(fontSize: 11, color: cor, fontWeight: FontWeight.w600)),
    );
  }
}
