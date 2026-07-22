import 'package:flutter/material.dart';

import '../../providers/inteligencia_rede_provider.dart';
import '../../widgets/inteligencia_shared.dart';

// Aba 11/11 — "💳 Meios de Pagamento". Pedido do Daniel: "Criar um painel
// de preços médios com os preços praticados nos abastecimentos nos
// diversos meios de pagamento. Variações entre os meios de pagamentos,
// variações por Estado e por Região, indicadores de desempenho de meios de
// pagamento. Onde é mais vantajoso e com qual meio de pagamento... inserir
// os indicadores de volumes por combustível". Porta fiel de
// PrecosPorMeioPagamento.tsx (web) — mesma agregação client-side em cima
// do bruto granular (provedor+uf+regiao+combustivel) da RPC
// preco_medio_por_meio_pagamento.
const _corA = Color(0xFF0D47A1);

class AgregadoMeioPagamento {
  final String chave;
  final double litros;
  final double valor;
  final int qtd;
  double get precoMedio => litros > 0 ? valor / litros : 0;
  AgregadoMeioPagamento({required this.chave, required this.litros, required this.valor, required this.qtd});
}

class RankingGeo {
  final String local;
  final AgregadoMeioPagamento melhor;
  final AgregadoMeioPagamento pior;
  final double economiaPct;
  final int qtdMeios;
  const RankingGeo({required this.local, required this.melhor, required this.pior, required this.economiaPct, required this.qtdMeios});
}

List<AgregadoMeioPagamento> _agregarPor(List<ItemPrecoMeioPagamento> itens, String? Function(ItemPrecoMeioPagamento) chaveFn) {
  final mapa = <String, AgregadoMeioPagamento>{};
  for (final i in itens) {
    final chave = chaveFn(i);
    if (chave == null) continue;
    final atual = mapa[chave];
    mapa[chave] = AgregadoMeioPagamento(
      chave: chave,
      litros: (atual?.litros ?? 0) + i.litrosTotal,
      valor: (atual?.valor ?? 0) + i.valorTotal,
      qtd: (atual?.qtd ?? 0) + i.qtd,
    );
  }
  return mapa.values.toList();
}

class AbaMeiosPagamento extends StatefulWidget {
  final InteligenciaRedeCompleta dados;
  const AbaMeiosPagamento({super.key, required this.dados});

  @override
  State<AbaMeiosPagamento> createState() => _AbaMeiosPagamentoState();
}

class _AbaMeiosPagamentoState extends State<AbaMeiosPagamento> {
  String _modoGeo = 'estado'; // estado | regiao
  String _combustivelFiltro = '__todos__';

