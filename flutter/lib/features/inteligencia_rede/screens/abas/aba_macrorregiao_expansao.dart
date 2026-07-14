import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../providers/inteligencia_rede_provider.dart';
import '../../widgets/inteligencia_shared.dart';

// Aba 3/10 — "👔 Macrorregião & Expansão". Porta
// GraficoCoberturaMacrorregiao.tsx + GraficoOportunidadesExpansao.tsx.
class AbaMacrorregiaoExpansao extends StatelessWidget {
  final InteligenciaRedeCompleta dados;
  const AbaMacrorregiaoExpansao({super.key, required this.dados});

  static Color _corCobertura(double pct) {
    if (pct >= 30) return const Color(0xFF2E7D32);
    if (pct >= 10) return const Color(0xFFF57F17);
    return const Color(0xFFB71C1C);
  }

  static Color _corScore(double score) {
    if (score >= 80) return const Color(0xFFB71C1C);
    if (score >= 60) return const Color(0xFFE65100);
    if (score >= 40) return const Color(0xFFF57F17);
    return const Color(0xFF1565C0);
  }

  @override
  Widget build(BuildContext context) {
    final d = dados;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🗺️ Cobertura da Rede por Macrorregião', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text('% dos municípios de cada macrorregião que já têm ao menos 1 posto GF (referência IBGE).', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(height: 12),
                  if (d.coberturaMacrorregiao.isEmpty)
                    const Text('Ainda não há postos cadastrados.', style: TextStyle(color: Colors.grey))
                  else ...[
                    BarraHorizontal(
                      dados: d.coberturaMacrorregiao
                          .map((c) => BarraHorizontalItem(label: c.regiao, valor: c.coberturaPct, cor: _corCobertura(c.coberturaPct), texto: '${c.coberturaPct.toStringAsFixed(1)}%'))
                          .toList(),
                      eixoX: 'Cobertura de municípios',
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.5,
                      children: d.coberturaMacrorregiao.map((c) {
                        final cor = _corCobertura(c.coberturaPct);
                        return Container(
                          decoration: BoxDecoration(border: Border(top: BorderSide(color: cor, width: 3))),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              Text(c.regiao, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              Text('${c.coberturaPct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cor)),
                              Text('${c.postosGf} postos', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                              Text('${c.estadosComGf}/${c.totalUfs} estados', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🎯 Top Oportunidades de Expansão', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text('Menor penetração GF + maior preço de mercado (diesel ANP) = maior oportunidade.', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(height: 12),
                  if (d.oportunidades.isEmpty)
                    const Text('Sem dados suficientes para calcular oportunidades.', style: TextStyle(color: Colors.grey))
                  else ...[
                    SizedBox(
                      height: 260,
                      child: BarChart(
                        BarChartData(
                          maxY: 105,
                          barGroups: d.oportunidades.asMap().entries.map((e) {
                            return BarChartGroupData(x: e.key, barRods: [
                              BarChartRodData(toY: e.value.score, color: _corScore(e.value.score), width: 18, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
                            ]);
                          }).toList(),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 9)))),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 24,
                                getTitlesWidget: (v, _) {
                                  final i = v.toInt();
                                  if (i < 0 || i >= d.oportunidades.length) return const SizedBox.shrink();
                                  return Text(d.oportunidades[i].uf, style: const TextStyle(fontSize: 10));
                                },
                              ),
                            ),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: const FlGridData(drawVerticalLine: false),
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TabelaSimples(
                      colunas: const ['UF', 'Postos GF', 'Penetração', 'Diesel ANP', 'Score'],
                      linhas: d.oportunidades
                          .map((o) => [
                                o.uf,
                                '${o.postosGf}',
                                '${o.penetracaoPct.toStringAsFixed(2)}%',
                                o.dieselAnp != null ? formatarMoeda(o.dieselAnp!, casas: 2) : '—',
                                o.score.toStringAsFixed(0),
                              ])
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
