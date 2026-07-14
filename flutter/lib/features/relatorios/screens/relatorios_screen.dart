import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/relatorios_provider.dart';

const _cores = [
  Color(0xFF1565C0),
  Color(0xFFE65100),
  Color(0xFF2E7D32),
  Color(0xFF6A1B9A),
  Color(0xFFB71C1C),
  Color(0xFF00838F),
  Color(0xFFF9A825),
  Color(0xFF4527A0),
];

// Fase FLT-3 — Relatórios Personalizados (cliente), porta de
// RelatoriosPersonalizados.tsx. Ver escopo completo (o que ficou de fora)
// em relatorios_provider.dart.
class RelatoriosScreen extends ConsumerStatefulWidget {
  const RelatoriosScreen({super.key});

  @override
  ConsumerState<RelatoriosScreen> createState() => _RelatoriosScreenState();
}

class _RelatoriosScreenState extends ConsumerState<RelatoriosScreen> {
  String _fonte = 'abastecimentos';
  late String _dimensaoId = dimensoesPorFonte[_fonte]!.first.id;
  late List<String> _metricaIds = [metricasPorFonte[_fonte]!.first.id];
  String _tipoGrafico = 'bar';

  void _trocarFonte(String novaFonte) {
    setState(() {
      _fonte = novaFonte;
      _dimensaoId = dimensoesPorFonte[novaFonte]!.first.id;
      _metricaIds = [metricasPorFonte[novaFonte]!.first.id];
    });
  }

