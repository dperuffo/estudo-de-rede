import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../providers/inteligencia_rede_provider.dart';
import '../../widgets/inteligencia_shared.dart';

// Aba 1/10 — "⛽ Preços vs ANP". Porta GraficoCustoAnp.tsx + tabela +
// GraficoSavingMensal.tsx.
class AbaPrecosAnp extends StatefulWidget {
  final InteligenciaRedeCompleta dados;
  const AbaPrecosAnp({super.key, required this.dados});

  @override
  State<AbaPrecosAnp> createState() => _AbaPrecosAnpState();
}

class _AbaPrecosAnpState extends State<AbaPrecosAnp> {
  String _combustivelSaving = 'Todos';

  @override
  Widget build(BuildContext context) {
    final d = widget.dados;
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
                  const Text('Preço médio da rede vs referência ANP', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    d.semanaAnpMaisRecente != null
                        ? 'Referência oficial ANP da semana de ${_dataBr(d.semanaAnpMaisRecente!.dataInicial)} a ${_dataBr(d.semanaAnpMaisRecente!.dataFinal)}. Combustíveis sem categoria oficial mapeada usam uma estimativa fixa.'
                        : 'Nenhuma planilha oficial da ANP foi importada ainda — usando estimativa fixa como referência provisória.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 12),
                  if (d.precoPorCombustivel.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Ainda não há preços cadastrados. Importe as planilhas em Postos Revendedores.', style: TextStyle(color: Colors.grey)),
                    )
                  else ...[
                    _GraficoCustoAnp(dados: d.precoPorCombustivel),
                    const SizedBox(height: 12),
                    TabelaSimples(
                      colunas: const ['Combustível', 'Preço GF', 'Referência', 'Diferença'],
                      flexColunas: const [3, 2, 3, 2],
                      linhas: d.precoPorCombustivel
                          .map((p) => [
                                p.combustivel,
                                formatarMoeda(p.precoMedio, casas: 2),
                                p.referencia != null
                                    ? '${formatarMoeda(p.referencia!, casas: 2)} ${p.ehOficial ? "(oficial)" : "(estim.)"}'
                                    : 'sem ref.',
                                p.deltaPct != null ? '${p.deltaPct! > 0 ? "+" : ""}${p.deltaPct!.toStringAsFixed(1)}%' : '—',
                              ])
                          .toList(),
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
                  const Text('💰 Saving Mensal Acumulado', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    'Evolução mensal do preço médio GF. Barras verdes = abaixo do ANP (saving); vermelhas = acima do ANP (custo extra).',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 12),
                  _graficoSavingMensal(d),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _graficoSavingMensal(InteligenciaRedeCompleta d) {
    if (d.evolucaoMensal.isEmpty) {
      return const Text('Histórico de preços vazio.', style: TextStyle(color: Colors.grey));
    }
    final combustiveis = d.evolucaoMensal.map((e) => e.combustivel).toSet().toList()..sort();
    final referenciaAtual = _combustivelSaving != 'Todos' ? d.referenciasPorCombustivel[_combustivelSaving] : null;

    final porMes = <String, List<double>>{};
    for (final e in d.evolucaoMensal) {
      if (_combustivelSaving != 'Todos' && e.combustivel != _combustivelSaving) continue;
      porMes.putIfAbsent(e.mes, () => []).add(e.precoMedio);
    }
    final meses = porMes.keys.toList()..sort();
    final serie = meses.map((mes) {
      final precos = porMes[mes]!;
      return (mes: mes, precoMedio: precos.reduce((a, b) => a + b) / precos.length);
    }).toList();

    double? savingAcumulado;
    if (referenciaAtual != null) {
      savingAcumulado = serie.fold<double>(0, (soma, p) => soma + (referenciaAtual - p.precoMedio));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Combustível: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(width: 4),
            DropdownButton<String>(
              value: _combustivelSaving,
              isDense: true,
              items: [
                const DropdownMenuItem(value: 'Todos', child: Text('Todos', style: TextStyle(fontSize: 12))),
                ...combustiveis.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))),
              ],
              onChanged: (v) => setState(() => _combustivelSaving = v ?? 'Todos'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (serie.isEmpty)
          const Text('Sem histórico para esse combustível.', style: TextStyle(color: Colors.grey))
        else ...[
          SizedBox(
            height: 260,
            child: BarChart(
              BarChartData(
                maxY: (serie.map((s) => s.precoMedio).reduce((a, b) => a > b ? a : b) * 1.2).clamp(0.01, double.infinity),
                barGroups: serie.asMap().entries.map((e) {
                  final cor = referenciaAtual == null
                      ? const Color(0xFF1565C0)
                      : (e.value.precoMedio < referenciaAtual ? const Color(0xFF2E7D32) : const Color(0xFFB71C1C));
                  return BarChartGroupData(x: e.key, barRods: [
                    BarChartRodData(toY: e.value.precoMedio, color: cor, width: 14, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
                  ]);
                }).toList(),
                extraLinesData: referenciaAtual != null
                    ? ExtraLinesData(horizontalLines: [
                        HorizontalLine(
                          y: referenciaAtual,
                          color: const Color(0xFFE65100),
                          strokeWidth: 1.5,
                          dashArray: [4, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            labelResolver: (_) => 'ANP: ${formatarMoeda(referenciaAtual!, casas: 2)}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFFE65100)),
                          ),
                        ),
                      ])
                    : const ExtraLinesData(),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, _) => Text(v.toStringAsFixed(2), style: const TextStyle(fontSize: 9)))),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= serie.length) return const SizedBox.shrink();
                        return Padding(padding: const EdgeInsets.only(top: 4), child: Text(_mesLabel(serie[i].mes), style: const TextStyle(fontSize: 9)));
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
          if (savingAcumulado != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  children: [
                    const TextSpan(text: 'Saldo acumulado do período: '),
                    TextSpan(
                      text: '${formatarMoeda(savingAcumulado.abs(), casas: 3)}/L',
                      style: TextStyle(fontWeight: FontWeight.w700, color: savingAcumulado > 0 ? const Color(0xFF2E7D32) : const Color(0xFFB71C1C)),
                    ),
                    TextSpan(text: ' (rede GF ${savingAcumulado > 0 ? "abaixo" : "acima"} do ANP em média)'),
                  ],
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  static String _mesLabel(String mes) {
    final partes = mes.split('-');
    if (partes.length < 2) return mes;
    const nomes = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
    final mesIdx = int.tryParse(partes[1]) ?? 1;
    final ano = partes[0].length == 4 ? partes[0].substring(2) : partes[0];
    return '${nomes[(mesIdx - 1).clamp(0, 11)]}/$ano';
  }

  static String _dataBr(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _GraficoCustoAnp extends StatelessWidget {
  final List<PrecoCombustivelRef> dados;
  const _GraficoCustoAnp({required this.dados});

  @override
  Widget build(BuildContext context) {
    final maxValor = dados.fold<double>(0.01, (m, d) {
      final v1 = d.precoMedio;
      final v2 = d.referencia ?? 0;
      return [m, v1, v2].reduce((a, b) => a > b ? a : b);
    });

    Widget barra(double valor, Color cor) => Container(
          height: 12,
          margin: const EdgeInsets.only(top: 2),
          child: Row(
            children: [
              Expanded(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (valor / maxValor).clamp(0.02, 1.0),
                  child: Container(decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(3))),
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _legendaItem(const Color(0xFFE65100), 'Preço médio GF'),
          const SizedBox(width: 12),
          _legendaItem(const Color(0xFF1565C0), 'Referência ANP'),
        ]),
        const SizedBox(height: 10),
        ...dados.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.combustivel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  barra(d.precoMedio, const Color(0xFFE65100)),
                  Text(formatarMoeda(d.precoMedio, casas: 2), style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  if (d.referencia != null) ...[
                    barra(d.referencia!, const Color(0xFF1565C0)),
                    Text(formatarMoeda(d.referencia!, casas: 2), style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ],
              ),
            )),
      ],
    );
  }

  Widget _legendaItem(Color cor, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, color: cor),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ]);
}
