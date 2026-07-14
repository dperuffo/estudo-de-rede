import 'package:flutter/material.dart';

import '../../providers/constantes_anp.dart';
import '../../providers/inteligencia_rede_provider.dart';
import '../../widgets/inteligencia_shared.dart';

// Aba 5/10 — "⚖️ Modo Comparativo". Porta ModoComparativo.tsx (362 linhas)
// — compara 2 estados OU 2 macrorregiões lado a lado (postos, cobertura,
// distribuidoras, preço médio por combustível).
class AbaComparativo extends StatefulWidget {
  final InteligenciaRedeCompleta dados;
  const AbaComparativo({super.key, required this.dados});

  @override
  State<AbaComparativo> createState() => _AbaComparativoState();
}

class _Metricas {
  final int nPostos, nMuns, nCoord, nDistrib;
  final double cobPct, mediaMun;
  final List<MapEntry<String, int>> top10Distrib;
  final Map<String, double> precos;
  const _Metricas({
    required this.nPostos,
    required this.nMuns,
    required this.nCoord,
    required this.nDistrib,
    required this.cobPct,
    required this.mediaMun,
    required this.top10Distrib,
    required this.precos,
  });
}

const _corA = Color(0xFF0D47A1);
const _corB = Color(0xFFB71C1C);

class _AbaComparativoState extends State<AbaComparativo> {
  String _modo = 'estados'; // estados | regioes
  late String _ladoA;
  late String _ladoB;

  List<String> get _ufsDisponiveis => widget.dados.ufsDisponiveis;
  List<String> get _regioesDisp => regioesBrasil.keys.toList()..sort();

  @override
  void initState() {
    super.initState();
    _ladoA = _ufsDisponiveis.isNotEmpty ? _ufsDisponiveis[0] : '';
    _ladoB = _ufsDisponiveis.length > 1 ? _ufsDisponiveis[1] : _ladoA;
  }

  void _trocarModo(String novo) {
    setState(() {
      _modo = novo;
      if (novo == 'estados') {
        _ladoA = _ufsDisponiveis.isNotEmpty ? _ufsDisponiveis[0] : '';
        _ladoB = _ufsDisponiveis.length > 1 ? _ufsDisponiveis[1] : _ladoA;
      } else {
        _ladoA = _regioesDisp[0];
        _ladoB = _regioesDisp[1];
      }
    });
  }

