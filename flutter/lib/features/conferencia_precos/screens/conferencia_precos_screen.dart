import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../posto/services/abastecimentos_posto_service.dart'
    show coresProvedor, nomeProvedor;
import '../services/conferencia_precos_service.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _numero = NumberFormat.decimalPattern('pt_BR');
final _dataHoraBr = DateFormat('dd/MM/yyyy HH:mm');
final _dataBr = DateFormat('dd/MM/yyyy');

String _fmtDataHora(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    return _dataHoraBr.format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

String _fmtData(String iso) {
  try {
    return _dataBr.format(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
}

// Fase FLT-Conferência-Precos (02/09/2026) — porta da visão cliente de
// conferencia-precos/page.tsx: compara o preço praticado em cada
// abastecimento com o acordo/negociação vigente com o posto, e mostra o
// extrato diário. Alerta "hoje" sempre calculado pro dia atual, independente
// do filtro escolhido — mesma regra da web ("não deixar acumular pra só ver
// no fechamento de ciclo").
class ConferenciaPrecosScreen extends ConsumerStatefulWidget {
  const ConferenciaPrecosScreen({super.key});

  @override
  ConsumerState<ConferenciaPrecosScreen> createState() =>
      _ConferenciaPrecosScreenState();
}

class _ConferenciaPrecosScreenState
    extends ConsumerState<ConferenciaPrecosScreen> {
  final _service = ConferenciaPrecosService();
  Future<ResultadoConferenciaPrecos>? _futuro;
  bool _abaExtrato = false;
  late DateTime _de;
  late DateTime _ate;

  @override
  void initState() {
    super.initState();
    _ate = DateTime.now();
    _de = _ate.subtract(const Duration(days: 6));
    _carregar();
  }

  void _carregar() {
    final empresaId = ref.read(sessaoProvider).valueOrNull?.empresaId;
    if (empresaId == null) {
      setState(() =>
          _futuro = Future.value(ResultadoConferenciaPrecos.vazio));
      return;
    }
    final fmt = DateFormat('yyyy-MM-dd');
    setState(() {
      _futuro = _service.buscar(
        empresaId: empresaId,
        de: fmt.format(_de),
        ate: fmt.format(_ate),
      );
    });
  }

  Future<void> _selecionarData({required bool inicio}) async {
    final atual = inicio ? _de : _ate;
    final escolhida = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (escolhida == null) return;
    setState(() {
      if (inicio) {
        _de = escolhida;
      } else {
        _ate = escolhida;
      }
    });
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessaoProvider, (prev, next) {
      final idAnterior = prev?.valueOrNull?.empresaId;
      final idAtual = next.valueOrNull?.empresaId;
      if (idAtual != null && idAtual != idAnterior) _carregar();
    });
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Conferência de Preços')),
      body: RefreshIndicator(
        onRefresh: () async => _carregar(),
        child: FutureBuilder<ResultadoConferenciaPrecos>(
          future: _futuro,
          builder: (context, snap) {
            if (!snap.hasData &&
                snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text('Não deu pra carregar: ${snap.error}',
                      textAlign: TextAlign.center)
                ],
              );
            }
            final dados = snap.data ?? ResultadoConferenciaPrecos.vazio;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  'Compare o preço praticado em cada abastecimento com o acordo/negociação vigente com o posto, '
                  'e acompanhe o extrato diário por meio de pagamento.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                if (dados.divergenciasHoje.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      border: Border.all(color: const Color(0xFFFECACA)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '🚨 ${dados.divergenciasHoje.length} abastecimento${dados.divergenciasHoje.length == 1 ? '' : 's'} hoje '
                      'fora do preço acordado com o posto — impacto de ${_moeda.format(dados.valorDivergenciaHoje)} até agora. '
                      'Confira abaixo antes do fechamento do dia.',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: [
                    _indicador('Abastecimentos no período',
                        _numero.format(dados.totalAbastecimentosPeriodo)),
                    _indicador('Volume no período',
                        '${_numero.format(dados.totalLitrosPeriodo.round())} L'),
                    _indicador(
                        'Custo no período', _moeda.format(dados.totalValorPeriodo)),
                    _indicador(
                      'Divergências no período',
                      '${dados.totalDivergenciasPeriodo}',
                      destaque: dados.totalDivergenciasPeriodo > 0,
                    ),
                    _indicador(
                      'Impacto das divergências',
                      _moeda.format(dados.totalValorDivergenciaPeriodo),
                      destaque: dados.totalValorDivergenciaPeriodo != 0,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    _chip('Divergências de Preço', !_abaExtrato,
                        () => setState(() => _abaExtrato = false)),
                    _chip('Extrato Diário', _abaExtrato,
                        () => setState(() => _abaExtrato = true)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _selecionarData(inicio: true),
                        child: Text('De: ${_dataBr.format(_de)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _selecionarData(inicio: false),
                        child: Text('Até: ${_dataBr.format(_ate)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_abaExtrato)
                  _listaExtrato(dados.extrato)
                else
                  _listaDivergencias(dados.divergencias),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _listaDivergencias(List<DivergenciaPreco> divergencias) {
    if (divergencias.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
                'Nenhuma divergência de preço encontrada neste período — tudo dentro do acordado.',
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center),
          ),
        ),
      );
    }
    return Column(
        children: divergencias.map((d) => _cardDivergencia(d)).toList());
  }

  Widget _cardDivergencia(DivergenciaPreco d) {
    final acimaDoAcordo = (d.diferencaRs ?? 0) > 0;
    final cor = coresProvedor[d.provedor];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: d.temAjustePendente
            ? null
            : () => context.push('/abastecimentos/${d.chave}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(_fmtDataHora(d.dataAbastecimento),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cor != null ? Color(cor) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(nomeProvedor(d.provedor),
                        style: const TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${d.postoNome} · ${d.placa ?? '—'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 6),
              Text(
                  '${d.combustivel ?? '—'} · ${d.litros != null ? _numero.format(d.litros) : '—'} L'),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                      'Praticado: ${d.precoPraticado != null ? _moeda.format(d.precoPraticado) : '—'}',
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 10),
                  Text(
                      'Acordado: ${d.precoAcordado != null ? _moeda.format(d.precoAcordado) : '—'}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${acimaDoAcordo ? '+' : ''}${_moeda.format(d.diferencaRs ?? 0)}'
                '${d.diferencaPct != null ? ' (${d.diferencaPct! > 0 ? '+' : ''}${d.diferencaPct}%)' : ''}',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: acimaDoAcordo
                        ? const Color(0xFFDC2626)
                        : const Color(0xFFD97706)),
              ),
              const SizedBox(height: 6),
              if (d.temAjustePendente)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Text('Ajuste em andamento',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E))),
                )
              else
                const Text('Ver e solicitar ajuste →',
                    style: TextStyle(fontSize: 12, color: Color(0xFF4F46E5))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listaExtrato(List<ExtratoDia> extrato) {
    if (extrato.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text('Nenhum abastecimento fornecido neste período.',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
        ),
      );
    }
    return Column(
      children: extrato.map((e) {
        final cor = coresProvedor[e.provedor];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(_fmtData(e.dia),
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            cor != null ? Color(cor) : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(nomeProvedor(e.provedor),
                          style: const TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                    '${e.qtdAbastecimentos} abastecimento${e.qtdAbastecimentos == 1 ? '' : 's'} · '
                    '${_numero.format(e.litros.round())} L · ${_moeda.format(e.valorTotal)}'),
                if (e.qtdDivergencias > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                      '${e.qtdDivergencias} divergência${e.qtdDivergencias == 1 ? '' : 's'} · ${_moeda.format(e.valorDivergencia)}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFFDC2626))),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _indicador(String label, String valor, {bool destaque = false}) =>
      Card(
        color: destaque ? const Color(0xFFFEF2F2) : null,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(valor,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: destaque ? const Color(0xFFB91C1C) : null),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );

  Widget _chip(String label, bool selecionado, VoidCallback onTap) =>
      ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selecionado,
        onSelected: (_) => onTap(),
      );
}
