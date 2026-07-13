import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/dashboard_posto_provider.dart';

// Paleta fixa por combustível — mesma família de cores usada nos gráficos
// já existentes (precos_screen.dart, analise_cliente_screen.dart), pra
// manter a identidade visual entre as duas visões do app.
const _coresCombustivel = [
  Color(0xFF1565C0),
  Colors.red,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.teal,
];

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _numero = NumberFormat.decimalPattern('pt_BR');
final _dataBr = DateFormat('dd/MM/yyyy');

String _formatarData(String? iso) {
  if (iso == null) return '—';
  try {
    return _dataBr.format(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
}

// Fase FLT-2 — primeira tela real da visão Posto (as outras 16 continuam
// placeholder). Espelha DashboardPosto.tsx da web: indicadores de venda dos
// últimos 30 dias (via RPC resumo_vendas_diarias_posto), desempenho por
// combustível, e indicadores/listas de negociações (negociacoes_postos).
// O gráfico evolutivo diário da web fica pra uma próxima iteração — aqui
// entram números e tabelas, que já cobrem o essencial do painel.
class PostoDashboardScreen extends ConsumerWidget {
  const PostoDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dadosAsync = ref.watch(dashboardPostoProvider);
    final sessao = ref.watch(sessaoProvider).valueOrNull;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(dashboardPostoProvider),
      child: dadosAsync.when(
        loading: () => const Center(child: Padding(
          padding: EdgeInsets.only(top: 80),
          child: CircularProgressIndicator(),
        )),
        error: (e, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.error_outline, size: 40, color: Colors.red),
            const SizedBox(height: 12),
            Text('Não deu pra carregar o painel.\n$e', textAlign: TextAlign.center),
          ],
        ),
        data: (dados) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              sessao?.nomeEmpresa != null ? 'Dashboard — ${sessao!.nomeEmpresa}' : 'Dashboard',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text('Desempenho de vendas e negociações.',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 20),

            _tituloSecao('Vendas — últimos 30 dias'),
            _gradeIndicadores([
              _Indicador('Abastecimentos', _numero.format(dados.totalAbastecimentos)),
              _Indicador('Volume', '${_numero.format(dados.volumeVendido.round())} L'),
              _Indicador('Receita', _moeda.format(dados.receitaVendida)),
              _Indicador('Preço médio', _moeda.format(dados.precoMedioGeral)),
              _Indicador('Ticket médio', _moeda.format(dados.ticketMedio)),
            ]),

            const SizedBox(height: 20),
            _tituloSecao('Venda diária por combustível — últimos $janelaGraficoDias dias'),
            if (dados.serieDiariaPorCombustivel.isEmpty)
              _cardVazio('Sem dados suficientes no período.')
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
                  child: _graficoLinhaVendaDiaria(dados.serieDiariaPorCombustivel),
                ),
              ),

            const SizedBox(height: 20),
            _tituloSecao('Desempenho por combustível'),
            if (dados.desempenhoPorCombustivel.isEmpty)
              _cardVazio('Nenhum abastecimento no período.')
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _donutParticipacao(dados.desempenhoPorCombustivel),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: dados.desempenhoPorCombustivel
                      .map((d) => ListTile(
                            dense: true,
                            title: Text(d.combustivel),
                            subtitle: Text(
                              '${_numero.format(d.volume.round())} L · ${_moeda.format(d.precoMedio)}/L',
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_moeda.format(d.receita),
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text('${d.participacao.toStringAsFixed(0)}%',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],

            const SizedBox(height: 20),
            _tituloSecao('Negociações'),
            _gradeIndicadores([
              _Indicador('Aguardando resposta', '${dados.pendentes}'),
              _Indicador('Vigentes', '${dados.vigentes}'),
              _Indicador('Clientes ativos', '${dados.clientesAtivos}'),
              _Indicador('Vol. mín./mês', '${_numero.format(dados.volumeContratado.round())} L'),
            ]),

            const SizedBox(height: 20),
            _tituloSecao('Negociações vigentes agora'),
            if (dados.vigentesLista.isEmpty)
              _cardVazio('Nenhuma negociação vigente no momento.')
            else
              Card(
                child: Column(
                  children: dados.vigentesLista
                      .map((n) => ListTile(
                            dense: true,
                            title: Text(n.clienteNome ?? '—'),
                            subtitle: Text(
                              '${n.combustivel ?? '—'} · ${_formatarData(n.vigenciaInicio)} – ${_formatarData(n.vigenciaFim)}\n'
                              '${n.volumeMinimoMensal != null ? '${_numero.format(n.volumeMinimoMensal!.round())} L/mês' : '—'}'
                              '${n.precoUnitario != null ? ' · ${_moeda.format(n.precoUnitario)}/L' : ''}',
                            ),
                            isThreeLine: true,
                            onTap: () => context.push('/posto/negociacoes'),
                          ))
                      .toList(),
                ),
              ),

            if (dados.pendentesLista.isNotEmpty) ...[
              const SizedBox(height: 20),
              _tituloSecao('Aguardando sua resposta'),
              Card(
                child: Column(
                  children: dados.pendentesLista
                      .map((n) => ListTile(
                            dense: true,
                            title: Text(n.clienteNome ?? '—'),
                            trailing: TextButton(
                              onPressed: () => context.push('/posto/negociacoes'),
                              child: const Text('Responder'),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Porta de GraficoEvolutivoPostos.tsx (LineChart do recharts) — 1 linha
  // por combustível, eixo X = dia, eixo Y = litros. Mesmo padrão visual dos
  // outros LineChart do app (precos_screen.dart): curva suave, área leve
  // abaixo, tooltip formatado, legenda manual.
  Widget _graficoLinhaVendaDiaria(List<PontoVendaDiaria> pontos) {
    final dias = pontos.map((p) => p.dia).toSet().toList()..sort();
    final combustiveis = pontos.map((p) => p.combustivel).toSet().toList()..sort();
    if (dias.isEmpty || combustiveis.isEmpty) return const SizedBox();

    final linhas = <LineChartBarData>[];
    for (var ci = 0; ci < combustiveis.length; ci++) {
      final comb = combustiveis[ci];
      final spots = <FlSpot>[];
      for (var di = 0; di < dias.length; di++) {
        final ponto = pontos.where((p) => p.dia == dias[di] && p.combustivel == comb);
        final volume = ponto.isNotEmpty ? ponto.first.volume : 0.0;
        spots.add(FlSpot(di.toDouble(), volume));
      }
      final cor = _coresCombustivel[ci % _coresCombustivel.length];
      linhas.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        color: cor,
        barWidth: 2.5,
        dotData: FlDotData(show: dias.length < 10),
        belowBarData: BarAreaData(show: true, color: cor.withOpacity(0.05)),
      ));
    }

    return Column(children: [
      SizedBox(
        height: 220,
        child: LineChart(LineChartData(
          lineBarsData: linhas,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, _) =>
                  Text(_numero.format(v.round()), style: const TextStyle(fontSize: 9)),
            )),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: dias.length > 6 ? (dias.length / 6).ceilToDouble() : 1,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= dias.length) return const SizedBox();
                return Text(_formatarData(dias[idx]).substring(0, 5),
                    style: const TextStyle(fontSize: 9));
              },
            )),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: Colors.grey.withOpacity(0.15), strokeWidth: 1),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${_numero.format(s.y.round())} L',
                        TextStyle(color: _coresCombustivel[s.barIndex % _coresCombustivel.length], fontSize: 11),
                      ))
                  .toList(),
            ),
          ),
        )),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 12,
        children: List.generate(
          combustiveis.length,
          (i) => Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 12, height: 3, color: _coresCombustivel[i % _coresCombustivel.length]),
            const SizedBox(width: 4),
            Text(combustiveis[i], style: const TextStyle(fontSize: 11)),
          ]),
        ),
      ),
    ]);
  }

  // Donut de participação por combustível — sem equivalente direto na web
  // ainda; dado já vinha calculado no provider (desempenhoPorCombustivel).
  Widget _donutParticipacao(List<DesempenhoCombustivel> lista) {
    return SizedBox(
      height: 180,
      child: Row(children: [
        Expanded(
          child: PieChart(PieChartData(
            sections: lista.asMap().entries.map((e) {
              final cor = _coresCombustivel[e.key % _coresCombustivel.length];
              return PieChartSectionData(
                value: e.value.volume,
                title: '${e.value.participacao.toStringAsFixed(0)}%',
                color: cor,
                radius: 60,
                titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              );
            }).toList(),
            centerSpaceRadius: 32,
            sectionsSpace: 2,
          )),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lista.asMap().entries.map((e) {
              final cor = _coresCombustivel[e.key % _coresCombustivel.length];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(e.value.combustivel,
                        style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                  ),
                ]),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

  Widget _tituloSecao(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          texto.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      );

  Widget _cardVazio(String texto) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text(texto, style: const TextStyle(color: Colors.grey))),
        ),
      );

  Widget _gradeIndicadores(List<_Indicador> itens) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        children: itens
            .map((i) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(i.label,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(i.valor,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ))
            .toList(),
      );
}

class _Indicador {
  final String label;
  final String valor;
  const _Indicador(this.label, this.valor);
}
