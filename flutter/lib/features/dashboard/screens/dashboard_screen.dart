import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/dashboard_provider.dart';

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

// Fase FLT-3 — primeira tela real da visão Cliente (ver comentário completo
// em dashboard_provider.dart sobre o escopo reduzido em relação à web).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dadosAsync = ref.watch(dashboardClienteProvider);
    final sessao = ref.watch(sessaoProvider).valueOrNull;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(dashboardClienteProvider),
      child: dadosAsync.when(
        loading: () => const Center(
          child: Padding(padding: EdgeInsets.only(top: 80), child: CircularProgressIndicator()),
        ),
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
            const Text('Visão geral da frota.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 20),

            _gradeIndicadores([
              _Indicador('Clientes ativos', '${dados.clientesAtivos}', 'de ${dados.totalClientes}'),
              _Indicador('Motoristas ativos', '${dados.motoristasAtivos}', 'de ${dados.totalMotoristas}'),
              _Indicador('Veículos ativos', '${dados.veiculosAtivos}', 'de ${dados.totalVeiculos}'),
              _Indicador('Litros no mês', _numero.format(dados.litrosMes.round()), null),
              _Indicador('Valor no mês', _moeda.format(dados.valorMes), null),
              _Indicador('Custo médio/litro', _moeda.format(dados.custoMedioLitroMes), null),
            ]),

            if (dados.provedoresMes.isNotEmpty) ...[
              const SizedBox(height: 20),
              _tituloSecao('Meios de pagamento no mês'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: dados.provedoresMes
                    .map((p) => Chip(label: Text('${p.provedor} · ${_moeda.format(p.valor)}')))
                    .toList(),
              ),
            ],

            const SizedBox(height: 20),
            _tituloSecao('Consumo e gasto — últimos 6 meses'),
            if (dados.serieConsumo.every((p) => p.litros == 0))
              _cardVazio('Ainda não há abastecimentos suficientes para o gráfico.')
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
                  child: _graficoConsumo(dados.serieConsumo),
                ),
              ),

            const SizedBox(height: 20),
            _tituloSecao('CNH vencendo em 30 dias'),
            if (dados.cnhVencendo.isEmpty)
              _cardVazio('Nenhuma CNH vencendo nos próximos 30 dias.')
            else
              Card(
                child: Column(
                  children: dados.cnhVencendo
                      .map((m) => ListTile(
                            dense: true,
                            title: Text(m.nome),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFB45309).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(_formatarData(m.vencimento),
                                  style: const TextStyle(fontSize: 11, color: Color(0xFFB45309), fontWeight: FontWeight.w600)),
                            ),
                          ))
                      .toList(),
                ),
              ),

            const SizedBox(height: 20),
            _tituloSecao('Top 5 clientes por gasto (últimos 6 meses)'),
            if (dados.topClientes.isEmpty)
              _cardVazio('Ainda não há abastecimentos vinculados a um cliente.')
            else
              Card(
                child: Column(
                  children: dados.topClientes
                      .map((c) => ListTile(
                            dense: true,
                            title: Text(c.nome),
                            trailing: Text(_moeda.format(c.valor), style: const TextStyle(fontWeight: FontWeight.w600)),
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // BarChart de litros/mês — a web usa um gráfico de barras com 2 eixos Y
  // (litros à esquerda, valor à direita). Simplificado aqui pra 1 eixo
  // (litros, o principal) + valor exposto no tooltip e no total abaixo —
  // 2 eixos numa tela de celular pequena tende a ficar difícil de ler.
  Widget _graficoConsumo(List<PontoConsumoMensal> pontos) {
    final maxLitros = pontos.map((p) => p.litros).fold<double>(0, (a, b) => a > b ? a : b);
    final valorTotal = pontos.fold<double>(0, (s, p) => s + p.valor);

    return Column(children: [
      SizedBox(
        height: 200,
        child: BarChart(BarChartData(
          maxY: maxLitros <= 0 ? 1 : maxLitros * 1.2,
          barGroups: pontos.asMap().entries.map((e) {
            return BarChartGroupData(x: e.key, barRods: [
              BarChartRodData(
                toY: e.value.litros,
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 18,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ]);
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, _) => Text(_numero.format(v.round()), style: const TextStyle(fontSize: 9)),
            )),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= pontos.length) return const SizedBox();
                return Text(pontos[idx].mesLabel, style: const TextStyle(fontSize: 10));
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
              getTooltipItem: (group, groupIdx, rod, rodIdx) {
                final p = pontos[group.x];
                return BarTooltipItem(
                  '${_numero.format(p.litros.round())} L\n${_moeda.format(p.valor)}',
                  const TextStyle(color: Color(0xFF1565C0), fontSize: 11, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
        )),
      ),
      const SizedBox(height: 8),
      Text('Valor gasto no período: ${_moeda.format(valorTotal)}',
          style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]);
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
                        if (i.sub != null)
                          Text(i.sub!,
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
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
  final String? sub;
  const _Indicador(this.label, this.valor, this.sub);
}