  _Metricas _calcularMetricas(List<String> ufs) {
    final d = widget.dados;
    final nPostos = ufs.fold<int>(0, (s, uf) => s + (d.postosPorUf[uf] ?? 0));
    final nMuns = ufs.fold<int>(0, (s, uf) => s + (d.municipiosPorUf[uf] ?? 0));
    final nCoord = ufs.fold<int>(0, (s, uf) => s + (d.coordPorUf[uf] ?? 0));
    final totalMunsRef = ufs.fold<int>(0, (s, uf) => s + (totalMunicipiosUf[uf] ?? 0));
    final cobPct = totalMunsRef > 0 ? ((nMuns / totalMunsRef) * 1000).round() / 10 : 0.0;
    final mediaMun = nMuns > 0 ? ((nPostos / nMuns) * 10).round() / 10 : 0.0;

    final distribMap = <String, int>{};
    for (final dist in d.distribuidorasPorUf) {
      if (!ufs.contains(dist.uf)) continue;
      distribMap[dist.distribuidora] = (distribMap[dist.distribuidora] ?? 0) + dist.total;
    }
    final top10Distrib = distribMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final soma = <String, double>{};
    final qtd = <String, double>{};
    for (final p in d.precosPorUf) {
      if (!ufs.contains(p.uf)) continue;
      soma[p.combustivel] = (soma[p.combustivel] ?? 0) + p.precoMedio * p.qtdPostos;
      qtd[p.combustivel] = (qtd[p.combustivel] ?? 0) + p.qtdPostos;
    }
    final precos = <String, double>{
      for (final c in soma.keys) c: (qtd[c] ?? 0) > 0 ? soma[c]! / qtd[c]! : 0,
    };

    return _Metricas(
      nPostos: nPostos,
      nMuns: nMuns,
      nCoord: nCoord,
      nDistrib: distribMap.length,
      cobPct: cobPct,
      mediaMun: mediaMun,
      top10Distrib: top10Distrib.take(10).toList(),
      precos: precos,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_ufsDisponiveis.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Sem UFs com postos cadastrados ainda.', style: TextStyle(color: Colors.grey))));
    }
    final ufsA = _modo == 'estados' ? [_ladoA] : (regioesBrasil[_ladoA] ?? []);
    final ufsB = _modo == 'estados' ? [_ladoB] : (regioesBrasil[_ladoB] ?? []);
    final labelA = _modo == 'estados' ? nomeUf(_ladoA) : _ladoA;
    final labelB = _modo == 'estados' ? nomeUf(_ladoB) : _ladoB;
    final metricasA = _calcularMetricas(ufsA);
    final metricasB = _calcularMetricas(ufsB);

    final combustiveisComuns = {...metricasA.precos.keys, ...metricasB.precos.keys}.toList()..sort();
    final melhorA = metricasA.precos.entries.isEmpty ? null : (metricasA.precos.entries.toList()..sort((a, b) => a.value.compareTo(b.value))).first;
    final melhorB = metricasB.precos.entries.isEmpty ? null : (metricasB.precos.entries.toList()..sort((a, b) => a.value.compareTo(b.value))).first;

    final linhasKpi = [
      ('Postos GF', metricasA.nPostos.toDouble(), metricasB.nPostos.toDouble(), 'int'),
      ('Municípios GF', metricasA.nMuns.toDouble(), metricasB.nMuns.toDouble(), 'int'),
      ('Cobertura (%)', metricasA.cobPct, metricasB.cobPct, 'pct'),
      ('Distribuidoras', metricasA.nDistrib.toDouble(), metricasB.nDistrib.toDouble(), 'int'),
      ('Com coordenadas', metricasA.nCoord.toDouble(), metricasB.nCoord.toDouble(), 'int'),
      ('Média GF/Município', metricasA.mediaMun, metricasB.mediaMun, 'dec'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Comparar dois estados ou regiões', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text('Postos, cobertura, distribuidoras e preço médio por combustível, lado a lado.', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Comparar por: ', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                ChoiceChip(label: const Text('🗺️ Estados', style: TextStyle(fontSize: 11)), selected: _modo == 'estados', onSelected: (_) => _trocarModo('estados')),
                const SizedBox(width: 6),
                ChoiceChip(label: const Text('🌎 Regiões', style: TextStyle(fontSize: 11)), selected: _modo == 'regioes', onSelected: (_) => _trocarModo('regioes')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _seletorLado('Lado A', _ladoA, (v) => setState(() => _ladoA = v))),
                const SizedBox(width: 8),
                Expanded(child: _seletorLado('Lado B', _ladoB, (v) => setState(() => _ladoB = v))),
              ]),
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _cardResumo(_corA, labelA, metricasA, melhorA)),
                const SizedBox(width: 8),
                Expanded(child: _cardResumo(_corB, labelB, metricasB, melhorB)),
              ]),
              const SizedBox(height: 16),
              TabelaSimples(
                colunas: const ['Métrica', 'A', 'B'],
                linhas: linhasKpi
                    .map((l) => [
                          l.$1,
                          l.$4 == 'pct' ? '${l.$2.toStringAsFixed(1)}%' : l.$4 == 'dec' ? l.$2.toStringAsFixed(1) : l.$2.toInt().toString(),
                          l.$4 == 'pct' ? '${l.$3.toStringAsFixed(1)}%' : l.$4 == 'dec' ? l.$3.toStringAsFixed(1) : l.$3.toInt().toString(),
                        ])
                    .toList(),
              ),
              if (combustiveisComuns.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Preço médio por combustível', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                ...combustiveisComuns.where((c) => metricasA.precos.containsKey(c) && metricasB.precos.containsKey(c)).map((c) {
                  final pa = metricasA.precos[c]!;
                  final pb = metricasB.precos[c]!;
                  final maxV = pa > pb ? pa : pb;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        _barraComparativa(pa, maxV, _corA, formatarMoeda(pa)),
                        _barraComparativa(pb, maxV, _corB, formatarMoeda(pb)),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _distribuidoras('Top 10 ($labelA)', metricasA.top10Distrib, _corA)),
                const SizedBox(width: 8),
                Expanded(child: _distribuidoras('Top 10 ($labelB)', metricasB.top10Distrib, _corB)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _seletorLado(String label, String valor, ValueChanged<String> onChanged) {
    final opcoes = _modo == 'estados' ? _ufsDisponiveis : _regioesDisp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        DropdownButton<String>(
          value: valor,
          isExpanded: true,
          isDense: true,
          items: opcoes.map((v) => DropdownMenuItem(value: v, child: Text(_modo == 'estados' ? nomeUf(v) : v, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (v) => v != null ? onChanged(v) : null,
        ),
      ],
    );
  }

  Widget _cardResumo(Color cor, String label, _Metricas m, MapEntry<String, double>? melhor) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: cor, width: 1.5), borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cor)),
          const SizedBox(height: 6),
          Text('${m.nPostos} postos GF', style: const TextStyle(fontSize: 11)),
          Text('${m.nMuns} municípios (${m.cobPct.toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 11)),
          Text('${m.nDistrib} distribuidoras', style: const TextStyle(fontSize: 11)),
          Text('${m.mediaMun.toStringAsFixed(1)} postos/município', style: const TextStyle(fontSize: 11)),
          if (melhor != null) Text('Mais barato: ${melhor.key} a ${formatarMoeda(melhor.value)}', style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _barraComparativa(double valor, double maxV, Color cor, String texto) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(children: [
        Expanded(
          child: Container(
            height: 12,
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(3)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: maxV > 0 ? (valor / maxV).clamp(0.02, 1.0) : 0.02,
              child: Container(decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(3))),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(width: 60, child: Text(texto, style: TextStyle(fontSize: 10, color: Colors.grey.shade600))),
      ]),
    );
  }

  Widget _distribuidoras(String titulo, List<MapEntry<String, int>> dados, Color cor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        if (dados.isEmpty)
          Text('Sem distribuidora cadastrada.', style: TextStyle(fontSize: 11, color: Colors.grey.shade400))
        else
          BarraHorizontal(dados: dados.map((e) => BarraHorizontalItem(label: e.key, valor: e.value.toDouble(), cor: cor, texto: '${e.value}')).toList()),
      ],
    );
  }
}