  String _compacto(double v) {
    if (v.abs() >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final brutosAsync = ref.watch(relatoriosBrutosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios Personalizados')),
      body: brutosAsync.when(
        data: (brutos) => _conteudo(brutos),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar relatórios: $e')),
      ),
    );
  }

  List<Object> _dadosBase(RelatoriosBrutos brutos) {
    switch (_fonte) {
      case 'manutencao':
        return brutos.manutencoes.cast<Object>();
      case 'custos_fixos':
        return brutos.custosFixos.cast<Object>();
      default:
        return brutos.abastecimentos.cast<Object>();
    }
  }

  Widget _conteudo(RelatoriosBrutos brutos) {
    final dimensoesDisponiveis = dimensoesPorFonte[_fonte]!;
    final metricasDisponiveis = metricasPorFonte[_fonte]!;
    final dimensaoAtual = dimensoesDisponiveis.firstWhere((d) => d.id == _dimensaoId, orElse: () => dimensoesDisponiveis.first);
    final metricasAtuais = metricasDisponiveis.where((m) => _metricaIds.contains(m.id)).toList();
    final dadosBase = _dadosBase(brutos);
    final resultado = calcularResultado(dadosBase, dimensaoAtual, metricasAtuais);
    final metricaGrafico = metricasAtuais.isNotEmpty ? metricasAtuais.first : metricasDisponiveis.first;
    final dadosGrafico = resultado.take(25).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF4F46E5)]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🗂️ Relatórios Personalizados', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              SizedBox(height: 4),
              Text('Combine fonte, dimensão, uma ou mais métricas e tipo de gráfico.',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text('Fonte', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: _fonte,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          items: const [
            DropdownMenuItem(value: 'abastecimentos', child: Text('⛽ Abastecimentos')),
            DropdownMenuItem(value: 'manutencao', child: Text('🔧 Manutenção')),
            DropdownMenuItem(value: 'custos_fixos', child: Text('💰 Custos Fixos')),
          ],
          onChanged: (v) => _trocarFonte(v ?? _fonte),
        ),
        const SizedBox(height: 12),

        const Text('Dimensão', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: dimensaoAtual.id,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          items: dimensoesDisponiveis.map((d) => DropdownMenuItem(value: d.id, child: Text(d.label))).toList(),
          onChanged: (v) => setState(() => _dimensaoId = v ?? _dimensaoId),
        ),
        const SizedBox(height: 12),

        const Text('Métricas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: metricasDisponiveis.map((m) {
            final selecionada = _metricaIds.contains(m.id);
            return FilterChip(
              label: Text(m.label, style: const TextStyle(fontSize: 12)),
              selected: selecionada,
              onSelected: (v) => setState(() {
                if (v) {
                  _metricaIds = [..._metricaIds, m.id];
                } else if (_metricaIds.length > 1) {
                  _metricaIds = _metricaIds.where((id) => id != m.id).toList();
                }
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        const Text('Gráfico', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: _tipoGrafico,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          items: const [
            DropdownMenuItem(value: 'bar', child: Text('📊 Barras')),
            DropdownMenuItem(value: 'line', child: Text('📈 Linhas')),
            DropdownMenuItem(value: 'pie', child: Text('🥧 Pizza')),
            DropdownMenuItem(value: 'table', child: Text('📋 Tabela')),
          ],
          onChanged: (v) => setState(() => _tipoGrafico = v ?? _tipoGrafico),
        ),
        const SizedBox(height: 20),

        if (dadosBase.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Nenhum dado de ${_fonte == 'abastecimentos' ? 'abastecimento' : _fonte == 'manutencao' ? 'manutenção' : 'custo fixo'} '
              'encontrado no período (últimos 12 meses${_fonte == 'custos_fixos' ? ', e também os próximos 12' : ''}).',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          )
        else if (resultado.isEmpty || metricasAtuais.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('Nenhum resultado para essa combinação de dimensão/métrica.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          )
        else ...[
          Text(
            '${metricasAtuais.map((m) => m.label).join(', ')} por ${dimensaoAtual.label.toLowerCase()} — ${resultado.length} grupo(s)'
            '${resultado.length > 25 ? ' (mostrando os 25 maiores no gráfico)' : ''}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          if (metricasAtuais.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'O gráfico mostra apenas a 1ª métrica selecionada (${metricaGrafico.label}) — as demais continuam na tabela abaixo.',
                style: TextStyle(fontSize: 11, color: Colors.amber.shade800),
              ),
            ),
          if (_tipoGrafico != 'table') _grafico(dadosGrafico, metricaGrafico),
          const SizedBox(height: 16),
          _tabela(resultado, dimensaoAtual, metricasAtuais),
        ],
      ],
    );
  }

  Widget _grafico(List<GrupoRelatorio> dados, MetricaRelatorio metrica) {
    if (dados.isEmpty) return const SizedBox.shrink();
    switch (_tipoGrafico) {
      case 'pie':
        return _pizza(dados, metrica);
      case 'line':
        return _linha(dados, metrica);
      default:
        return _barras(dados, metrica);
    }
  }

  Widget _barras(List<GrupoRelatorio> dados, MetricaRelatorio metrica) {
    final maxV = dados.map((d) => d.valores[metrica.id] ?? 0).fold<double>(0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 260,
      child: BarChart(
        BarChartData(
          maxY: maxV <= 0 ? 1 : maxV * 1.2,
          barGroups: dados.asMap().entries.map((e) {
            return BarChartGroupData(x: e.key, barRods: [
              BarChartRodData(
                toY: e.value.valores[metrica.id] ?? 0,
                color: _cores[e.key % _cores.length],
                width: 14,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ]);
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                getTitlesWidget: (v, _) => Text(_compacto(v), style: const TextStyle(fontSize: 9)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= dados.length) return const SizedBox();
                  final label = dados[idx].chave;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(label.length > 8 ? '${label.substring(0, 8)}…' : label,
                        style: const TextStyle(fontSize: 8), overflow: TextOverflow.ellipsis),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.withOpacity(0.15), strokeWidth: 1),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1E293B),
              getTooltipItem: (group, groupIdx, rod, rodIdx) => BarTooltipItem(
                '${dados[group.x.toInt()].chave}\n${formatarValorMetrica(rod.toY, metrica.formato)}',
                const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _linha(List<GrupoRelatorio> dados, MetricaRelatorio metrica) {
    final maxV = dados.map((d) => d.valores[metrica.id] ?? 0).fold<double>(0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 260,
      child: LineChart(
        LineChartData(
          maxY: maxV <= 0 ? 1 : maxV * 1.2,
          lineBarsData: [
            LineChartBarData(
              spots: dados.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.valores[metrica.id] ?? 0)).toList(),
              isCurved: false,
              color: _cores.first,
              barWidth: 2,
              dotData: const FlDotData(show: true),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 48, getTitlesWidget: (v, _) => Text(_compacto(v), style: const TextStyle(fontSize: 9))),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= dados.length) return const SizedBox();
                  final label = dados[idx].chave;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(label.length > 8 ? '${label.substring(0, 8)}…' : label, style: const TextStyle(fontSize: 8)),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
          gridData: FlGridData(getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.withOpacity(0.15), strokeWidth: 1)),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1E293B),
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${dados[s.x.toInt()].chave}\n${formatarValorMetrica(s.y, metrica.formato)}',
                        const TextStyle(color: Colors.white, fontSize: 11),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pizza(List<GrupoRelatorio> dados, MetricaRelatorio metrica) {
    final total = dados.fold<double>(0, (s, d) => s + (d.valores[metrica.id] ?? 0));
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sections: dados.asMap().entries.map((e) {
                final v = e.value.valores[metrica.id] ?? 0;
                final pct = total > 0 ? v / total * 100 : 0.0;
                return PieChartSectionData(
                  value: v <= 0 ? 0.001 : v,
                  title: '${pct.toStringAsFixed(0)}%',
                  color: _cores[e.key % _cores.length],
                  radius: 85,
                  titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: dados.asMap().entries.map((e) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: _cores[e.key % _cores.length], shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(e.value.chave, style: const TextStyle(fontSize: 10)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _tabela(List<GrupoRelatorio> resultado, DimensaoRelatorio dimensao, List<MetricaRelatorio> metricas) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 44,
        columns: [
          DataColumn(label: Text(dimensao.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
          for (final m in metricas) DataColumn(label: Text(m.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)), numeric: true),
          const DataColumn(label: Text('Registros', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)), numeric: true),
        ],
        rows: resultado
            .map((r) => DataRow(cells: [
                  DataCell(Text(r.chave, style: const TextStyle(fontSize: 12))),
                  for (final m in metricas)
                    DataCell(Text(formatarValorMetrica(r.valores[m.id] ?? 0, m.formato), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  DataCell(Text('${r.qtdLinhas}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
                ]))
            .toList(),
      ),
    );
  }
}
