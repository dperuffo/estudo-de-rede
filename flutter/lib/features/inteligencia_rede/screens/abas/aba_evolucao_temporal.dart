import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../providers/inteligencia_rede_provider.dart';
import '../../widgets/inteligencia_shared.dart';

// Aba 9/10 — "📈 Evolução Temporal". Porta EvolucaoTemporal.tsx (497
// linhas) — tendência de preço por UF (com preço real pago sobreposto),
// volatilidade por UF (desvio padrão + coef. de variação) e ranking de
// estabilidade por posto. Todo o cálculo (14 mil+ registros de
// historicoDetalhado) roda no cliente, igual na web.
class AbaEvolucaoTemporal extends StatefulWidget {
  final InteligenciaRedeCompleta dados;
  const AbaEvolucaoTemporal({super.key, required this.dados});

  @override
  State<AbaEvolucaoTemporal> createState() => _AbaEvolucaoTemporalState();
}

const _coresUf = [
  Color(0xFF1040A0), Color(0xFF1565C0), Color(0xFF1976D2), Color(0xFF42A5F5), Color(0xFF90CAF9),
  Color(0xFF0B2660), Color(0xFF071840), Color(0xFF2979FF), Color(0xFF448AFF), Color(0xFF82B1FF),
];
const _corPrecoReal = Color(0xFFE65100);

String _periodoLabel(String data, bool semanal) {
  final partes = data.split('-');
  if (partes.length < 3) return data;
  final dia = partes[2];
  const nomes = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
  final mesIdx = int.tryParse(partes[1]) ?? 1;
  if (semanal) return '$dia/${partes[1]}';
  final ano = partes[0].length == 4 ? partes[0].substring(2) : partes[0];
  return '${nomes[(mesIdx - 1).clamp(0, 11)]}/$ano';
}

class _AbaEvolucaoTemporalState extends State<AbaEvolucaoTemporal> {
  String _combustivelSel = 'Todos';
  String _ufSel = 'Todos';
  bool _semanal = true;

