import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../providers/constantes_anp.dart';
import '../../providers/inteligencia_rede_provider.dart';
import '../../widgets/inteligencia_shared.dart';
import '../../widgets/mapa_circulos.dart';

// Aba 8/10 — "🚦 Operacional". Porta Operacional.tsx (535 linhas) — 4
// sub-abas: Mapa de Preços, Postos Inconsistentes, Score por Região,
// Distribuição A/B/C/D.
class AbaOperacional extends StatefulWidget {
  final InteligenciaRedeCompleta dados;
  const AbaOperacional({super.key, required this.dados});

  @override
  State<AbaOperacional> createState() => _AbaOperacionalState();
}

const _prioridadeCombustivel = ['Diesel S-10 Comum', 'Diesel S-10 Aditivado', 'Diesel S-500 Comum', 'Diesel S-500 Aditivado', 'Gasolina Comum'];
const _coresGrade = {'A': Color(0xFF27AE60), 'B': Color(0xFF3498DB), 'C': Color(0xFFF39C12), 'D': Color(0xFFE74C3C)};

typedef _ScoreLinha = ({String cnpj, String? razaoSocial, String uf, String macro, double score, String grade});

(double score, String grade) _calcularScore(double diffPctSigned, int nServicos) {
  final diff = diffPctSigned / 100;
  final sPreco = (50 - diff * 500).clamp(0, 100);
  final sServ = ((nServicos / 11) * 100).clamp(0, 100);
  const sDist = 50.0;
  final score = ((0.5 * sPreco + 0.3 * sServ + 0.2 * sDist) * 10).round() / 10;
  final grade = score >= 75 ? 'A' : (score >= 55 ? 'B' : (score >= 35 ? 'C' : 'D'));
  return (score, grade);
}

class _AbaOperacionalState extends State<AbaOperacional> {
  int _subAba = 0;
  static const _titulos = ['🌡️ Mapa', '⚡ Inconsistentes', '⭐ Score', '🏅 A/B/C/D'];
  late final List<_ScoreLinha> _scores;

  @override
  void initState() {
    super.initState();
    _scores = _calcularScores(widget.dados);
  }

  static List<_ScoreLinha> _calcularScores(InteligenciaRedeCompleta d) {
    final porCnpj = <String, List<AlertaPreco>>{};
    for (final dv in d.desvioAnp) {
      if (dv.uf == null) continue;
      porCnpj.putIfAbsent(dv.cnpj, () => []).add(dv);
    }
    final servicosPorCnpj = {for (final s in d.servicosPosto) s.cnpj: s};
    final resultado = <_ScoreLinha>[];
    for (final entry in porCnpj.entries) {
      final linhas = entry.value;
      var preferida = linhas.first;
      for (final pref in _prioridadeCombustivel) {
        final achada = linhas.where((l) => l.combustivel == pref).toList();
        if (achada.isNotEmpty) {
          preferida = achada.first;
          break;
        }
      }
      final s = servicosPorCnpj[entry.key];
      final nServicos = s?.nServicos ?? 0;
      final (score, grade) = _calcularScore(preferida.diffPct, nServicos);
      resultado.add((
        cnpj: entry.key,
        razaoSocial: preferida.razaoSocial,
        uf: preferida.uf!,
        macro: regioesBrasil.entries.firstWhere((e) => e.value.contains(preferida.uf), orElse: () => const MapEntry('Outros', [])).key,
        score: score,
        grade: grade,
      ));
    }
    return resultado;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dados;
    if (d.precosMapaOperacional.isEmpty && d.desvioAnp.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Ainda não há preços/postos suficientes para o painel operacional.', style: TextStyle(color: Colors.grey))));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: SeletorChips<int>(opcoes: List.generate(_titulos.length, (i) => i), selecionado: _subAba, rotulo: (i) => _titulos[i], onSelecionar: (i) => setState(() => _subAba = i)),
        ),
        Expanded(
          child: IndexedStack(index: _subAba, sizing: StackFit.expand, children: [
            _MapaPrecos(precosMapa: d.precosMapaOperacional),
            _PostosInconsistentes(desvios: d.desvioAnp),
            _ScorePorRegiao(scores: _scores),
            _DistribuicaoGrade(scores: _scores),
          ]),
        ),
      ],
    );
  }
}

