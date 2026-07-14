import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../providers/constantes_anp.dart';
import '../../providers/inteligencia_rede_provider.dart';
import '../../widgets/inteligencia_shared.dart';
import '../../widgets/mapa_circulos.dart';

// Aba 6/10 — "🎯 Cobertura × Demanda". Porta CoberturaDemanda.tsx +
// MapaGapCobertura.tsx — cruza demanda real da frota (abastecimentos) com
// ausência de postos GF por UF. Gap Score = demanda_norm × (1 − cobertura_norm).
class AbaCoberturaDemanda extends StatelessWidget {
  final InteligenciaRedeCompleta dados;
  const AbaCoberturaDemanda({super.key, required this.dados});

  static Color _corGap(double gap) {
    if (gap >= 0.6) return const Color(0xFFE03030);
    if (gap >= 0.35) return const Color(0xFFF5A623);
    if (gap >= 0.15) return const Color(0xFFF5C518);
    return const Color(0xFF1A7A40);
  }

  static String _prioridade(double gap) {
    if (gap >= 0.6) return '🔴 Crítico';
    if (gap >= 0.35) return '🟠 Alto';
    if (gap >= 0.15) return '🟡 Médio';
    return '🟢 Baixo';
  }

  static String _acao(double gap) {
    if (gap >= 0.6) return 'Abrir posto urgente';
    if (gap >= 0.35) return 'Avaliar nova unidade';
    if (gap >= 0.15) return 'Monitorar crescimento';
    return 'Cobertura adequada';
  }

  @override
  Widget build(BuildContext context) {
    final d = dados;
    final ufs = ufCentroides.keys.toList();
    final demandaMax = ufs.fold<int>(1, (m, uf) => (d.demandaPorUf[uf] ?? 0) > m ? (d.demandaPorUf[uf] ?? 0) : m);
    final coberturaMax = ufs.fold<int>(1, (m, uf) => (d.postosPorUf[uf] ?? 0) > m ? (d.postosPorUf[uf] ?? 0) : m);

    final linhas = ufs.map((uf) {
      final demanda = d.demandaPorUf[uf] ?? 0;
      final postosGf = d.postosPorUf[uf] ?? 0;
      final demandaNorm = demanda / demandaMax;
      final coberturaNorm = postosGf / coberturaMax;
      final gap = (demandaNorm * (1 - coberturaNorm) * 10000).round() / 10000;
      return (uf: uf, demanda: demanda, postosGf: postosGf, gap: gap);
    }).toList()
      ..sort((a, b) => b.gap.compareTo(a.gap));

    final demandaTotal = linhas.fold<int>(0, (s, l) => s + l.demanda);

    if (demandaTotal == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Ainda não há abastecimentos reais suficientes (via integração PróFrotas) para medir demanda por UF.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final nGapAlto = linhas.where((l) => l.gap >= 0.35).length;
    final ufPrioritaria = linhas.first.uf;
    final totalPostosGf = linhas.fold<int>(0, (s, l) => s + l.postosGf);
    final top15 = linhas.take(15).toList();
    final criticos = linhas.where((l) => l.gap >= 0.6).map((l) => l.uf).toList();
    final altos = linhas.where((l) => l.gap >= 0.35 && l.gap < 0.6).map((l) => l.uf).toList();
    final semGf = linhas.where((l) => l.postosGf == 0).map((l) => l.uf).toList();

    final insights = <String>[];
    if (criticos.isNotEmpty) {
      insights.add('🔴 Expansão urgente: as UFs ${criticos.take(5).join(", ")} têm alta demanda real e baixíssima cobertura GF — candidatas prioritárias para abertura imediata de novos postos.');
    }
    if (altos.isNotEmpty) {
      insights.add('🟠 Avaliação estratégica: ${altos.take(4).join(", ")} têm gap relevante — vale avaliar parceiros/franquias locais.');
    }
    if (semGf.isNotEmpty) {
      insights.add('⚠️ Sem nenhum posto GF: ${semGf.take(6).join(", ")} não têm cobertura GF cadastrada.');
    }
    if (insights.isEmpty) insights.add('✅ Cobertura equilibrada: não foram identificados gaps críticos com os dados atuais.');

    final pontosMapa = linhas.where((l) => l.demanda > 0).map((l) {
      final centro = ufCentroides[l.uf]!;
      final raio = (l.demanda / demandaMax) * 26 + 8;
      return PontoCirculo(
        lat: centro[0],
        lon: centro[1],
        cor: _corGap(l.gap),
        raio: raio,
        tooltip: '${l.uf}\nDemanda: ${l.demanda}\nPostos GF: ${l.postosGf}\nGap: ${l.gap.toStringAsFixed(3)}',
      );
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cobertura × Demanda — Expansão Estratégica da Rede', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8)),
                child: const Text(
                  '⚠️ Demanda aqui = abastecimentos reais da frota (integração PróFrotas). Não inclui rotas planejadas/sugeridas pelo otimizador.',
                  style: TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.7,
                children: [
                  CartaoIndicador(label: '⛽ Abastecimentos analisados', valor: formatarInt(demandaTotal), mini: true),
                  CartaoIndicador(label: '⚠️ UFs com gap alto/crítico', valor: formatarInt(nGapAlto), mini: true),
                  CartaoIndicador(label: '🥇 UF prioritária', valor: ufPrioritaria, mini: true),
                  CartaoIndicador(label: '⛽ Total postos GF', valor: formatarInt(totalPostosGf), mini: true),
                ],
              ),
              const SizedBox(height: 12),
              Text('🗺️ Mapa de Gaps — tamanho = demanda, cor = severidade', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 6),
              MapaCirculos(pontos: pontosMapa, height: 380, mensagemVazio: 'Sem abastecimentos reais registrados para gerar o mapa de demanda.'),
              const SizedBox(height: 16),
              Text('📊 Top 15 UFs — Prioridade de Expansão', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              SizedBox(
                height: 260,
                child: BarChart(
                  BarChartData(
                    maxY: 1.1,
                    barTouchData: barTouchPadrao(formatarY: (v) => 'Gap ${v.toStringAsFixed(3)}'),
                    barGroups: top15.asMap().entries.map((e) {
                      return BarChartGroupData(x: e.key, barRods: [
                        BarChartRodData(toY: e.value.gap, color: _corGap(e.value.gap), width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
                      ]);
                    }).toList(),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (v, _) => Text(v.toStringAsFixed(1), style: const TextStyle(fontSize: 9)))),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= top15.length) return const SizedBox.shrink();
                            return Text(top15[i].uf, style: const TextStyle(fontSize: 10));
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
              Text('🔴 Crítico ≥0,60 · 🟠 Alto ≥0,35 · 🟡 Médio ≥0,15 · 🟢 Baixo <0,15', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              const SizedBox(height: 16),
              ...insights.map((texto) => BlocoInsight(texto: texto)),
              const SizedBox(height: 8),
              TabelaSimples(
                colunas: const ['UF', 'Demanda', 'Postos', 'Gap', 'Prioridade', 'Ação'],
                flexColunas: const [1, 2, 1, 2, 2, 3],
                linhas: linhas.map((l) => [l.uf, '${l.demanda}', '${l.postosGf}', l.gap.toStringAsFixed(3), _prioridade(l.gap), _acao(l.gap)]).toList(),
                maxHeight: 420,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
