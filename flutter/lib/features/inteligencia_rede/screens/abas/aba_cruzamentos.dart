import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../providers/inteligencia_rede_provider.dart';
import '../../widgets/inteligencia_shared.dart';
import '../../widgets/mapa_circulos.dart';

// Aba 7/10 — "🔀 Cruzamentos Avançados". Porta CruzamentosAvancados.tsx
// (616 linhas, o maior componente da web) — 4 sub-abas: Regiões
// caras/baratas, Clusters de oportunidade, GF vs Concorrência, Frota Real.
class AbaCruzamentos extends StatefulWidget {
  final InteligenciaRedeCompleta dados;
  const AbaCruzamentos({super.key, required this.dados});

  @override
  State<AbaCruzamentos> createState() => _AbaCruzamentosState();
}

class _AbaCruzamentosState extends State<AbaCruzamentos> {
  int _subAba = 0;
  static const _titulos = ['🗺️ Regiões', '🎯 Clusters', '⚖️ GF vs Anp', '🚛 Frota Real'];

  @override
  Widget build(BuildContext context) {
    final combustiveis = widget.dados.precosPorUf.map((p) => p.combustivel).toSet().toList()..sort();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: SeletorChips<int>(
            opcoes: List.generate(_titulos.length, (i) => i),
            selecionado: _subAba,
            rotulo: (i) => _titulos[i],
            onSelecionar: (i) => setState(() => _subAba = i),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _subAba,
            sizing: StackFit.expand,
            children: [
              _RegioesCarasBaratas(dados: widget.dados, combustiveis: combustiveis),
              _ClustersOportunidade(dados: widget.dados, combustiveis: combustiveis),
              _GfVsConcorrencia(dados: widget.dados, combustiveis: combustiveis),
              _FrotaReal(dados: widget.dados),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Sub-aba 1: Regiões caras vs baratas
// ---------------------------------------------------------------------
class _RegioesCarasBaratas extends StatefulWidget {
  final InteligenciaRedeCompleta dados;
  final List<String> combustiveis;
  const _RegioesCarasBaratas({required this.dados, required this.combustiveis});
  @override
  State<_RegioesCarasBaratas> createState() => _RegioesCarasBaratasState();
}

class _RegioesCarasBaratasState extends State<_RegioesCarasBaratas> {
  String? _sel;

  @override
  Widget build(BuildContext context) {
    final combustiveis = widget.combustiveis;
    final atual = (_sel != null && combustiveis.contains(_sel)) ? _sel! : (combustiveis.isNotEmpty ? combustiveis[0] : '');

    final filtrado = widget.dados.precosPorUf.where((p) => p.combustivel == atual).toList()
      ..sort((a, b) => b.precoMedio.compareTo(a.precoMedio));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _seletorCombustivel(combustiveis, atual, (v) => setState(() => _sel = v)),
          if (filtrado.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Sem preços cadastrados para esse combustível.', style: TextStyle(color: Colors.grey)))
          else
            Builder(builder: (context) {
              final precos = filtrado.map((p) => p.precoMedio).toList();
              final p25 = quantil(precos, 0.25);
              final p75 = quantil(precos, 0.75);
              final mediaGeral = media(precos);
              final linhas = filtrado
                  .map((p) => (
                        uf: p.uf,
                        precoMedio: p.precoMedio,
                        qtdPostos: p.qtdPostos,
                        categoria: p.precoMedio >= p75 ? '🔴 Caro' : (p.precoMedio <= p25 ? '🟢 Barato' : '🟡 Médio'),
                        cor: p.precoMedio >= p75 ? const Color(0xFFE53935) : (p.precoMedio <= p25 ? const Color(0xFF43A047) : const Color(0xFFF57C00)),
                      ))
                  .toList();
              final maisCara = linhas.first;
              final maisBarata = linhas.last;
              final spread = maisCara.precoMedio - maisBarata.precoMedio;
              final spreadPct = maisBarata.precoMedio != 0 ? (spread / maisBarata.precoMedio) * 100 : 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _cardDestaque('🔴 UF mais cara', maisCara.uf ?? '—', formatarMoeda(maisCara.precoMedio), '${maisCara.qtdPostos} postos', const Color(0xFFFFF3F3), const Color(0xFFE53935))),
                    const SizedBox(width: 6),
                    Expanded(child: _cardDestaque('🟢 UF mais barata', maisBarata.uf ?? '—', formatarMoeda(maisBarata.precoMedio), '${maisBarata.qtdPostos} postos', const Color(0xFFF3FFF3), const Color(0xFF43A047))),
                  ]),
                  const SizedBox(height: 6),
                  _cardDestaque('↕️ Spread entre extremos', formatarMoeda(spread), '${spreadPct.toStringAsFixed(1)}% de diferença', null, const Color(0xFFF0F4FF), const Color(0xFF1040A0)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 280,
                    child: BarChart(
                      BarChartData(
                        barTouchData: barTouchPadrao(formatarY: (v) => formatarMoeda(v)),
                        barGroups: linhas.asMap().entries.map((e) {
                          return BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: e.value.precoMedio, color: e.value.cor, width: 14, borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))]);
                        }).toList(),
                        extraLinesData: ExtraLinesData(horizontalLines: [
                          HorizontalLine(y: mediaGeral, color: const Color(0xFF1040A0), strokeWidth: 1.5, dashArray: [4, 4]),
                        ]),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36, getTitlesWidget: (v, _) => Text(v.toStringAsFixed(2), style: const TextStyle(fontSize: 9)))),
                          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= linhas.length) return const SizedBox.shrink();
                            return Text(linhas[i].uf ?? '', style: const TextStyle(fontSize: 9));
                          })),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: const FlGridData(drawVerticalLine: false),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                  ),
                  Text('Linha tracejada = média geral (${formatarMoeda(mediaGeral)})', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                  const SizedBox(height: 12),
                  TabelaSimples(
                    colunas: const ['UF', 'Categoria', 'Preço médio', 'Postos'],
                    linhas: linhas.map((l) => [l.uf ?? '—', l.categoria, formatarMoeda(l.precoMedio, casas: 4), '${l.qtdPostos}']).toList(),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Sub-aba 2: Clusters de oportunidade
// ---------------------------------------------------------------------
const _coresCluster = {
  '🔴 Caro (>+5%)': Color(0xFFE53935),
  '🟡 Acima da média (+2% a +5%)': Color(0xFFF57C00),
  '🟢 Abaixo da média (-2% a +2%)': Color(0xFF66BB6A),
  '🟢 Barato (<-2%)': Color(0xFF1B5E20),
};

String _classificarCluster(double delta) {
  if (delta > 5) return '🔴 Caro (>+5%)';
  if (delta > 2) return '🟡 Acima da média (+2% a +5%)';
  if (delta > -2) return '🟢 Abaixo da média (-2% a +2%)';
  return '🟢 Barato (<-2%)';
}

class _ClustersOportunidade extends StatefulWidget {
  final InteligenciaRedeCompleta dados;
  final List<String> combustiveis;
  const _ClustersOportunidade({required this.dados, required this.combustiveis});
  @override
  State<_ClustersOportunidade> createState() => _ClustersOportunidadeState();
}

class _ClustersOportunidadeState extends State<_ClustersOportunidade> {
  String? _sel;

  @override
  Widget build(BuildContext context) {
    final combustiveis = widget.combustiveis;
    final atual = (_sel != null && combustiveis.contains(_sel)) ? _sel! : (combustiveis.isNotEmpty ? combustiveis[0] : '');

    final mapa = <String, ({String uf, String municipio, Set<String> postos, double soma, int qtd})>{};
    for (final r in widget.dados.historicoDetalhado) {
      if (r.combustivel != atual || r.uf == null || r.municipio == null) continue;
      final chave = '${r.uf}__${r.municipio}';
      final at = mapa[chave] ?? (uf: r.uf!, municipio: r.municipio!, postos: <String>{}, soma: 0.0, qtd: 0);
      at.postos.add(r.cnpj);
      mapa[chave] = (uf: at.uf, municipio: at.municipio, postos: at.postos, soma: at.soma + r.preco, qtd: at.qtd + 1);
    }
    final linhasBase = mapa.values.map((v) => (uf: v.uf, municipio: v.municipio, precoMedio: v.soma / v.qtd, postos: v.postos.length)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _seletorCombustivel(combustiveis, atual, (v) => setState(() => _sel = v)),
          Text('Municípios agrupados por faixa de preço GF. 🟢 preço abaixo da média nacional. 🔴 preço acima da média.', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          if (linhasBase.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Sem dados de município para esse combustível.', style: TextStyle(color: Colors.grey)))
          else
            Builder(builder: (context) {
              final mediaNac = media(linhasBase.map((l) => l.precoMedio).toList());
              final linhas = linhasBase.map((l) {
                final deltaVsMedia = mediaNac != 0 ? ((l.precoMedio - mediaNac) / mediaNac) * 100 : 0.0;
                return (uf: l.uf, municipio: l.municipio, precoMedio: l.precoMedio, postos: l.postos, deltaVsMedia: deltaVsMedia, cluster: _classificarCluster(deltaVsMedia));
              }).toList();

              final contagemCluster = <String, int>{};
              for (final l in linhas) {
                contagemCluster[l.cluster] = (contagemCluster[l.cluster] ?? 0) + l.postos;
              }
              final ordenadoPorDelta = [...linhas]..sort((a, b) => a.deltaVsMedia.compareTo(b.deltaVsMedia));
              final top15 = ordenadoPorDelta.take(15).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Distribuição por cluster', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 220,
                    child: PieChart(PieChartData(
                      sectionsSpace: 1,
                      centerSpaceRadius: 40,
                      sections: contagemCluster.entries.map((e) {
                        return PieChartSectionData(
                          value: e.value <= 0 ? 0.001 : e.value.toDouble(),
                          title: e.key.split(' ').first,
                          color: _coresCluster[e.key] ?? Colors.grey,
                          radius: 75,
                          titleStyle: const TextStyle(fontSize: 14, color: Colors.white),
                        );
                      }).toList(),
                    )),
                  ),
                  const SizedBox(height: 12),
                  Text('Top 15 municípios mais baratos', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  BarraHorizontal(
                    dados: top15
                        .map((m) => BarraHorizontalItem(
                              label: '${truncarTexto(m.municipio, 18)} (${m.uf})',
                              valor: m.deltaVsMedia.abs(),
                              cor: m.deltaVsMedia < 0 ? const Color(0xFF43A047) : const Color(0xFFF57C00),
                              texto: '${m.deltaVsMedia >= 0 ? "+" : ""}${m.deltaVsMedia.toStringAsFixed(1)}%',
                            ))
                        .toList(),
                    eixoX: 'Δ% vs média nacional',
                  ),
                  const SizedBox(height: 16),
                  Text('📋 Tabela completa de municípios', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  TabelaSimples(
                    colunas: const ['Município', 'UF', 'Preço médio', 'Δ% vs média', 'Postos'],
                    flexColunas: const [3, 1, 2, 2, 1],
                    maxHeight: 400,
                    linhas: ordenadoPorDelta
                        .map((m) => [m.municipio, m.uf, formatarMoeda(m.precoMedio, casas: 4), '${m.deltaVsMedia >= 0 ? "+" : ""}${m.deltaVsMedia.toStringAsFixed(2)}%', '${m.postos}'])
                        .toList(),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Sub-aba 3: GF vs Concorrência
// ---------------------------------------------------------------------
class _GfVsConcorrencia extends StatefulWidget {
  final InteligenciaRedeCompleta dados;
  final List<String> combustiveis;
  const _GfVsConcorrencia({required this.dados, required this.combustiveis});
  @override
  State<_GfVsConcorrencia> createState() => _GfVsConcorrenciaState();
}

class _GfVsConcorrenciaState extends State<_GfVsConcorrencia> {
  String? _sel;

  @override
  Widget build(BuildContext context) {
    final combustiveis = widget.combustiveis;
    final atual = (_sel != null && combustiveis.contains(_sel)) ? _sel! : (combustiveis.isNotEmpty ? combustiveis[0] : '');

    final mapa = <String, ({double somaGf, double somaAnp, int n, String nivel})>{};
    for (final dv in widget.dados.desvioAnp) {
      if (dv.combustivel != atual || dv.uf == null || dv.precoAnp == null) continue;
      final at = mapa[dv.uf!] ?? (somaGf: 0.0, somaAnp: 0.0, n: 0, nivel: dv.nivelAnp ?? '—');
      mapa[dv.uf!] = (somaGf: at.somaGf + dv.precoGf, somaAnp: at.somaAnp + dv.precoAnp!, n: at.n + 1, nivel: at.nivel);
    }
    final comp = mapa.entries.map((e) {
      final gfMed = e.value.somaGf / e.value.n;
      final anpMed = e.value.somaAnp / e.value.n;
      final deltaAbs = gfMed - anpMed;
      final deltaPct = anpMed != 0 ? (deltaAbs / anpMed) * 100 : 0.0;
      return (uf: e.key, gfMed: gfMed, anpMed: anpMed, deltaAbs: deltaAbs, deltaPct: deltaPct, nivelAnp: e.value.nivel, postos: e.value.n);
    }).toList()
      ..sort((a, b) => b.deltaPct.compareTo(a.deltaPct));

    final nCaros = comp.where((c) => c.deltaPct > 5).length;
    final nBaratos = comp.where((c) => c.deltaPct < -2).length;
    final nOk = comp.length - nCaros - nBaratos;
    final deltaMedio = comp.isNotEmpty ? comp.fold<double>(0, (s, c) => s + c.deltaPct) / comp.length : 0.0;
    final alertas = comp.where((c) => c.deltaPct > 5).toList()..sort((a, b) => b.deltaPct.compareTo(a.deltaPct));
    final oportunidades = comp.where((c) => c.deltaPct < -2).toList()..sort((a, b) => a.deltaPct.compareTo(b.deltaPct));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _seletorCombustivel(combustiveis, atual, (v) => setState(() => _sel = v)),
          if (comp.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Sem referência ANP resolvida para esse combustível.', style: TextStyle(color: Colors.grey)))
          else ...[
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.7,
              children: [
                CartaoIndicador(label: '🔴 UFs caras (>+5%)', valor: formatarInt(nCaros), mini: true),
                CartaoIndicador(label: '🟢 UFs baratas (<-2%)', valor: formatarInt(nBaratos), mini: true),
                CartaoIndicador(label: '🟡 Faixa competitiva', valor: formatarInt(nOk), mini: true),
                CartaoIndicador(label: '📊 Delta médio', valor: '${deltaMedio >= 0 ? "+" : ""}${deltaMedio.toStringAsFixed(1)}%', mini: true),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 280,
              child: BarChart(
                BarChartData(
                  barTouchData: barTouchPadrao(formatarY: (v) => '${v >= 0 ? "+" : ""}${v.toStringAsFixed(1)}%'),
                  barGroups: comp.asMap().entries.map((e) {
                    final cor = e.value.deltaPct > 5 ? const Color(0xFFE53935) : (e.value.deltaPct > 0 ? const Color(0xFFF57C00) : const Color(0xFF43A047));
                    return BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: e.value.deltaPct, color: cor, width: 14, borderRadius: const BorderRadius.vertical(top: Radius.circular(3)))]);
                  }).toList(),
                  extraLinesData: ExtraLinesData(horizontalLines: [HorizontalLine(y: 0, color: const Color(0xFF1040A0), strokeWidth: 1.5)]),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36, getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: const TextStyle(fontSize: 9)))),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= comp.length) return const SizedBox.shrink();
                      return Text(comp[i].uf, style: const TextStyle(fontSize: 9));
                    })),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            Text('Zona competitiva: -2% a +5% vs ANP.', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            const SizedBox(height: 12),
            if (alertas.isNotEmpty) ...[
              Text('⚠️ Atenção', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
              const SizedBox(height: 6),
              ...alertas.map((a) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), border: const Border(left: BorderSide(color: Color(0xFFE53935), width: 4)), borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      '🔴 ${a.uf} — GF ${formatarMoeda(a.gfMed)} vs ANP ${formatarMoeda(a.anpMed)} (${a.deltaPct >= 0 ? "+" : ""}${a.deltaPct.toStringAsFixed(1)}%) · Custo extra: ${formatarMoeda((a.deltaAbs).abs() * 100, casas: 2)}/100L · ${a.postos} postos',
                      style: const TextStyle(fontSize: 12),
                    ),
                  )),
              const SizedBox(height: 8),
            ],
            if (oportunidades.isNotEmpty) ...[
              Text('💚 Destaque', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
              const SizedBox(height: 6),
              ...oportunidades.map((o) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), border: const Border(left: BorderSide(color: Color(0xFF43A047), width: 4)), borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      '💚 ${o.uf} — GF ${formatarMoeda(o.gfMed)} vs ANP ${formatarMoeda(o.anpMed)} (${o.deltaPct.toStringAsFixed(1)}%) · Saving: ${formatarMoeda((o.deltaAbs).abs() * 100, casas: 2)}/100L · ${o.postos} postos',
                      style: const TextStyle(fontSize: 12),
                    ),
                  )),
              const SizedBox(height: 8),
            ],
            TabelaSimples(
              colunas: const ['UF', 'GF médio', 'ANP ref.', 'Delta %', 'Postos'],
              linhas: comp.map((c) => [c.uf, formatarMoeda(c.gfMed, casas: 4), formatarMoeda(c.anpMed, casas: 4), '${c.deltaPct >= 0 ? "+" : ""}${c.deltaPct.toStringAsFixed(2)}%', '${c.postos}']).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Sub-aba 4: Frota Real
// ---------------------------------------------------------------------
class _FrotaReal extends StatelessWidget {
  final InteligenciaRedeCompleta dados;
  const _FrotaReal({required this.dados});

  @override
  Widget build(BuildContext context) {
    final postosVisitados = dados.postosVisitados;
    if (postosVisitados.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Ainda não há abastecimentos com coordenada do posto — conecte a integração PróFrotas.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
        ),
      );
    }

    final totalVisitas = postosVisitados.fold<int>(0, (s, p) => s + p.visitas);
    final ufsCobertas = postosVisitados.map((p) => p.uf).where((v) => v != null).toSet().length;
    final precoMedioPago = totalVisitas > 0 ? postosVisitados.fold<double>(0, (s, p) => s + p.precoMedio * p.visitas) / totalVisitas : 0.0;

    final precos = postosVisitados.map((p) => p.precoMedio).toList();
    final min = precos.isEmpty ? 0.0 : precos.reduce((a, b) => a < b ? a : b);
    final max = precos.isEmpty ? 0.0 : precos.reduce((a, b) => a > b ? a : b);
    final faixa = (max - min) > 0.01 ? (max - min) : 0.01;

    final pontosMapa = postosVisitados.where((p) => p.lat != null && p.lon != null).map((p) {
      final norm = (p.precoMedio - min) / faixa;
      final cor = norm < 0.33 ? const Color(0xFF43A047) : (norm < 0.66 ? const Color(0xFFF57C00) : const Color(0xFFE53935));
      return PontoCirculo(
        lat: p.lat!,
        lon: p.lon!,
        cor: cor,
        raio: (p.visitas.clamp(0, 50) / 50) * 20 + 6,
        tooltip: '${p.razaoSocial ?? "Posto"}\nVisitas: ${p.visitas}\nPreço médio: ${formatarMoeda(p.precoMedio)}',
      );
    }).toList();

    final ranking = [...postosVisitados]..sort((a, b) => b.visitas.compareTo(a.visitas));
    final top15Ranking = ranking.take(15).toList();

    final porUfMapa = <String, ({double soma, int visitas})>{};
    for (final p in postosVisitados) {
      if (p.uf == null) continue;
      final at = porUfMapa[p.uf!] ?? (soma: 0.0, visitas: 0);
      porUfMapa[p.uf!] = (soma: at.soma + p.precoMedio * p.visitas, visitas: at.visitas + p.visitas);
    }
    final porUf = porUfMapa.entries.map((e) {
      final precoReal = e.value.visitas > 0 ? e.value.soma / e.value.visitas : 0.0;
      final anpRef = dados.dieselAnpPorUf[e.key];
      final deltaPct = anpRef != null && anpRef != 0 ? ((precoReal - anpRef) / anpRef) * 100 : null;
      return (uf: e.key, precoReal: precoReal, visitas: e.value.visitas, anpRef: anpRef, deltaPct: deltaPct);
    }).toList()
      ..sort((a, b) => b.precoReal.compareTo(a.precoReal));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.7,
            children: [
              CartaoIndicador(label: '⛽ Abastecimentos', valor: formatarInt(totalVisitas), mini: true),
              CartaoIndicador(label: '📍 Postos distintos', valor: formatarInt(postosVisitados.length), mini: true),
              CartaoIndicador(label: '🗺️ UFs cobertas', valor: formatarInt(ufsCobertas), mini: true),
              CartaoIndicador(label: '💰 Preço médio pago', valor: formatarMoeda(precoMedioPago), mini: true),
            ],
          ),
          const SizedBox(height: 12),
          Text('🌎 Mapa de calor — postos visitados pela frota', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
          Text('Tamanho = frequência de visitas. Cor = preço médio pago.', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
          const SizedBox(height: 8),
          MapaCirculos(pontos: pontosMapa, height: 380),
          const SizedBox(height: 16),
          Text('🏆 Ranking de postos mais utilizados', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          BarraHorizontal(
            dados: top15Ranking.map((p) => BarraHorizontalItem(label: truncarTexto(p.razaoSocial ?? p.cnpj, 28), valor: p.visitas.toDouble(), cor: const Color(0xFF283593), texto: formatarInt(p.visitas))).toList(),
            eixoX: 'Abastecimentos',
          ),
          const SizedBox(height: 16),
          Text('📊 Preço pago por UF (ref.: Diesel S10 ANP)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          ...porUf.map((u) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.uf, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    _barraDupla(u.precoReal, u.anpRef ?? 0, const Color(0xFFE65100), const Color(0xFF7B1FA2)),
                  ],
                ),
              )),
          const SizedBox(height: 8),
          TabelaSimples(
            colunas: const ['UF', 'Preço real', 'Abast.', 'ANP ref.', 'Δ%'],
            linhas: porUf
                .map((u) => [u.uf, formatarMoeda(u.precoReal), '${u.visitas}', u.anpRef != null ? formatarMoeda(u.anpRef!) : '—', u.deltaPct != null ? '${u.deltaPct! >= 0 ? "+" : ""}${u.deltaPct!.toStringAsFixed(1)}%' : '—'])
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _barraDupla(double a, double b, Color corA, Color corB) {
    final maxV = a > b ? a : b;
    Widget barra(double v, Color cor, String texto) => Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(children: [
            Expanded(
              child: Container(
                height: 10,
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(3)),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: maxV > 0 ? (v / maxV).clamp(0.02, 1.0) : 0.02,
                  child: Container(decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(3))),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(width: 56, child: Text(texto, style: TextStyle(fontSize: 10, color: Colors.grey.shade600))),
          ]),
        );
    return Column(children: [
      barra(a, corA, formatarMoeda(a)),
      barra(b, corB, b > 0 ? formatarMoeda(b) : '—'),
    ]);
  }
}

Widget _cardDestaque(String titulo, String valor, String linha1, String? linha2, Color bg, Color borda) {
  return Container(
    decoration: BoxDecoration(color: bg, border: Border(left: BorderSide(color: borda, width: 4)), borderRadius: BorderRadius.circular(4)),
    padding: const EdgeInsets.all(10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        Text(valor, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        Text(linha1, style: const TextStyle(fontSize: 11)),
        if (linha2 != null) Text(linha2, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
      ],
    ),
  );
}

Widget _seletorCombustivel(List<String> opcoes, String atual, ValueChanged<String> onChanged) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
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