// ---- Sub-aba: Mapa de Preços ----
class _MapaPrecos extends StatefulWidget {
  final List<PontoPrecoMapaOperacional> precosMapa;
  const _MapaPrecos({required this.precosMapa});
  @override
  State<_MapaPrecos> createState() => _MapaPrecosState();
}

class _MapaPrecosState extends State<_MapaPrecos> {
  String? _sel;

  @override
  Widget build(BuildContext context) {
    final combustiveis = widget.precosMapa.map((p) => p.combustivel).toSet().toList()..sort();
    final atual = (_sel != null && combustiveis.contains(_sel)) ? _sel! : (combustiveis.isNotEmpty ? combustiveis[0] : '');
    final filtrado = widget.precosMapa.where((p) => p.combustivel == atual && p.lat != null && p.lon != null && p.preco > 0).toList();
    final precos = filtrado.map((p) => p.preco).toList();
    final min = precos.isEmpty ? 0.0 : precos.reduce((a, b) => a < b ? a : b);
    final max = precos.isEmpty ? 0.0 : precos.reduce((a, b) => a > b ? a : b);
    final ordenado = [...precos]..sort();
    final med = ordenado.isEmpty ? 0.0 : (ordenado.length % 2 == 0 ? (ordenado[ordenado.length ~/ 2 - 1] + ordenado[ordenado.length ~/ 2]) / 2 : ordenado[ordenado.length ~/ 2]);
    final faixa = (max - min) > 0.01 ? (max - min) : 0.01;

    final pontos = filtrado.map((p) {
      final norm = (p.preco - min) / faixa;
      final cor = norm < 0.33 ? const Color(0xFF27AE60) : (norm < 0.66 ? const Color(0xFFF39C12) : const Color(0xFFE74C3C));
      return PontoCirculo(lat: p.lat!, lon: p.lon!, cor: cor, tooltip: '${p.razaoSocial ?? "Posto GF"}\n${formatarMoeda(p.preco)}');
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _seletorCombustivel(combustiveis, atual, (v) => setState(() => _sel = v)),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.7,
          children: [
            CartaoIndicador(label: '⛽ Postos mapeados', valor: formatarInt(filtrado.length), mini: true),
            CartaoIndicador(label: '💰 Mín', valor: formatarMoeda(min), mini: true),
            CartaoIndicador(label: '💰 Máx', valor: formatarMoeda(max), mini: true),
            CartaoIndicador(label: '📊 Mediana', valor: formatarMoeda(med), mini: true),
          ],
        ),
        const SizedBox(height: 12),
        MapaCirculos(pontos: pontos, height: 400),
        const SizedBox(height: 6),
        Text('🟢 Preço baixo · 🟡 Preço médio · 🔴 Preço alto', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
      ]),
    );
  }
}

// ---- Sub-aba: Postos Inconsistentes ----
class _PostosInconsistentes extends StatefulWidget {
  final List<AlertaPreco> desvios;
  const _PostosInconsistentes({required this.desvios});
  @override
  State<_PostosInconsistentes> createState() => _PostosInconsistentesState();
}

class _PostosInconsistentesState extends State<_PostosInconsistentes> {
  double _tolerancia = 15;