  @override
  Widget build(BuildContext context) {
    final dados = widget.dados.precosPorMeioPagamento;

    if (dados.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nenhum abastecimento com meio de pagamento identificado ainda.', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final litrosTotal = dados.fold<double>(0, (s, d) => s + d.litrosTotal);
    final valorTotal = dados.fold<double>(0, (s, d) => s + d.valorTotal);
    final qtdTotal = dados.fold<int>(0, (s, d) => s + d.qtd);

    final porProvedor = _agregarPor(dados, (i) => i.provedor)..sort((a, b) => a.precoMedio.compareTo(b.precoMedio));
    final porCombustivel = _agregarPor(dados, (i) => i.combustivel)..sort((a, b) => b.litros.compareTo(a.litros));
    final maisVantajoso = porProvedor.isNotEmpty ? porProvedor.first : null;
    final menosVantajoso = porProvedor.isNotEmpty ? porProvedor.last : null;

    final combustiveisDisponiveis = dados.map((d) => d.combustivel).toSet().toList()..sort();
    final provedoresDisponiveis = dados.map((d) => d.provedor).toSet().toList()..sort();

    // Cruzamento combustível × provedor.
    final cruzamento = <String, Map<String, AgregadoMeioPagamento>>{};
    for (final combustivel in combustiveisDisponiveis) {
      final porProv = _agregarPor(dados.where((d) => d.combustivel == combustivel).toList(), (i) => i.provedor);
      cruzamento[combustivel] = {for (final p in porProv) p.chave: p};
    }

    // Onde é mais vantajoso, filtrado por combustível.
    final itensGeoFiltrados = _combustivelFiltro == '__todos__' ? dados : dados.where((d) => d.combustivel == _combustivelFiltro).toList();
    String? chaveGeo(ItemPrecoMeioPagamento i) => _modoGeo == 'estado' ? i.uf : i.regiao;
    final locais = itensGeoFiltrados.map(chaveGeo).whereType<String>().toSet().toList();
    final ranking = <RankingGeo>[];
    for (final local in locais) {
      final porProv = _agregarPor(itensGeoFiltrados.where((i) => chaveGeo(i) == local).toList(), (i) => i.provedor)
        ..sort((a, b) => a.precoMedio.compareTo(b.precoMedio));
      if (porProv.isEmpty) continue;
      final melhor = porProv.first;
      final pior = porProv.last;
      final economiaPct = pior.precoMedio > 0 ? ((pior.precoMedio - melhor.precoMedio) / pior.precoMedio) * 100 : 0.0;
      ranking.add(RankingGeo(local: local, melhor: melhor, pior: pior, economiaPct: economiaPct, qtdMeios: porProv.length));
    }
    ranking.sort((a, b) => b.economiaPct.compareTo(a.economiaPct));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 2.2,
            children: [
              CartaoIndicador(label: 'Volume total', valor: '${formatarInt(litrosTotal.round())} L', mini: true),
              CartaoIndicador(label: 'Valor total', valor: formatarMoeda(valorTotal, casas: 2), mini: true),
              CartaoIndicador(label: 'Abastecimentos', valor: formatarInt(qtdTotal), mini: true),
              if (maisVantajoso != null)
                CartaoIndicador(
                  label: 'Meio mais vantajoso',
                  valor: maisVantajoso.chave,
                  sub: '${formatarMoeda(maisVantajoso.precoMedio)}/L',
                  mini: true,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⛽ Volume por combustível', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(
                    'Litros transacionados por tipo de combustível — o preço médio de cada meio de pagamento pode variar conforme o mix de combustível.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 10),
                  BarraHorizontal(
                    dados: porCombustivel
                        .map((c) => BarraHorizontalItem(label: c.chave, valor: c.litros, cor: _corA, texto: '${(c.litros / 1000).toStringAsFixed(1)}k L'))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💳 Preço médio por meio de pagamento', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(
                    'Média ponderada por litro (todos os combustíveis), do mais em conta ao mais caro.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 10),
                  BarraHorizontal(
                    dados: porProvedor
                        .map((p) => BarraHorizontalItem(
                              label: p.chave,
                              valor: p.precoMedio,
                              cor: p.chave == maisVantajoso?.chave
                                  ? const Color(0xFF2E7D32)
                                  : (p.chave == menosVantajoso?.chave ? const Color(0xFFB71C1C) : _corA),
                              texto: formatarMoeda(p.precoMedio),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  TabelaSimples(
                    colunas: const ['Meio', 'Volume', 'Abast.'],
                    linhas: porProvedor.map((p) => [p.chave, '${(p.litros / 1000).toStringAsFixed(1)}k L', formatarInt(p.qtd)]).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Preço médio por combustível × meio de pagamento', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(
                    'Variação de preço entre os meios de pagamento, separado por tipo de combustível.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 10),
                  TabelaSimples(
                    colunas: ['Combustível', ...provedoresDisponiveis],
                    flexColunas: [2, ...List.filled(provedoresDisponiveis.length, 1)],
                    linhas: combustiveisDisponiveis.map((c) {
                      final linha = cruzamento[c] ?? {};
                      return [
                        c,
                        ...provedoresDisponiveis.map((p) => linha[p] != null ? formatarMoeda(linha[p]!.precoMedio) : '—'),
                      ];
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Onde é mais vantajoso e com qual meio de pagamento', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(
                    'Por ${_modoGeo == 'estado' ? 'estado' : 'região'}, o meio mais barato vs. o mais caro (para o combustível selecionado).',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    const Text('Ver por: ', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    ChoiceChip(
                      label: const Text('🗺️ Estados', style: TextStyle(fontSize: 11)),
                      selected: _modoGeo == 'estado',
                      onSelected: (_) => setState(() => _modoGeo = 'estado'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('🌎 Regiões', style: TextStyle(fontSize: 11)),
                      selected: _modoGeo == 'regiao',
                      onSelected: (_) => setState(() => _modoGeo = 'regiao'),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  DropdownButton<String>(
                    value: _combustivelFiltro,
                    isExpanded: true,
                    isDense: true,
                    items: [
                      const DropdownMenuItem(value: '__todos__', child: Text('Todos os combustíveis', style: TextStyle(fontSize: 12))),
                      ...combustiveisDisponiveis.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))),
                    ],
                    onChanged: (v) => v != null ? setState(() => _combustivelFiltro = v) : null,
                  ),
                  const SizedBox(height: 10),
                  if (ranking.isNotEmpty)
                    TabelaSimples(
                      colunas: [_modoGeo == 'estado' ? 'UF' : 'Região', 'Melhor', 'Preço', 'Pior', 'Preço', 'Economia'],
                      linhas: ranking
                          .map((r) => [
                                r.local,
                                r.melhor.chave,
                                formatarMoeda(r.melhor.precoMedio),
                                r.qtdMeios > 1 ? r.pior.chave : '—',
                                r.qtdMeios > 1 ? formatarMoeda(r.pior.precoMedio) : '—',
                                r.qtdMeios > 1 ? '${r.economiaPct.toStringAsFixed(1)}%' : 'só 1 meio',
                              ])
                          .toList(),
                    )
                  else
                    Text('Sem dados suficientes pra esse recorte.', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