  @override
  Widget build(BuildContext context) {
    final registros = widget.dados.historicoDetalhado;
    if (registros.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Histórico de preços vazio.', style: TextStyle(color: Colors.grey))));
    }
    final combustiveis = registros.map((r) => r.combustivel).toSet().toList()..sort();
    final ufs = registros.map((r) => r.uf).whereType<String>().toSet().toList()..sort();

    final filtrado = registros.where((r) {
      if (_combustivelSel != 'Todos' && r.combustivel != _combustivelSel) return false;
      if (_ufSel != 'Todos' && r.uf != _ufSel) return false;
      return r.uf != null;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 12, runSpacing: 8, children: [
            _dropdown('Combustível', ['Todos', ...combustiveis], _combustivelSel, (v) => setState(() => _combustivelSel = v)),
            _dropdown('UF', ['Todos', ...ufs], _ufSel, (v) => setState(() => _ufSel = v)),
            _dropdownBool('Granularidade', {'Semanal': true, 'Mensal': false}, _semanal, (v) => setState(() => _semanal = v)),
          ]),
          const SizedBox(height: 16),
          if (filtrado.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Nenhum dado para os filtros selecionados.', style: TextStyle(color: Colors.grey)))
          else
            Builder(builder: (context) => _conteudo(filtrado)),
        ],
      ),
    );
  }

  Widget _conteudo(List<RegistroPrecoHistorico> filtrado) {
    String chave(RegistroPrecoHistorico r) => _semanal ? r.semana : r.mes;

    // ---- Tendência por UF ----
    final mapa = <String, Map<String, ({double soma, int qtd})>>{};
    for (final r in filtrado) {
      final uf = r.uf!;
      final periodo = chave(r);
      final porPeriodo = mapa.putIfAbsent(uf, () => {});
      final atual = porPeriodo[periodo] ?? (soma: 0.0, qtd: 0);
      porPeriodo[periodo] = (soma: atual.soma + r.preco, qtd: atual.qtd + 1);
    }
    var tendenciaPorUf = mapa.entries
        .map((e) => (uf: e.key, pontos: e.value.entries.map((p) => (periodo: p.key, precoMedio: p.value.soma / p.value.qtd)).toList()..sort((a, b) => a.periodo.compareTo(b.periodo))))
        .where((s) => s.pontos.length >= 2)
        .toList()
      ..sort((a, b) => b.pontos.length.compareTo(a.pontos.length));
    final limitado = tendenciaPorUf.length > 10;
    tendenciaPorUf = tendenciaPorUf.take(10).toList()..sort((a, b) => a.uf.compareTo(b.uf));

    final precoRealMapa = <String, ({double soma, int qtd})>{};
    for (final p in widget.dados.precoRealPeriodo) {
      if (_ufSel != 'Todos' && p.uf != _ufSel) continue;
      final periodo = _semanal ? p.semana : p.mes;
      final atual = precoRealMapa[periodo] ?? (soma: 0.0, qtd: 0);
      precoRealMapa[periodo] = (soma: atual.soma + p.precoMedio * p.qtd, qtd: atual.qtd + p.qtd);
    }
    final precoRealSerie = precoRealMapa.entries.map((e) => (periodo: e.key, precoReal: e.value.qtd > 0 ? e.value.soma / e.value.qtd : 0.0)).toList()..sort((a, b) => a.periodo.compareTo(b.periodo));

    final todosPeriodos = <String>{};
    for (final s in tendenciaPorUf) {
      for (final p in s.pontos) todosPeriodos.add(p.periodo);
    }
    for (final p in precoRealSerie) todosPeriodos.add(p.periodo);
    final periodosOrdenados = todosPeriodos.toList()..sort();

    ({(String, double) alta, (String, double) queda})? insights;
    if (tendenciaPorUf.isNotEmpty) {
      final deltas = tendenciaPorUf.map((s) {
        final primeiro = s.pontos.first.precoMedio;
        final ultimo = s.pontos.last.precoMedio;
        final pct = primeiro != 0 ? ((ultimo - primeiro) / primeiro) * 100 : 0.0;
        return (uf: s.uf, pct: pct);
      }).toList()
        ..sort((a, b) => b.pct.compareTo(a.pct));
      insights = (alta: (deltas.first.uf, deltas.first.pct), queda: (deltas.last.uf, deltas.last.pct));
    }

    // ---- Volatilidade por UF ----
    final linhasVol = mapa.entries.map((e) {
      final mediasPeriodo = e.value.values.map((v) => v.soma / v.qtd).toList();
      return (uf: e.key, media: media(mediasPeriodo), std: desvioPadraoAmostral(mediasPeriodo), n: mediasPeriodo.length);
    }).where((l) => l.n >= 2).map((l) => (uf: l.uf, media: l.media, std: l.std, n: l.n, cv: l.media != 0 ? (l.std / l.media) * 100 : 0.0)).toList();
    final stds = linhasVol.map((l) => l.std).toList();
    final p75 = quantil(stds, 0.75);
    final p50 = quantil(stds, 0.5);
    final porStd = [...linhasVol]..sort((a, b) => b.std.compareTo(a.std));
    final porCv = [...linhasVol]..sort((a, b) => b.cv.compareTo(a.cv));

    // ---- Ranking de estabilidade por posto ----
    final postosMapa = <String, ({String razaoSocial, String municipio, String uf, List<double> precos})>{};
    for (final r in filtrado) {
      final at = postosMapa[r.cnpj] ?? (razaoSocial: r.razaoSocial ?? r.cnpj, municipio: r.municipio ?? '—', uf: r.uf ?? '—', precos: <double>[]);
      at.precos.add(r.preco);
      postosMapa[r.cnpj] = at;
    }
    final ranking = postosMapa.entries
        .map((e) {
          final m = media(e.value.precos);
          final std = desvioPadraoAmostral(e.value.precos);
          return (cnpj: e.key, razaoSocial: e.value.razaoSocial, municipio: e.value.municipio, uf: e.value.uf, n: e.value.precos.length, media: m, std: std, cvPct: m != 0 ? (std / m) * 100 : 0.0);
        })
        .where((l) => l.n >= 3)
        .toList()
      ..sort((a, b) => a.cvPct.compareTo(b.cvPct));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('🗺️ Tendência de preço por UF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        if (tendenciaPorUf.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Dados insuficientes para traçar tendências regionais (mín. 2 períodos por UF).', style: TextStyle(color: Colors.grey, fontSize: 12)))
        else ...[
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                lineTouchData: lineTouchPadrao(formatarY: (v) => formatarMoeda(v)),
                lineBarsData: [
                  ...tendenciaPorUf.asMap().entries.map((e) {
                    final idxPorPeriodo = {for (final p in e.value.pontos) p.periodo: p.precoMedio};
                    return LineChartBarData(
                      spots: periodosOrdenados.asMap().entries.where((pe) => idxPorPeriodo.containsKey(pe.value)).map((pe) => FlSpot(pe.key.toDouble(), idxPorPeriodo[pe.value]!)).toList(),
                      isCurved: false,
                      color: _coresUf[e.key % _coresUf.length],
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    );
                  }),
                  if (precoRealSerie.isNotEmpty)
                    LineChartBarData(
                      spots: periodosOrdenados
                          .asMap()
                          .entries
                          .where((pe) => precoRealSerie.any((p) => p.periodo == pe.value))
                          .map((pe) => FlSpot(pe.key.toDouble(), precoRealSerie.firstWhere((p) => p.periodo == pe.value).precoReal))
                          .toList(),
                      isCurved: false,
                      color: _corPrecoReal,
                      barWidth: 3,
                      dashArray: [6, 3],
                      dotData: const FlDotData(show: true),
                    ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, _) => Text(v.toStringAsFixed(2), style: const TextStyle(fontSize: 9)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= periodosOrdenados.length) return const SizedBox.shrink();
                    return Text(_periodoLabel(periodosOrdenados[i], _semanal), style: const TextStyle(fontSize: 8));
                  })),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(drawVerticalLine: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          Wrap(spacing: 10, runSpacing: 4, children: [
            ...tendenciaPorUf.asMap().entries.map((e) => _legendaLinha(_coresUf[e.key % _coresUf.length], e.value.uf)),
            if (precoRealSerie.isNotEmpty) _legendaLinha(_corPrecoReal, '💰 Preço real pago'),
          ]),
          if (limitado) Text('Mostrando os 10 estados com mais dados no período.', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
          if (insights != null) ...[
            const SizedBox(height: 10),
            BlocoInsight(texto: '${insights.alta.$2 > 0 ? "📈" : "📉"} ${insights.alta.$1} — variação de ${insights.alta.$2 >= 0 ? "+" : ""}${insights.alta.$2.toStringAsFixed(1)}% (maior alta)'),
            BlocoInsight(texto: '${insights.queda.$2 < 0 ? "📉" : "📈"} ${insights.queda.$1} — variação de ${insights.queda.$2 >= 0 ? "+" : ""}${insights.queda.$2.toStringAsFixed(1)}% (maior queda)'),
          ],
        ],
        const SizedBox(height: 20),
        Text('🌊 Volatilidade de preços por UF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text('Desvio padrão do preço médio ${_semanal ? "semanal" : "mensal"} por estado.', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        const SizedBox(height: 8),
        if (porStd.isEmpty)
          const Text('Dados insuficientes para calcular volatilidade.', style: TextStyle(color: Colors.grey, fontSize: 12))
        else ...[
          Text('Desvio padrão por UF', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          BarraHorizontal(dados: porStd.map((v) => BarraHorizontalItem(label: v.uf, valor: v.std, cor: v.std > p75 ? const Color(0xFFE53935) : (v.std > p50 ? const Color(0xFFF57C00) : const Color(0xFF43A047)), texto: formatarMoeda(v.std, casas: 4))).toList(), eixoX: 'Desvio padrão (R\$/L)'),
          const SizedBox(height: 12),
          Text('Coeficiente de variação por UF', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          BarraHorizontal(dados: porCv.map((v) => BarraHorizontalItem(label: v.uf, valor: v.cv, cor: v.cv > 5 ? const Color(0xFFE53935) : (v.cv > 2 ? const Color(0xFFF57C00) : const Color(0xFF43A047)), texto: '${v.cv.toStringAsFixed(1)}%')).toList(), eixoX: 'Coeficiente de variação (%)'),
          Text('Verde < 2% · Laranja 2–5% · Vermelho > 5%.', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        ],
        const SizedBox(height: 20),
        Text('🏆 Ranking de estabilidade por posto', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text('Postos com pelo menos 3 registros, ordenados pelo menor coeficiente de variação.', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        const SizedBox(height: 8),
        if (ranking.isEmpty)
          const Text('Nenhum posto com 3 ou mais registros ainda.', style: TextStyle(color: Colors.grey, fontSize: 12))
        else ...[
          Text('🥇 Top 10 mais estáveis', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ranking.take(10).length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final p = ranking[i];
                final medalha = ['🥇', '🥈', '🥉'].length > i ? ['🥇', '🥈', '🥉'][i] : '#${i + 1}';
                final (bg, borda) = p.cvPct < 1 ? (const Color(0xFFE8F5E9), const Color(0xFF43A047)) : (p.cvPct < 3 ? (const Color(0xFFFFF8E1), const Color(0xFFF57C00)) : (const Color(0xFFFCE4EC), const Color(0xFFE53935)));
                return Container(
                  width: 140,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: bg, border: Border.all(color: borda), borderRadius: BorderRadius.circular(6)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(medalha, style: const TextStyle(fontSize: 11)),
                    Text(truncarTexto(p.razaoSocial, 20), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                    Text('${p.municipio}/${p.uf}', style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
                    Text('CV ${p.cvPct.toStringAsFixed(2)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: borda)),
                    Text('${formatarMoeda(p.media)} médio', style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
                  ]),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text('📊 Distribuição de estabilidade (top 20)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          BarraHorizontal(
            dados: ranking.take(20).map((p) => BarraHorizontalItem(label: '${truncarTexto(p.razaoSocial, 22)} (${p.uf})', valor: p.cvPct, cor: p.cvPct < 1 ? const Color(0xFF43A047) : (p.cvPct < 3 ? const Color(0xFFF57C00) : const Color(0xFFE53935)), texto: '${p.cvPct.toStringAsFixed(2)}%')).toList(),
            eixoX: 'Coeficiente de variação (%)',
          ),
          const SizedBox(height: 16),
          Text('📋 Tabela completa de estabilidade', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TabelaSimples(
            colunas: const ['Posto', 'UF', 'Registros', 'Preço médio', 'CV (%)'],
            flexColunas: const [4, 1, 2, 2, 2],
            maxHeight: 420,
            linhas: ranking.map((p) => [truncarTexto(p.razaoSocial, 22), p.uf, '${p.n}', formatarMoeda(p.media, casas: 4), '${p.cvPct.toStringAsFixed(2)}%']).toList(),
          ),
        ],
      ],
    );
  }

  Widget _legendaLinha(Color cor, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 3, color: cor),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ]);

  Widget _dropdown(String label, List<String> opcoes, String valor, ValueChanged<String> onChanged) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
      DropdownButton<String>(value: opcoes.contains(valor) ? valor : opcoes.first, isDense: true, items: opcoes.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(), onChanged: (v) => v != null ? onChanged(v) : null),
    ]);
  }

  Widget _dropdownBool(String label, Map<String, bool> opcoes, bool valor, ValueChanged<bool> onChanged) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
      DropdownButton<bool>(value: valor, isDense: true, items: opcoes.entries.map((e) => DropdownMenuItem(value: e.value, child: Text(e.key, style: const TextStyle(fontSize: 12)))).toList(), onChanged: (v) => v != null ? onChanged(v) : null),
    ]);
  }
}
