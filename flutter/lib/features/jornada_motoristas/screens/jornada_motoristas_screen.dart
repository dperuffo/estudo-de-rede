import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/jornada_motoristas_provider.dart';

final _dataBr = DateFormat('dd/MM/yyyy');
final _dataIso = DateFormat('yyyy-MM-dd');
final _diaCurto = DateFormat('dd/MM');
final _dataHoraBr = DateFormat('dd/MM/yyyy HH:mm');

const _corDirigindo = Color(0xFF1B7A43);
const _corPausa = Color(0xFFB8860B);
const _corDescanso = Color(0xFF1E6FBF);

const Map<String, String> _labelEstado = {
  'dirigindo': 'Dirigindo',
  'pausa': 'Em pausa',
  'descanso': 'Descansando',
  'nunca_iniciado': 'Nunca iniciou',
};

String _formatarDuracao(int? minutos) {
  if (minutos == null) return '—';
  final h = minutos ~/ 60;
  final m = minutos % 60;
  if (h == 0) return '${m}min';
  return '${h}h${m.toString().padLeft(2, '0')}';
}

// Fase Painel-Jornada-Motorista (17/08/2026, pedido do Daniel: painel do
// gestor com indicadores e gráficos de jornada, "Web e PWA juntos desde
// já") — porta de jornada-motoristas/page.tsx (web). Ver escopo completo em
// jornada_motoristas_provider.dart.
class JornadaMotoristasScreen extends ConsumerStatefulWidget {
  const JornadaMotoristasScreen({super.key});

  @override
  ConsumerState<JornadaMotoristasScreen> createState() => _JornadaMotoristasScreenState();
}

class _JornadaMotoristasScreenState extends ConsumerState<JornadaMotoristasScreen> {
  DateTime _dataInicio = DateTime.now().subtract(const Duration(days: 30));
  DateTime _dataFim = DateTime.now();
  String? _motoristaSelecionadoId;