  @override
  Widget build(BuildContext context) {
    final filtrado = widget.desvios.where((d) => d.diffPct.abs() > _tolerancia).toList()..sort((a, b) => b.diffPct.abs().compareTo(a.diffPct.abs()));
    final top20 = filtrado.take(20).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tolerância de desvio vs ANP: ${_tolerancia.toInt()}%', style: const TextStyle(fontSize: 12)),
        Slider(value: _tolerancia, min: 5, max: 40, divisions: 7, label: '${_tolerancia.toInt()}%', onChanged: (v) => setState(() => _tolerancia = v)),
        const SizedBox(height: 8),
        if (filtrado.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
            child: Text('✅ Nenhum posto com desvio superior a ${_tolerancia.toInt()}%.', style: const TextStyle(fontSize: 12)),
          )
        else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
            child: Text('⚠️ ${filtrado.length} registros com desvio superior a ${_tolerancia.toInt()}%', style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 12),
          Text('Top 20 postos com maior desvio vs ANP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          BarraHorizontal(
            dados: top20
                .map((d) => BarraHorizontalItem(
                      label: '${truncarTexto(d.razaoSocial, 22)} (${d.uf})',
                      valor: d.diffPct.abs(),
                      cor: d.diffPct > 0 ? const Color(0xFFE74C3C) : const Color(0xFF3498DB),
                      texto: '${d.diffPct > 0 ? "+" : ""}${d.diffPct.toStringAsFixed(1)}%',
                    ))
                .toList(),
            eixoX: 'Desvio % vs ANP',
          ),
          const SizedBox(height: 12),
          TabelaSimples(
            colunas: const ['Posto', 'UF', 'Combustível', 'Preço GF', 'Desvio'],
            flexColunas: const [3, 1, 3, 2, 2],
            maxHeight: 400,
            linhas: filtrado.map((d) => [truncarTexto(d.razaoSocial, 20), d.uf ?? '—', d.combustivel, formatarMoeda(d.precoGf), '${d.diffPct > 0 ? "+" : ""}${d.diffPct.toStringAsFixed(1)}%']).toList(),
          ),
        ],
      ]),
    );
  }
}

// ---- Sub-aba: Score por Região ----
class _ScorePorRegiao extends StatefulWidget {
  final List<_ScoreLinha> scores;
  const _ScorePorRegiao({required this.scores});
  @override
  State<_ScorePorRegiao> createState() => _ScorePorRegiaoState();
}

class _ScorePorRegiaoState extends State<_ScorePorRegiao> {
  bool _porUf = false;

  @override
  Widget build(BuildContext context) {
    if (widget.scores.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Sem dados suficientes (preço + ANP resolvido) para calcular o score.', style: TextStyle(color: Colors.grey))));
    }
    final agrupadoMapa = <String, List<double>>{};
    for (final s in widget.scores) {
      final chave = _porUf ? s.uf : s.macro;
      agrupadoMapa.putIfAbsent(chave, () => []).add(s.score);
    }
    final agrupado = agrupadoMapa.entries.map((e) => (chave: e.key, scoreMedio: media(e.value), n: e.value.length)).toList()..sort((a, b) => b.scoreMedio.compareTo(a.scoreMedio));
    final scoreGeral = media(widget.scores.map((s) => s.score).toList());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Granularidade: ', style: TextStyle(fontSize: 12)),
          ChoiceChip(label: const Text('Macrorregião', style: TextStyle(fontSize: 11)), selected: !_porUf, onSelected: (_) => setState(() => _porUf = false)),
          const SizedBox(width: 6),
          ChoiceChip(label: const Text('UF', style: TextStyle(fontSize: 11)), selected: _porUf, onSelected: (_) => setState(() => _porUf = true)),
        ]),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.2,
          children: [
            CartaoIndicador(label: '⭐ Score médio', valor: scoreGeral.toStringAsFixed(1), mini: true),
            CartaoIndicador(label: '🏆 Melhor', valor: agrupado.isNotEmpty ? agrupado.first.chave : '—', mini: true),
            CartaoIndicador(label: '⚠️ Pior', valor: agrupado.isNotEmpty ? agrupado.last.chave : '—', mini: true),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: BarChart(
            BarChartData(
              maxY: 105,
              barTouchData: barTouchPadrao(formatarY: (v) => 'Score ${v.toStringAsFixed(1)}'),
              barGroups: agrupado.asMap().entries.map((e) {
                final cor = e.value.scoreMedio >= 70 ? const Color(0xFF27AE60) : (e.value.scoreMedio >= 45 ? const Color(0xFFF39C12) : const Color(0xFFE74C3C));
                return BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: e.value.scoreMedio, color: cor, width: 18, borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))]);
              }).toList(),
              extraLinesData: ExtraLinesData(horizontalLines: [
                HorizontalLine(y: 70, color: const Color(0xFF27AE60), strokeWidth: 1, dashArray: [4, 4]),
                HorizontalLine(y: 45, color: const Color(0xFFF57C00), strokeWidth: 1, dashArray: [4, 4]),
              ]),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 9)))),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= agrupado.length) return const SizedBox.shrink();
                  return Text(agrupado[i].chave, style: const TextStyle(fontSize: 9));
                })),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(drawVerticalLine: false),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TabelaSimples(colunas: const ['Região', 'Score médio', 'Postos'], linhas: agrupado.map((a) => [a.chave, a.scoreMedio.toStringAsFixed(1), '${a.n}']).toList()),
      ]),
    );
  }
}

