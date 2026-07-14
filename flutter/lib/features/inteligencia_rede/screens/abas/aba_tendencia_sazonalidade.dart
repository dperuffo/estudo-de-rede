import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../providers/inteligencia_rede_provider.dart';
import '../../widgets/inteligencia_shared.dart';

// Aba 10/10 — "📅 Tendência & Sazonalidade". Porta
// TendenciaSazonalidade.tsx (376 linhas) — regressão linear de preço por
// UF, heatmap de sazonalidade (preço médio por mês do ano) e volatilidade
// mensal por combustível.
class AbaTendenciaSazonalidade extends StatefulWidget {
  final InteligenciaRedeCompleta dados;
  const AbaTendenciaSazonalidade({super.key, required this.dados});

  @override
  State<AbaTendenciaSazonalidade> createState() => _AbaTendenciaSazonalidadeState();
}

const _coresUfTend = [Color(0xFF0D47A1), Color(0xFFB71C1C), Color(0xFF2E7D32), Color(0xFFE65100), Color(0xFF6A1B9A), Color(0xFF00838F), Color(0xFFF57F17), Color(0xFF4E342E)];
const _coresCombustivelTend = [Color(0xFF1565C0), Color(0xFFC62828), Color(0xFF2E7D32), Color(0xFFEF6C00), Color(0xFF6A1B9A), Color(0xFF00838F)];
const _nomesMesCompleto = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
const _nomesMesAbrev = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];

String _mesLabel(String mes) {
  final partes = mes.split('-');
  if (partes.length < 2) return mes;
  const nomes = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
  final idx = (int.tryParse(partes[1]) ?? 1) - 1;
  final ano = partes[0].length == 4 ? partes[0].substring(2) : partes[0];
  return '${nomes[idx.clamp(0, 11)]}/$ano';
}

int _mesNumero(String mes) {
  final partes = mes.split('-');
  return partes.length >= 2 ? ((int.tryParse(partes[1]) ?? 1) - 1) : 0;
}

DateTime _dataDoMes(String mes) {
  final partes = mes.split('-');
  final ano = int.tryParse(partes[0]) ?? 2024;
  final m = partes.length >= 2 ? (int.tryParse(partes[1]) ?? 1) : 1;
  return DateTime(ano, m, 1);
}

// Igual a _dataDoMes, mas preserva o dia — precisa pra data de INÍCIO da
// semana (semana = date_trunc('week', data_ref) no banco, um dia
// diferente por semana, não sempre dia 1 como em "mes").
DateTime _dataCompleta(String iso) {
  final partes = iso.split('-');
  final ano = int.tryParse(partes[0]) ?? 2024;
  final m = partes.length >= 2 ? (int.tryParse(partes[1]) ?? 1) : 1;
  final d = partes.length >= 3 ? (int.tryParse(partes[2]) ?? 1) : 1;
  return DateTime(ano, m, d);
}

// Rótulo de eixo pra semana (dia/mês de início da semana) — pedido do
// Daniel: trocar a escala de mês pra semana nos gráficos de tendência e de
// volatilidade, que tinham poucos pontos (um por mês) e ficavam pouco
// informativos com poucos meses de histórico.
String _semanaLabel(String semana) {
  final partes = semana.split('-');
  if (partes.length < 3) return semana;
  return '${partes[2]}/${partes[1]}';
}

({double slope, double intercept})? _regressaoLinear(List<({double x, double y})> pontos) {
  final n = pontos.length;
  if (n < 2) return null;
  final somaX = pontos.fold<double>(0, (s, p) => s + p.x);
  final somaY = pontos.fold<double>(0, (s, p) => s + p.y);
  final somaXY = pontos.fold<double>(0, (s, p) => s + p.x * p.y);
  final somaX2 = pontos.fold<double>(0, (s, p) => s + p.x * p.x);
  final denom = n * somaX2 - somaX * somaX;
  if (denom == 0) return null;
  final slope = (n * somaXY - somaX * somaY) / denom;
  final intercept = (somaY - slope * somaX) / n;
  return (slope: slope, intercept: intercept);
}