  Future<void> _escolherData({required bool inicio}) async {
    final atual = inicio ? _dataInicio : _dataFim;
    final escolhida = await showDatePicker(context: context, initialDate: atual, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (escolhida == null || !mounted) return;
    setState(() {
      if (inicio) {
        _dataInicio = escolhida;
      } else {
        _dataFim = escolhida;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtro = (dataInicio: _dataIso.format(_dataInicio), dataFim: _dataIso.format(_dataFim));
    final statusAsync = ref.watch(statusAtualJornadaProvider);
    final diariosAsync = ref.watch(indicadoresJornadaProvider(filtro));
    final registroAsync = ref.watch(registroDetalhadoJornadaProvider(filtro));

    return Scaffold(
      appBar: AppBar(title: const Text('Jornada dos Motoristas')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(statusAtualJornadaProvider);
          ref.invalidate(indicadoresJornadaProvider);
          ref.invalidate(registroDetalhadoJornadaProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Indicadores a partir dos horários de trabalho, pausa e descanso que os próprios motoristas registram '
              'no app — inclui alertas de aderência à Lei do Motorista (13.103/2015): condução contínua acima de '
              '5h30 sem pausa, e descanso entre jornadas abaixo de 11h.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            statusAsync.when(
              data: (status) => _secaoAgora(status),
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Erro ao carregar status: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ),
            const SizedBox(height: 24),
            _tituloSecao('Período selecionado'),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _escolherData(inicio: true),
                    child: Text('De: ${_dataBr.format(_dataInicio)}', style: const TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _escolherData(inicio: false),
                    child: Text('Até: ${_dataBr.format(_dataFim)}', style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            diariosAsync.when(
              data: (diarios) => _corpoPeriodo(diarios, statusAsync.asData?.value ?? const []),
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Erro ao carregar indicadores: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ),
            const SizedBox(height: 24),
            _tituloSecao('Registro detalhado (tracking)'),
            registroAsync.when(
              data: (registros) => _secaoRegistroDetalhado(registros, statusAsync.asData?.value ?? const []),
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Erro ao carregar registro detalhado: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fase Painel-Jornada-Motorista (17/08/2026, pedido do Daniel: "senti
  // falta de um relatório que traga os tempos registrados... como se fosse
  // um tracking por motorista") — porta de jornada-motoristas/page.tsx
  // (web): seletor de motorista + lista de segmentos (dirigindo/pausa/
  // descanso) com início, fim e duração.
  Widget _secaoRegistroDetalhado(List<RegistroDetalhadoMotorista> registros, List<StatusAtualMotorista> status) {
    final motoristas = <String, String>{};
    for (final s in status) {
      motoristas[s.motoristaId] = s.nomeCompleto;
    }
    final motoristasOrdenados = motoristas.entries.toList()..sort((a, b) => a.value.compareTo(b.value));

    if (motoristasOrdenados.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('Nenhum motorista com jornada registrada.', style: TextStyle(color: Colors.grey))),
      );
    }

    final selecionadoValido = _motoristaSelecionadoId != null && motoristas.containsKey(_motoristaSelecionadoId);
    final segmentos = selecionadoValido ? registros.where((r) => r.motoristaId == _motoristaSelecionadoId).toList() : const <RegistroDetalhadoMotorista>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: selecionadoValido ? _motoristaSelecionadoId : null,
          decoration: const InputDecoration(labelText: 'Motorista', isDense: true, border: OutlineInputBorder()),
          items: motoristasOrdenados
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13))))
              .toList(),
          onChanged: (v) => setState(() => _motoristaSelecionadoId = v),
        ),
        const SizedBox(height: 12),
        if (!selecionadoValido)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('Selecione um motorista para ver o registro detalhado.', style: TextStyle(color: Colors.grey, fontSize: 12))),
          )
        else if (segmentos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('Nenhum registro encontrado para esse motorista no período.', style: TextStyle(color: Colors.grey, fontSize: 12))),
          )
        else
          ...segmentos.map((r) {
            final cor = r.tipoSegmento == 'dirigindo' ? _corDirigindo : r.tipoSegmento == 'pausa' ? _corPausa : _corDescanso;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
                ),
                title: Text(_labelEstado[r.tipoSegmento] ?? r.tipoSegmento, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cor)),
                subtitle: Text(
                  '${_dataHoraBr.format(r.inicio)} → ${r.emAndamento ? "Em andamento" : _dataHoraBr.format(r.fim)}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Text(_formatarDuracao(r.duracaoMinutos), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            );
          }),
      ],
    );
  }

  Widget _tituloSecao(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(texto.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
      );

  Widget _secaoAgora(List<StatusAtualMotorista> status) {
    final dirigindo = status.where((s) => s.estado == 'dirigindo').length;
    final emPausa = status.where((s) => s.estado == 'pausa').length;
    final descansando = status.where((s) => s.estado == 'descanso').length;
    final excedendo = status.where((s) => s.excedeuLimite).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSecao('Agora'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.9,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            _card('Dirigindo agora', '$dirigindo', cor: _corDirigindo),
            _card('Em pausa agora', '$emPausa', cor: _corPausa),
            _card('Descansando agora', '$descansando', cor: _corDescanso),
            _card('Acima de 5h30 dirigindo', '${excedendo.length}', cor: excedendo.isNotEmpty ? Colors.red.shade700 : _corDirigindo),
          ],
        ),
        if (excedendo.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
            child: Text(
              '⚠️ ${excedendo.map((s) => s.nomeCompleto).join(", ")} já ${excedendo.length == 1 ? "está" : "estão"} dirigindo há mais de '
              '5h30 sem pausa.',
              style: TextStyle(fontSize: 12, color: Colors.red.shade900),
            ),
          ),
        ],
      ],
    );
  }

  Widget _corpoPeriodo(List<IndicadorDiarioMotorista> diarios, List<StatusAtualMotorista> status) {
    final horasDirigidas = diarios.fold<double>(0, (s, d) => s + d.horasDirigidas);
    final pausas = diarios.fold<int>(0, (s, d) => s + d.numPausas);
    final alertasConducao = diarios.fold<int>(0, (s, d) => s + d.alertasConducaoContinua);
    final alertasDescanso = diarios.fold<int>(0, (s, d) => s + d.alertasDescansoInsuficiente);

    // Soma por dia (todos os motoristas), ordenado cronologicamente.
    final Map<String, ({double dirigidas, double pausa, double descanso})> porDia = {};
    for (final d in diarios) {
      final chave = _dataIso.format(d.dia);
      final atual = porDia[chave] ?? (dirigidas: 0.0, pausa: 0.0, descanso: 0.0);
      porDia[chave] = (
        dirigidas: atual.dirigidas + d.horasDirigidas,
        pausa: atual.pausa + d.horasPausa,
        descanso: atual.descanso + d.horasDescanso,
      );
    }
    final diasOrdenados = porDia.keys.toList()..sort();

    // Ranking por motorista — mais alertas primeiro.
    final Map<String, ({String nome, double horas, int pausas, int alertas})> porMotorista = {};
    for (final d in diarios) {
      final atual = porMotorista[d.motoristaId] ?? (nome: d.nomeCompleto, horas: 0.0, pausas: 0, alertas: 0);
      porMotorista[d.motoristaId] = (
        nome: atual.nome,
        horas: atual.horas + d.horasDirigidas,
        pausas: atual.pausas + d.numPausas,
        alertas: atual.alertas + d.alertasConducaoContinua + d.alertasDescansoInsuficiente,
      );
    }
    final ranking = porMotorista.entries.toList()
      ..sort((a, b) => b.value.alertas != a.value.alertas ? b.value.alertas.compareTo(a.value.alertas) : b.value.horas.compareTo(a.value.horas));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.9,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            _card('Horas dirigidas', '${horasDirigidas.toStringAsFixed(0)}h', cor: _corDirigindo),
            _card('Pausas realizadas', '$pausas', cor: _corPausa),
            _card('Alertas condução contínua', '$alertasConducao', cor: alertasConducao > 0 ? Colors.red.shade700 : _corDirigindo),
            _card('Alertas descanso insuficiente', '$alertasDescanso', cor: alertasDescanso > 0 ? Colors.red.shade700 : _corDirigindo),
          ],
        ),
        const SizedBox(height: 20),
        if (diasOrdenados.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('Nenhuma jornada registrada no período.', style: TextStyle(color: Colors.grey))),
          )
        else ...[
          Text('Horas por dia', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _graficoHoras(diasOrdenados, porDia),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legenda('Dirigindo', _corDirigindo),
              const SizedBox(width: 12),
              _legenda('Pausa', _corPausa),
              const SizedBox(width: 12),
              _legenda('Descanso', _corDescanso),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text('Por motorista', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (ranking.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('Nenhum motorista com jornada no período.', style: TextStyle(color: Colors.grey))),
          )
        else
          ...ranking.map((e) {
            final motoristaId = e.key;
            final v = e.value;
            StatusAtualMotorista? statusMotorista;
            for (final s in status) {
              if (s.motoristaId == motoristaId) {
                statusMotorista = s;
                break;
              }
            }
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(v.nome, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${v.horas.toStringAsFixed(1)}h dirigidas · ${v.pausas} pausa${v.pausas == 1 ? '' : 's'}'
                  '${statusMotorista != null ? ' · ${_labelEstado[statusMotorista.estado] ?? statusMotorista.estado} há ${_formatarDuracao(statusMotorista.duracaoMinutos)}' : ''}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: v.alertas > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(12)),
                        child: Text('${v.alertas}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                      )
                    : null,
              ),
            );
          }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _legenda(String texto, Color cor) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(texto, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );

  // Barras agrupadas (3 por dia: dirigindo/pausa/descanso) — mesmo padrão de
  // BarChart já usado em aba_visao_geral.dart (_graficoConsumo), sem
  // rodStackItems (empilhado) pra manter risco baixo sem analisador Dart
  // disponível nesta sessão pra validar sintaxe mais complexa.
  Widget _graficoHoras(List<String> dias, Map<String, ({double dirigidas, double pausa, double descanso})> porDia) {
    final maxValor = dias
        .map((d) => porDia[d]!)
        .fold<double>(0, (a, v) => [a, v.dirigidas, v.pausa, v.descanso].reduce((x, y) => x > y ? x : y));
    final maxY = maxValor <= 0 ? 1.0 : maxValor * 1.3;

    return SizedBox(
      height: 220,
      child: BarChart(BarChartData(
        maxY: maxY,
        barGroups: dias.asMap().entries.map((e) {
          final v = porDia[e.value]!;
          return BarChartGroupData(x: e.key, barRods: [
            BarChartRodData(toY: v.dirigidas, color: _corDirigindo, width: 6, borderRadius: const BorderRadius.vertical(top: Radius.circular(2))),
            BarChartRodData(toY: v.pausa, color: _corPausa, width: 6, borderRadius: const BorderRadius.vertical(top: Radius.circular(2))),
            BarChartRodData(toY: v.descanso, color: _corDescanso, width: 6, borderRadius: const BorderRadius.vertical(top: Radius.circular(2))),
          ]);
        }).toList(),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            getTitlesWidget: (v, _) => Text('${v.toStringAsFixed(0)}h', style: const TextStyle(fontSize: 9)),
          )),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            getTitlesWidget: (v, _) {
              final idx = v.toInt();
              if (idx < 0 || idx >= dias.length) return const SizedBox();
              return Text(_diaCurto.format(DateTime.parse(dias[idx])), style: const TextStyle(fontSize: 9));
            },
          )),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.withOpacity(0.15), strokeWidth: 1),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF263238),
            getTooltipItem: (group, groupIdx, rod, rodIdx) {
              final label = rodIdx == 0 ? 'Dirigindo' : rodIdx == 1 ? 'Pausa' : 'Descanso';
              return BarTooltipItem('$label: ${rod.toY.toStringAsFixed(1)}h', const TextStyle(color: Colors.white, fontSize: 11));
            },
          ),
        ),
      )),
    );
  }

  Widget _card(String label, String valor, {required Color cor}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: cor.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: cor.withOpacity(0.25))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: cor, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(valor, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: cor)),
        ],
      ),
    );
  }
}