// ---- Sub-aba: Distribuição A/B/C/D ----
class _DistribuicaoGrade extends StatelessWidget {
  final List<_ScoreLinha> scores;
  const _DistribuicaoGrade({required this.scores});

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Sem dados suficientes para calcular a distribuição de graus.', style: TextStyle(color: Colors.grey))));
    }
    final contagem = {'A': 0, 'B': 0, 'C': 0, 'D': 0};
    for (final s in scores) contagem[s.grade] = (contagem[s.grade] ?? 0) + 1;
    final total = scores.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.7,
          children: ['A', 'B', 'C', 'D'].map((g) {
            final emoji = {'A': '🟢', 'B': '🔵', 'C': '🟡', 'D': '🔴'}[g];
            return CartaoIndicador(label: '$emoji Categoria $g', valor: formatarInt(contagem[g] ?? 0), sub: '${((contagem[g] ?? 0) / total * 100).toStringAsFixed(1)}%', mini: true);
          }).toList(),
        ),
        const SizedBox(height: 16),
        Text('Distribuição geral', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: PieChart(PieChartData(
            sectionsSpace: 1,
            centerSpaceRadius: 40,
            sections: ['A', 'B', 'C', 'D'].map((g) {
              final v = contagem[g] ?? 0;
              return PieChartSectionData(value: v <= 0 ? 0.001 : v.toDouble(), title: '$g ${(v / total * 100).toStringAsFixed(0)}%', color: _coresGrade[g], radius: 75, titleStyle: const TextStyle(fontSize: 11, color: Colors.white));
            }).toList(),
          )),
        ),
        const SizedBox(height: 16),
        Text('% por categoria — UF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        Builder(builder: (context) {
          final porUfMapa = <String, Map<String, int>>{};
          for (final s in scores) {
            porUfMapa.putIfAbsent(s.uf, () => {'A': 0, 'B': 0, 'C': 0, 'D': 0});
            porUfMapa[s.uf]![s.grade] = (porUfMapa[s.uf]![s.grade] ?? 0) + 1;
          }
          final porUf = porUfMapa.entries.map((e) {
            final totalUf = e.value.values.fold<int>(0, (a, b) => a + b);
            return (uf: e.key, contagem: e.value, totalUf: totalUf, pctA: totalUf > 0 ? e.value['A']! / totalUf * 100 : 0.0);
          }).toList()
            ..sort((a, b) => b.pctA.compareTo(a.pctA));

          return TabelaSimples(
            colunas: const ['UF', 'A', 'B', 'C', 'D', 'Total'],
            linhas: porUf.map((u) => [u.uf, '${u.contagem['A']}', '${u.contagem['B']}', '${u.contagem['C']}', '${u.contagem['D']}', '${u.totalUf}']).toList(),
            maxHeight: 360,
          );
        }),
      ]),
    );
  }
}

Widget _seletorCombustivel(List<String> opcoes, String atual, ValueChanged<String> onChanged) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      const Text('Combustível: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(width: 4),
      DropdownButton<String>(
        value: opcoes.contains(atual) ? atual : null,
        isDense: true,
        items: opcoes.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
        onChanged: (v) => v != null ? onChanged(v) : null,
      ),
    ]),
  );
}