Color _corCelula(double? v, double min, double max) {
  if (v == null) return const Color(0xFFF1F5F9);
  if (max == min) return const Color(0xFF2E7D32);
  final t = ((v - min) / (max - min)).clamp(0.0, 1.0);
  final stops = <(double, List<int>)>[
    (0, [26, 74, 42]),
    (0.3, [46, 125, 50]),
    (0.6, [249, 168, 37]),
    (0.85, [230, 81, 0]),
    (1, [183, 28, 28]),
  ];
  for (var i = 0; i < stops.length - 1; i++) {
    if (t >= stops[i].$1 && t <= stops[i + 1].$1) {
      final localT = (t - stops[i].$1) / ((stops[i + 1].$1 - stops[i].$1) == 0 ? 1 : (stops[i + 1].$1 - stops[i].$1));
      final c = List.generate(3, (idx) => (stops[i].$2[idx] + (stops[i + 1].$2[idx] - stops[i].$2[idx]) * localT).round());
      return Color.fromARGB(255, c[0], c[1], c[2]);
    }
  }
  return const Color(0xFFB71C1C);
}

class _SerieUf {
  final String uf;
  final Color cor;
  final List<({String semana, String uf, double precoMedio, int qtd})> pontos;
  final double tendenciaMes;
  final double media;
  final double desvio;
  const _SerieUf({required this.uf, required this.cor, required this.pontos, required this.tendenciaMes, required this.media, required this.desvio});
}

class _AbaTendenciaSazonalidadeState extends State<AbaTendenciaSazonalidade> {
  String _selecionado = 'Todos';

