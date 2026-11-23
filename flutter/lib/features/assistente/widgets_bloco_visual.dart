import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../posto/services/assistente_service.dart';

// Porta do desenho de gráficos/tabelas do Assistente da web
// (ChatAssistente.tsx) pro PWA. Recebe o BlocoVisual vindo de /api/assistente.
String formatarValorBloco(double v, String formato) {
  switch (formato) {
    case 'moeda':
      return NumberFormat.currency(locale: 'pt_BR', symbol: r'R$').format(v);
    case 'litros':
      return '${NumberFormat('#,##0.##', 'pt_BR').format(v)} L';
    case 'km':
      return '${NumberFormat('#,##0.##', 'pt_BR').format(v)} km';
    case 'percentual':
      return '${NumberFormat('#,##0.##', 'pt_BR').format(v)}%';
    default:
      return NumberFormat('#,##0.##', 'pt_BR').format(v);
  }
}

const _paleta = [
  Color(0xFFB8860B),
  Color(0xFF2563EB),
  Color(0xFF16A34A),
  Color(0xFFDC2626),
  Color(0xFF7C3AED),
  Color(0xFF0891B2),
  Color(0xFFEA580C),
  Color(0xFF64748B),
];

class BlocoVisualWidget extends StatelessWidget {
  final BlocoVisual bloco;
  const BlocoVisualWidget({super.key, required this.bloco});

  @override
  Widget build(BuildContext context) {
    if (bloco.categorias.isEmpty || bloco.series.isEmpty) {
      return const SizedBox.shrink();
    }
    final corTexto = AppTheme.glassTexto;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.bordaSuave),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bloco.titulo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(bloco.titulo,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: corTexto)),
            ),
          switch (bloco.tipo) {
            'barras' => _barras(),
            'linhas' => _linhas(),
            'pizza' => _pizza(),
            _ => _tabela(corTexto),
          },
          if (bloco.tipo != 'tabela' && bloco.tipo != 'pizza' &&
              bloco.series.length > 1)
            _legenda(bloco.series.map((s) => s.nome).toList()),
        ],
      ),
    );
  }

  double get _max {
    var m = 0.0;
    for (final s in bloco.series) {
      for (final v in s.valores) {
        m = math.max(m, v);
      }
    }
    return m <= 0 ? 1 : m;
  }

  Widget _legenda(List<String> nomes) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(spacing: 10, runSpacing: 4, children: [
          for (var i = 0; i < nomes.length; i++)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 10,
                  height: 10,
                  color: _paleta[i % _paleta.length]),
              const SizedBox(width: 4),
              Text(nomes[i], style: const TextStyle(fontSize: 11)),
            ]),
        ]),
      );

  FlTitlesData get _titulos => FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 52,
            getTitlesWidget: (v, meta) => Text(
                formatarValorBloco(v, bloco.formato),
                style: const TextStyle(fontSize: 9)),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            getTitlesWidget: (v, meta) {
              final i = v.toInt();
              if (i < 0 || i >= bloco.categorias.length) {
                return const SizedBox.shrink();
              }
              final t = bloco.categorias[i];
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(t.length > 8 ? '${t.substring(0, 7)}…' : t,
                    style: const TextStyle(fontSize: 9)),
              );
            },
          ),
        ),
      );

  Widget _barras() => SizedBox(
        height: 220,
        child: BarChart(BarChartData(
          maxY: _max * 1.1,
          titlesData: _titulos,
          gridData: const FlGridData(drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var i = 0; i < bloco.categorias.length; i++)
              BarChartGroupData(x: i, barRods: [
                for (var j = 0; j < bloco.series.length; j++)
                  BarChartRodData(
                    toY: i < bloco.series[j].valores.length
                        ? bloco.series[j].valores[i]
                        : 0,
                    color: _paleta[j % _paleta.length],
                    width: bloco.series.length > 1 ? 8 : 14,
                  ),
              ]),
          ],
        )),
      );

  Widget _linhas() => SizedBox(
        height: 220,
        child: LineChart(LineChartData(
          maxY: _max * 1.1,
          minY: 0,
          titlesData: _titulos,
          gridData: const FlGridData(drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            for (var j = 0; j < bloco.series.length; j++)
              LineChartBarData(
                color: _paleta[j % _paleta.length],
                barWidth: 2,
                dotData: const FlDotData(show: true),
                spots: [
                  for (var i = 0; i < bloco.series[j].valores.length; i++)
                    FlSpot(i.toDouble(), bloco.series[j].valores[i]),
                ],
              ),
          ],
        )),
      );

  Widget _pizza() {
    final valores = bloco.series.first.valores;
    final total = valores.fold<double>(0, (a, b) => a + b);
    return Column(children: [
      SizedBox(
        height: 180,
        child: PieChart(PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 36,
          sections: [
            for (var i = 0; i < valores.length; i++)
              PieChartSectionData(
                value: valores[i] <= 0 ? 0.0001 : valores[i],
                color: _paleta[i % _paleta.length],
                radius: 48,
                title: total > 0
                    ? '${(valores[i] / total * 100).toStringAsFixed(0)}%'
                    : '',
                titleStyle: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
          ],
        )),
      ),
      Wrap(spacing: 10, runSpacing: 4, children: [
        for (var i = 0; i < bloco.categorias.length && i < valores.length; i++)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 10, height: 10, color: _paleta[i % _paleta.length]),
            const SizedBox(width: 4),
            Text(
                '${bloco.categorias[i]}: ${formatarValorBloco(valores[i], bloco.formato)}',
                style: const TextStyle(fontSize: 11)),
          ]),
      ]),
    ]);
  }

  Widget _tabela(Color corTexto) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 32,
          dataRowMinHeight: 28,
          dataRowMaxHeight: 36,
          columnSpacing: 20,
          columns: [
            const DataColumn(label: Text('')),
            for (final s in bloco.series)
              DataColumn(
                  label: Text(s.nome, style: const TextStyle(fontSize: 12)),
                  numeric: true),
          ],
          rows: [
            for (var i = 0; i < bloco.categorias.length; i++)
              DataRow(cells: [
                DataCell(Text(bloco.categorias[i],
                    style: const TextStyle(fontSize: 12))),
                for (final s in bloco.series)
                  DataCell(Text(
                      i < s.valores.length
                          ? formatarValorBloco(s.valores[i], bloco.formato)
                          : '',
                      style: const TextStyle(fontSize: 12))),
              ]),
          ],
        ),
      );
}
