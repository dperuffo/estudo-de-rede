import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/menu_button.dart';

class PrecosScreen extends StatefulWidget {
  const PrecosScreen({super.key});
  @override State<PrecosScreen> createState() => _State();
}

class _State extends State<PrecosScreen> {
  Map<String, dynamic>? _dados;
  bool _loading = true;
  int _dias = 90;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService().get('/precos/variacao', params: {'dias': _dias});
      setState(() => _dados = r);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt     = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final porComb = (_dados?['por_combustivel'] as List?) ?? [];
    final serie   = (_dados?['serie_temporal']  as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: const Text('Variacao de Precos'),
        actions: [
          DropdownButton<int>(
            value: _dias,
            dropdownColor: const Color(0xFF0D2D6B),
            style: const TextStyle(color: Colors.white),
            items: [30,60,90,180].map((d) => DropdownMenuItem(value: d, child: Text('$d dias'))).toList(),
            onChanged: (v) { setState(() => _dias = v!); _load(); },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: porComb.isEmpty
              ? const Center(child: Text('Sem dados para o periodo'))
              : ListView(padding: const EdgeInsets.all(16), children: [

                  // Cards por combustível
                  _secao('Resumo por combustivel'),
                  ...porComb.map((c) => _cardCombustivel(c, fmt)),
                  const SizedBox(height: 24),

                  // Gráfico de linha evolução de preço
                  if (serie.isNotEmpty) ...[
                    _secao('Evolucao do preco medio por mes'),
                    _graficoLinha(serie, porComb, fmt),
                    const SizedBox(height: 24),
                  ],

                  // Tabela comparativa
                  _secao('Comparativo de combustiveis'),
                  _tabelaComparativa(porComb, fmt),
                ])),
    );
  }