  @override
  Widget build(BuildContext context) {
    final serie = widget.dados.serieTendencia;
    if (serie.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Histórico de preços insuficiente para calcular tendências.', style: TextStyle(color: Colors.grey))));
    }
    final combustiveis = widget.dados.historicoDetalhado.map((r) => r.combustivel).toSet().toList()..sort();

    final porMesUfMapa = <String, ({double soma, int qtd})>{};
    for (final s in serie) {
      if (_selecionado != 'Todos' && s.combustivel != _selecionado) continue;
      final chave = '${s.mes}__${s.uf}';
      final at = porMesUfMapa[chave] ?? (soma: 0.0, qtd: 0);
      porMesUfMapa[chave] = (soma: at.soma + s.precoMedio * s.qtd, qtd: at.qtd + s.qtd);
    }
    final porMesUf = porMesUfMapa.entries.map((e) {
      final partes = e.key.split('__');
      return (mes: partes[0], uf: partes[1], precoMedio: e.value.qtd > 0 ? e.value.soma / e.value.qtd : 0.0, qtd: e.value.qtd);
    }).toList();

    final totalPorUf = <String, int>{};
    for (final p in porMesUf) totalPorUf[p.uf] = (totalPorUf[p.uf] ?? 0) + p.qtd;
    // "Top 8 UFs" continua escolhido pelo volume mensal (só decide QUAIS
    // estados aparecem, tanto no gráfico de tendência quanto no heatmap de
    // sazonalidade) — o que muda é a granularidade dos PONTOS do gráfico de
    // tendência, que agora vêm por semana (ver bloco abaixo).
    final topUfs = (totalPorUf.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(8).map((e) => e.key).toList();

    // Pedido do Daniel: escala de semana (não de mês) no gráfico de
    // tendência — calculado direto do histórico bruto por posto
    // (`historicoDetalhado`), que já traz a coluna `semana` pronta do banco
    // (date_trunc('week', data_ref)), em vez da série já agregada por mês
    // que a RPC `historico_precos_serie_uf_combustivel` devolve. Dá mais
    // pontos na linha (uma semana tem histórico de sobra pra virar vários
    // pontos, mesmo com poucos meses de dados acumulados).
    final porSemanaUfMapa = <String, ({double soma, int qtd})>{};
    for (final r in widget.dados.historicoDetalhado) {
      if (r.uf == null || !topUfs.contains(r.uf)) continue;
      if (_selecionado != 'Todos' && r.combustivel != _selecionado) continue;
      final chave = '${r.semana}__${r.uf}';
      final at = porSemanaUfMapa[chave] ?? (soma: 0.0, qtd: 0);
      porSemanaUfMapa[chave] = (soma: at.soma + r.preco, qtd: at.qtd + 1);
    }
    final porSemanaUf = porSemanaUfMapa.entries.map((e) {
      final partes = e.key.split('__');
      return (semana: partes[0], uf: partes[1], precoMedio: e.value.qtd > 0 ? e.value.soma / e.value.qtd : 0.0, qtd: e.value.qtd);
    }).toList();

    final seriesPorUf = <_SerieUf>[];
    for (final entry in topUfs.asMap().entries) {
      final idx = entry.key;
      final uf = entry.value;
      final pontos = porSemanaUf.where((p) => p.uf == uf).toList()..sort((a, b) => a.semana.compareTo(b.semana));
      if (pontos.isEmpty) continue;
      final primeiraSemanaTs = _dataCompleta(pontos.first.semana).millisecondsSinceEpoch.toDouble();
      final xs = pontos.map((p) => (_dataCompleta(p.semana).millisecondsSinceEpoch.toDouble() - primeiraSemanaTs) / (1000 * 60 * 60 * 24)).toList();
      final reg = pontos.length >= 3 ? _regressaoLinear(List.generate(pontos.length, (i) => (x: xs[i], y: pontos[i].precoMedio))) : null;
      final tendenciaMes = reg != null ? reg.slope * 30 : 0.0; // slope é R$/dia — ×30 continua dando a variação equivalente por mês, só que calculada com pontos semanais
      final m = media(pontos.map((p) => p.precoMedio).toList());
      final variancia = pontos.isEmpty ? 0.0 : pontos.fold<double>(0, (s, p) => s + (p.precoMedio - m) * (p.precoMedio - m)) / pontos.length;
      seriesPorUf.add(_SerieUf(
        uf: uf,
        cor: _coresUfTend[idx % _coresUfTend.length],
        pontos: pontos,
        tendenciaMes: tendenciaMes,
        media: m,
        desvio: _raizQuadrada(variancia),
      ));
    }

    final todasSemanas = porSemanaUf.map((p) => p.semana).toSet().toList()..sort();

    // Heatmap
    double heatMin = double.infinity;
    double heatMax = -double.infinity;
    final heatLinhas = topUfs.map((uf) {
      final porMesNum = <int, ({double soma, int qtd})>{};
      for (final p in porMesUf) {
        if (p.uf != uf) continue;
        final mesNum = _mesNumero(p.mes);
        final at = porMesNum[mesNum] ?? (soma: 0.0, qtd: 0);
        porMesNum[mesNum] = (soma: at.soma + p.precoMedio * p.qtd, qtd: at.qtd + p.qtd);
      }
      final valores = List.generate(12, (i) {
        final v = porMesNum[i];
        final m = (v != null && v.qtd > 0) ? v.soma / v.qtd : null;
        if (m != null) {
          if (m < heatMin) heatMin = m;
          if (m > heatMax) heatMax = m;
        }
        return m;
      });
      return (uf: uf, valores: valores);
    }).toList();
    if (heatMin == double.infinity) heatMin = 0;
    if (heatMax == -double.infinity) heatMax = 0;

    // Volatilidade por combustível — pedido do Daniel: escala de semana em
    // vez de mês (a RPC `historico_precos_volatilidade_mensal` só calcula
    // por mês, então recalculamos aqui direto do histórico bruto, mesma
    // fórmula do banco — stddev populacional, `having count(*) >= 2`).
    final porSemanaCombMapa = <String, List<double>>{};
    for (final r in widget.dados.historicoDetalhado) {
      if (r.preco <= 0) continue;
      porSemanaCombMapa.putIfAbsent('${r.semana}__${r.combustivel}', () => []).add(r.preco);
    }
    final volatilidade = porSemanaCombMapa.entries.where((e) => e.value.length >= 2).map((e) {
      final partes = e.key.split('__');
      final m = media(e.value);
      final variancia = e.value.fold<double>(0, (s, v) => s + (v - m) * (v - m)) / e.value.length;
      return (semana: partes[0], combustivel: partes[1], volatilidade: _raizQuadrada(variancia), qtd: e.value.length);
    }).toList();
    final combustiveisVol = volatilidade.map((v) => v.combustivel).toSet().toList()..sort();
    final semanasVol = volatilidade.map((v) => v.semana).toSet().toList()..sort();

    // Insights
    final globalPorMesMapa = <String, ({double soma, int qtd})>{};
    for (final p in porMesUf) {
      final at = globalPorMesMapa[p.mes] ?? (soma: 0.0, qtd: 0);
      globalPorMesMapa[p.mes] = (soma: at.soma + p.precoMedio * p.qtd, qtd: at.qtd + p.qtd);
    }
    final globalPorMes = globalPorMesMapa.entries.map((e) => (mes: e.key, precoMedio: e.value.qtd > 0 ? e.value.soma / e.value.qtd : 0.0)).toList()..sort((a, b) => a.mes.compareTo(b.mes));
    final n3 = (globalPorMes.length / 3).floor().clamp(1, 999999);
    final inicio = globalPorMes.take(n3).toList();
    final fim = globalPorMes.length > n3 ? globalPorMes.skip(globalPorMes.length - n3).toList() : globalPorMes;
    final mediaIni = inicio.isEmpty ? 0.0 : media(inicio.map((p) => p.precoMedio).toList());
    final mediaFim = fim.isEmpty ? 0.0 : media(fim.map((p) => p.precoMedio).toList());
    final varPct = mediaIni != 0 ? ((mediaFim - mediaIni) / mediaIni) * 100 : 0.0;

    final globalPorMesNumMapa = <int, ({double soma, int qtd})>{};
    for (final p in porMesUf) {
      final mesNum = _mesNumero(p.mes);
      final at = globalPorMesNumMapa[mesNum] ?? (soma: 0.0, qtd: 0);
      globalPorMesNumMapa[mesNum] = (soma: at.soma + p.precoMedio * p.qtd, qtd: at.qtd + p.qtd);
    }
    final globalPorMesNum = globalPorMesNumMapa.entries.map((e) => (mesNum: e.key, media: e.value.qtd > 0 ? e.value.soma / e.value.qtd : 0.0)).toList();
    final mesMaisCaro = globalPorMesNum.isEmpty ? null : globalPorMesNum.reduce((a, b) => b.media > a.media ? b : a);
    final mesMaisBarato = globalPorMesNum.isEmpty ? null : globalPorMesNum.reduce((a, b) => b.media < a.media ? b : a);

    final volPorCombustivelMapa = <String, ({double soma, int qtd})>{};
    for (final v in volatilidade) {
      final at = volPorCombustivelMapa[v.combustivel] ?? (soma: 0.0, qtd: 0);
      volPorCombustivelMapa[v.combustivel] = (soma: at.soma + v.volatilidade, qtd: at.qtd + 1);
    }
    final volPorCombustivel = volPorCombustivelMapa.entries.map((e) => (combustivel: e.key, media: e.value.qtd > 0 ? e.value.soma / e.value.qtd : 0.0)).toList();
    final maisVolatil = volPorCombustivel.isEmpty ? null : volPorCombustivel.reduce((a, b) => b.media > a.media ? b : a);
    final ufMaiorAlta = seriesPorUf.where((s) => s.tendenciaMes > 0.01).toList()..sort((a, b) => b.tendenciaMes.compareTo(a.tendenciaMes));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Combustível: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
            DropdownButton<String>(
              value: _selecionado,
              isDense: true,
              items: ['Todos', ...combustiveis].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) => setState(() => _selecionado = v ?? 'Todos'),
            ),
          ]),
          const SizedBox(height: 12),
          BlocoInsight(texto: '${varPct > 5 ? "📈 Alta tendência geral" : (varPct < -5 ? "📉 Queda de preços no período" : "➡️ Preços relativamente estáveis")} — variação de ${varPct >= 0 ? "+" : ""}${varPct.toStringAsFixed(1)}% no período.'),
          if (mesMaisCaro != null && mesMaisBarato != null)
            BlocoInsight(texto: '📅 ${_nomesMesCompleto[mesMaisCaro.mesNum]} costuma ser o mês mais caro e ${_nomesMesCompleto[mesMaisBarato.mesNum]} o mais barato.'),
          if (maisVolatil != null) BlocoInsight(texto: '⚡ Combustível mais volátil: ${maisVolatil.combustivel} (σ médio de ${formatarMoeda(maisVolatil.media)}).'),
          if (ufMaiorAlta.isNotEmpty) BlocoInsight(texto: '🔺 Maior alta: ${ufMaiorAlta.first.uf}, subindo ${formatarMoeda(ufMaiorAlta.first.tendenciaMes)}/mês em média.'),
          const SizedBox(height: 12),
          Text('Tendência de preço por estado (regressão linear, por semana)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          SizedBox(
            height: 300,
            child: LineChart(LineChartData(
              lineTouchData: lineTouchPadrao(formatarY: (v) => formatarMoeda(v)),
              lineBarsData: seriesPorUf.map((s) {
                final idxPorSemana = {for (final p in s.pontos) p.semana: p.precoMedio};
                return LineChartBarData(
                  spots: todasSemanas.asMap().entries.where((e) => idxPorSemana.containsKey(e.value)).map((e) => FlSpot(e.key.toDouble(), idxPorSemana[e.value]!)).toList(),
                  isCurved: false,
                  color: s.cor,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                );
              }).toList(),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, _) => Text(v.toStringAsFixed(2), style: const TextStyle(fontSize: 9)))),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= todasSemanas.length) return const SizedBox.shrink();
                  return Text(_semanaLabel(todasSemanas[i]), style: const TextStyle(fontSize: 8));
                })),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(drawVerticalLine: false),
              borderData: FlBorderData(show: false),
            )),
          ),
          Wrap(spacing: 10, runSpacing: 4, children: seriesPorUf.map((s) => Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 3, color: s.cor),
                const SizedBox(width: 4),
                Text(s.uf, style: const TextStyle(fontSize: 10)),
              ])).toList()),
          const SizedBox(height: 20),
          Text('Sazonalidade — preço médio por mês do ano', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const FixedColumnWidth(38),
              children: [
                TableRow(children: [
                  const SizedBox(width: 40, child: Text('UF', style: TextStyle(fontSize: 9, color: Colors.grey))),
                  ..._nomesMesAbrev.map((m) => Center(child: Text(m, style: const TextStyle(fontSize: 9, color: Colors.grey)))),
                ]),
                ...heatLinhas.map((l) => TableRow(children: [
                      SizedBox(width: 40, child: Text(l.uf, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
                      ...l.valores.map((v) => Container(
                            margin: const EdgeInsets.all(1),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            color: _corCelula(v, heatMin, heatMax),
                            child: Center(child: Text(v != null ? v.toStringAsFixed(2) : '—', style: const TextStyle(fontSize: 8, color: Colors.white))),
                          )),
                    ])),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Volatilidade por combustível (desvio padrão semanal)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          if (semanasVol.isEmpty)
            const Text('Sem dados de volatilidade.', style: TextStyle(color: Colors.grey, fontSize: 12))
          else
            SizedBox(
              height: 240,
              child: LineChart(LineChartData(
                lineTouchData: lineTouchPadrao(formatarY: (v) => formatarMoeda(v)),
                lineBarsData: combustiveisVol.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final c = entry.value;
                  final cor = _coresCombustivelTend[idx % _coresCombustivelTend.length];
                  return LineChartBarData(
                    spots: semanasVol.asMap().entries.map((e) {
                      final ponto = volatilidade.where((v) => v.semana == e.value && v.combustivel == c).toList();
                      final y = ponto.isNotEmpty ? ponto.first.volatilidade : 0.0;
                      return FlSpot(e.key.toDouble(), y);
                    }).toList(),
                    isCurved: true,
                    color: cor,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: cor.withOpacity(0.15)),
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, _) => Text(v.toStringAsFixed(2), style: const TextStyle(fontSize: 9)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= semanasVol.length) return const SizedBox.shrink();
                    return Text(_semanaLabel(semanasVol[i]), style: const TextStyle(fontSize: 8));
                  })),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(drawVerticalLine: false),
                borderData: FlBorderData(show: false),
              )),
            ),
          Wrap(spacing: 10, runSpacing: 4, children: combustiveisVol.asMap().entries.map((e) => Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, color: _coresCombustivelTend[e.key % _coresCombustivelTend.length]),
                const SizedBox(width: 4),
                Text(e.value, style: const TextStyle(fontSize: 10)),
              ])).toList()),
          const SizedBox(height: 20),
          Text('Resumo por estado', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          TabelaSimples(
            colunas: const ['UF', 'Preço médio', 'Volat. σ', 'Tendência', 'Δ R\$/mês'],
            linhas: (([...seriesPorUf]..sort((a, b) => a.uf.compareTo(b.uf))))
                .map((s) => [
                      s.uf,
                      formatarMoeda(s.media),
                      formatarMoeda(s.desvio),
                      s.tendenciaMes > 0.01 ? '📈 Alta' : (s.tendenciaMes < -0.01 ? '📉 Queda' : '➡️ Estável'),
                      '${s.tendenciaMes >= 0 ? "+" : ""}${formatarMoeda(s.tendenciaMes)}',
                    ])
                .toList(),
          ),
        ],
      ),
    );
  }
}

double _raizQuadrada(double v) {
  if (v <= 0) return 0;
  double x = v;
  double y = 1;
  const eps = 1e-10;
  while (x - y > eps) {
    x = (x + y) / 2;
    y = v / x;
  }
  return x;
}