  Widget _secao(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D2D6B))),
  );

  Widget _cardCombustivel(Map c, NumberFormat fmt) {
    final preco  = (c['preco_medio'] as num? ?? 0).toDouble();
    final pMin   = (c['preco_min']   as num? ?? 0).toDouble();
    final pMax   = (c['preco_max']   as num? ?? 0).toDouble();
    final varia  = pMax > 0 ? ((pMax - pMin) / pMax * 100) : 0.0;
    final nome   = c['item_nome']?.toString() ?? '-';
    final isAlto = preco > 6.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0,2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0D2D6B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D2D6B), fontSize: 13)),
          ),
          const Spacer(),
          Text('${c["n"]} abast.', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _precoBadgeGrande('Medio', preco, fmt,
              isAlto ? Colors.red : Colors.green)),
          Expanded(child: _precoBadge('Minimo', pMin, fmt, Colors.green)),
          Expanded(child: _precoBadge('Maximo', pMax, fmt, Colors.red)),
          Expanded(child: Column(children: [
            Text('Variacao', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            Text('${varia.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                    color: varia > 10 ? Colors.red : Colors.orange)),
          ])),
        ]),
        const SizedBox(height: 10),
        // Barra de variação
        Stack(children: [
          Container(height: 6, decoration: BoxDecoration(
            color: Colors.grey[200], borderRadius: BorderRadius.circular(3))),
          FractionallySizedBox(
            widthFactor: pMax > 0 ? (preco - pMin) / (pMax - pMin + 0.001) : 0,
            child: Container(height: 6, decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.green, Colors.orange, Colors.red]),
              borderRadius: BorderRadius.circular(3),
            )),
          ),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Text(fmt.format(pMin), style: const TextStyle(fontSize: 10, color: Colors.green)),
          const Spacer(),
          Text(fmt.format(pMax), style: const TextStyle(fontSize: 10, color: Colors.red)),
        ]),
      ]),
    );
  }

  Widget _precoBadgeGrande(String label, double valor, NumberFormat fmt, Color color) => Column(children: [
    Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
    Text(fmt.format(valor), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
    Text('/L', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
  ]);

  Widget _precoBadge(String label, double valor, NumberFormat fmt, Color color) => Column(children: [
    Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
    Text(fmt.format(valor), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
  ]);

  Widget _graficoLinha(List serie, List porComb, NumberFormat fmt) {
    final combustiveis = porComb.map((c) => c['item_nome']?.toString() ?? '').toSet().toList();
    final cores = [const Color(0xFF1565C0), Colors.red, Colors.green, Colors.orange, Colors.purple];

    final meses = serie.map((s) => s['mes']?.toString() ?? '').toSet().toList()..sort();
    if (meses.isEmpty) return const SizedBox();

    List<LineChartBarData> linhas = [];
    for (int ci = 0; ci < combustiveis.length && ci < 4; ci++) {
      final comb = combustiveis[ci];
      final spots = <FlSpot>[];
      for (int mi = 0; mi < meses.length; mi++) {
        final entry = serie.firstWhere(
          (s) => s['mes'] == meses[mi] && s['item_nome'] == comb,
          orElse: () => {},
        );
        if (entry.isNotEmpty) {
          spots.add(FlSpot(mi.toDouble(), (entry['preco_medio'] as num? ?? 0).toDouble()));
        }
      }
      if (spots.isNotEmpty) {
        linhas.add(LineChartBarData(
          spots: spots,
          isCurved: true,
          color: cores[ci % cores.length],
          barWidth: 2.5,
          dotData: FlDotData(show: spots.length < 6),
          belowBarData: BarAreaData(show: true, color: cores[ci % cores.length].withOpacity(0.05)),
        ));
      }
    }

    if (linhas.isEmpty) return const SizedBox();

    return Column(children: [
      SizedBox(height: 220, child: LineChart(LineChartData(
        lineBarsData: linhas,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 45,
            getTitlesWidget: (v, _) => Text('R\$${v.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 9)),
          )),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 22,
            getTitlesWidget: (v, _) {
              final idx = v.toInt();
              if (idx < 0 || idx >= meses.length) return const SizedBox();
              return Text(meses[idx].substring(5), style: const TextStyle(fontSize: 9));
            },
          )),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.withOpacity(0.15), strokeWidth: 1)),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
              fmt.format(s.y), TextStyle(color: cores[s.barIndex % cores.length], fontSize: 11)
            )).toList(),
          ),
        ),
      ))),
      const SizedBox(height: 8),
      Wrap(spacing: 12, children: List.generate(combustiveis.length > 4 ? 4 : combustiveis.length, (i) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 3, color: cores[i % cores.length]),
          const SizedBox(width: 4),
          Text(combustiveis[i], style: const TextStyle(fontSize: 11)),
        ])
      )),
    ]);
  }

  Widget _tabelaComparativa(List porComb, NumberFormat fmt) {
    return Table(
      border: TableBorder.all(color: Colors.grey.withOpacity(0.2), width: 0.5),
      columnWidths: const {0: FlexColumnWidth(2.5), 1: FlexColumnWidth(1.5), 2: FlexColumnWidth(1.5), 3: FlexColumnWidth(1.5)},
      children: [
        TableRow(decoration: const BoxDecoration(color: Color(0xFF0D2D6B)), children: [
          _celTabHeader('Combustivel'),
          _celTabHeader('Medio'),
          _celTabHeader('Min'),
          _celTabHeader('Max'),
        ]),
        ...porComb.map((c) => TableRow(children: [
          _celTab(c['item_nome']?.toString() ?? '-', bold: true),
          _celTab(fmt.format(c['preco_medio'] ?? 0), color: Colors.blue),
          _celTab(fmt.format(c['preco_min'] ?? 0), color: Colors.green),
          _celTab(fmt.format(c['preco_max'] ?? 0), color: Colors.red),
        ])),
      ],
    );
  }

  Widget _celTabHeader(String t) => Padding(
    padding: const EdgeInsets.all(8),
    child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
  );

  Widget _celTab(String t, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.all(8),
    child: Text(t, style: TextStyle(fontSize: 11, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color),
        textAlign: TextAlign.center),
  );
}
