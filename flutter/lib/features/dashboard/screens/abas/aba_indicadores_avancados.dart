import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../inteligencia_rede/widgets/inteligencia_shared.dart';
import '../../../roteirizacao/providers/roteirizacao_provider.dart' show produtosPosto;
import '../../providers/indicadores_avancados_provider.dart';

final _moeda2 = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _numero = NumberFormat.decimalPattern('pt_BR');

const _coresPostos = [Color(0xFF0EA5E9), Color(0xFFF97316), Color(0xFF16A34A), Color(0xFFDB2777), Color(0xFF7C3AED)];

// Achado real (reportado pelo Daniel com print): rótulos do eixo X em
// gráficos de barra com várias categorias (placas, nomes de motoristas,
// combustíveis) ficavam colados uns nos outros — texto horizontal simples
// não sobra espaço lateral suficiente quando há 8-15 barras numa tela
// estreita de celular. Rotacionado diagonalmente (mesmo truque padrão
// usado em gráficos com muitas categorias): ocupa bem menos largura por
// rótulo, então não invade mais o rótulo vizinho.
Widget _rotuloEixoX(String texto, {double fontSize = 8}) {
  return Transform.rotate(
    angle: -0.6,
    alignment: Alignment.topRight,
    child: Text(texto, style: TextStyle(fontSize: fontSize)),
  );
}

// Achado real: número em R$ (ex. "R$ 2.000,00") quebrava em 2 linhas
// dentro do espaço reservado do eixo Y — a Text do fl_chart quebra linha
// por padrão quando não cabe na largura reservada. maxLines:1 +
// softWrap:false + overflow visible evita a quebra (o número nunca corta
// nem quebra no meio; se for muito longo só "vaza" um pouco pra fora da
// área reservada, o que é bem menos confuso que ver "R$ 2.000,0" numa
// linha e "0" sozinho na linha de baixo).
Widget _rotuloEixoY(String texto, {double fontSize = 9}) {
  return Text(texto, style: TextStyle(fontSize: fontSize), maxLines: 1, softWrap: false, overflow: TextOverflow.visible);
}

// Fase FLT-6 — 2ª aba do Dashboard ("Indicadores Avançados"): os 8 gráficos
// de src/app/(dashboard)/dashboard/page.tsx que dependem de um período
// (mês/ano) — seletor próprio desta aba (ver decisão de escopo em
// dashboard_provider.dart sobre por que Centro de Custo, na aba Visão
// Geral, NÃO compartilha este seletor).
class AbaIndicadoresAvancados extends ConsumerStatefulWidget {
  const AbaIndicadoresAvancados({super.key});
  @override
  ConsumerState<AbaIndicadoresAvancados> createState() => _AbaIndicadoresAvancadosState();
}

class _AbaIndicadoresAvancadosState extends ConsumerState<AbaIndicadoresAvancados> {
  late ({int ano, int mes}) _periodo;
  String? _combustivel; // null = todos os combustíveis

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _periodo = (ano: agora.year, mes: agora.month);
  }

  @override
  Widget build(BuildContext context) {
    final chave = (ano: _periodo.ano, mes: _periodo.mes, combustivel: _combustivel);
    final dadosAsync = ref.watch(indicadoresAvancadosProvider(chave));
    final opcoes = opcoesMes();

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(indicadoresAvancadosProvider(chave)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const Text('Indicadores avançados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Preços, consumo e rankings do período selecionado.', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Período:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 8),
                  DropdownButton<({int ano, int mes})>(
                    value: _periodo,
                    isDense: true,
                    items: opcoes
                        .map((o) => DropdownMenuItem(value: o, child: Text(rotuloMesAno(o.ano, o.mes), style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _periodo = v);
                    },
                  ),
                ],
              ),
              // Fase Dashboard-Filtro-Combustivel (19/07) — mesma ideia da
              // web: filtra os itens 2, 3, 4 e 5 por combustível (item 1
              // fica de fora, já compara todos lado a lado).
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Combustível:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 8),
                  DropdownButton<String?>(
                    value: _combustivel,
                    isDense: true,
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Todos os combustíveis', style: TextStyle(fontSize: 13))),
                      ...produtosPosto.map((p) => DropdownMenuItem<String?>(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))),
                    ],
                    onChanged: (v) => setState(() => _combustivel = v),
                  ),
                ],
              ),
            ],
          ),
          if (_combustivel != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFF0F9FF), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(fontSize: 12, color: Color(0xFF0369A1)),
                        children: [
                          const TextSpan(text: 'Indicadores 2, 3, 4 e 5 filtrados por '),
                          TextSpan(text: _combustivel, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const TextSpan(text: '. O indicador 1 já compara todos os combustíveis lado a lado.'),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _combustivel = null),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: const Text('Limpar filtro', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          dadosAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text('Não deu pra carregar os indicadores.\n$e', textAlign: TextAlign.center),
            ),
            data: (dados) {
              if (!dados.temEmpresa) {
                return _cardVazio('Selecione um cliente para ver os indicadores avançados.');
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _item1VariacaoPrecos(dados),
                  const SizedBox(height: 20),
                  _item2PrevisaoConsumo(dados),
                  const SizedBox(height: 20),
                  _item3EvolucaoPrecoMedio(dados),
                  const SizedBox(height: 20),
                  _item4EvolutivoPostos(dados),
                  const SizedBox(height: 20),
                  _item5TopPostos(dados),
                  const SizedBox(height: 20),
                  _item6RankingVeiculos(dados),
                  const SizedBox(height: 20),
                  _item7RankingMotoristas(dados),
                  const SizedBox(height: 20),
                  _item8EficienciaVeiculos(dados),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tituloItem(String texto, {String? subtitulo}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(texto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            if (subtitulo != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitulo, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
          ],
        ),
      );

  Widget _cardVazio(String texto) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text(texto, style: const TextStyle(color: Colors.grey))),
        ),
      );

  // Item 1 — Variação de preços por combustível.
  Widget _item1VariacaoPrecos(IndicadoresAvancadosDados dados) {
    final itens = dados.variacaoPrecos;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloItem('1. Variação de preços por combustível',
                subtitulo: 'Faixa de preço paga na rede, comparada à referência ANP do estado mais frequente.'),
            if (itens.isEmpty)
              const Padding(padding: EdgeInsets.all(12), child: Text('Sem abastecimentos no período.', style: TextStyle(color: Colors.grey, fontSize: 12)))
            else ...[
              SizedBox(
                height: 220,
                child: BarChart(BarChartData(
                  barTouchData: barTouchPadrao(
                    formatarY: (v) => formatarMoeda(v, casas: 3),
                    formatarX: (i) => i >= 0 && i < itens.length ? itens[i].itemNome : '',
                  ),
                  barGroups: itens.asMap().entries.map((e) {
                    final i = e.value;
                    return BarChartGroupData(x: e.key, barRods: [
                      BarChartRodData(toY: i.precoMed, color: const Color(0xFF0EA5E9), width: 10, borderRadius: const BorderRadius.vertical(top: Radius.circular(2))),
                      if (i.anpPrecoMed != null)
                        BarChartRodData(toY: i.anpPrecoMed!, color: const Color(0xFF94A3B8), width: 10, borderRadius: const BorderRadius.vertical(top: Radius.circular(2))),
                    ]);
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, _) => _rotuloEixoY(v.toStringAsFixed(2)))),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 42, getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= itens.length) return const SizedBox.shrink();
                      return Padding(padding: const EdgeInsets.only(top: 4), child: _rotuloEixoX(truncarTexto(itens[i].itemNome, 8)));
                    })),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                )),
              ),
              const SizedBox(height: 4),
              const Text('🔵 Preço pago  ·  ⚪ Referência ANP', style: TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 10),
              TabelaSimples(
                colunas: const ['Combustível', 'Qtd', 'Méd.', 'CV', 'ANP Méd.'],
                flexColunas: const [3, 1, 2, 2, 2],
                linhas: itens
                    .map((i) => [
                          truncarTexto(i.itemNome, 16),
                          '${i.qtdAbastecimentos}',
                          formatarMoeda(i.precoMed, casas: 3),
                          i.coefVariacao > 0.08 ? '⚠️ ${(i.coefVariacao * 100).toStringAsFixed(1)}%' : '${(i.coefVariacao * 100).toStringAsFixed(1)}%',
                          i.anpPrecoMed != null ? formatarMoeda(i.anpPrecoMed!, casas: 3) : '—',
                        ])
                    .toList(),
                maxHeight: 240,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Item 2 — Previsão de consumo.
  Widget _item2PrevisaoConsumo(IndicadoresAvancadosDados dados) {
    final pontos = dados.previsaoConsumo;
    final maxY = pontos.map((p) => p.litros).fold<double>(0, (a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloItem('2. Previsão de consumo — ${rotuloMesAno(dados.ano, dados.mes)}',
                subtitulo: 'Litros por dia; dias restantes projetados pelo padrão de consumo por dia da semana (últimos 90 dias).'),
            if (pontos.isEmpty)
              const Padding(padding: EdgeInsets.all(12), child: Text('Sem dados de consumo no período.', style: TextStyle(color: Colors.grey, fontSize: 12)))
            else ...[
              SizedBox(
                height: 200,
                child: BarChart(BarChartData(
                  maxY: maxY <= 0 ? 1 : maxY * 1.2,
                  barTouchData: barTouchPadrao(
                    formatarY: (v) => '${_numero.format(v.round())} L',
                    formatarX: (i) => i >= 0 && i < pontos.length ? 'Dia ${pontos[i].diaLabel}' : '',
                  ),
                  barGroups: pontos.asMap().entries.map((e) {
                    final cor = e.value.tipo == 'real' ? const Color(0xFF0EA5E9) : const Color(0xFFBAE6FD);
                    return BarChartGroupData(x: e.key, barRods: [
                      BarChartRodData(toY: e.value.litros, color: cor, width: 6),
                    ]);
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44, getTitlesWidget: (v, _) => _rotuloEixoY(_numero.format(v.round())))),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: 5, getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= pontos.length) return const SizedBox.shrink();
                      return Text(pontos[i].diaLabel, style: const TextStyle(fontSize: 8));
                    })),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                )),
              ),
              const SizedBox(height: 4),
              const Text('🔵 Realizado  ·  🔵 Projetado (claro)', style: TextStyle(fontSize: 10, color: Colors.grey)),
              if (dados.isMesAtual && dados.diaAtual < dados.diasNoMes) ...[
                const SizedBox(height: 8),
                Text(
                  'Realizado até o dia ${dados.diaAtual}: ${_numero.format(dados.totalLitrosMes.round())} L · '
                  'Projeção p/ os ${dados.diasNoMes - dados.diaAtual} dias restantes: ${_numero.format(dados.totalLitrosProjetado.round())} L · '
                  'Total estimado: ${_numero.format((dados.totalLitrosMes + dados.totalLitrosProjetado).round())} L',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // Item 3 — Evolução do preço médio por abastecimento.
  Widget _item3EvolucaoPrecoMedio(IndicadoresAvancadosDados dados) {
    final pontos = dados.precoMedio;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloItem('3. Evolução do preço médio por abastecimento (R\$/L)'),
            if (pontos.isEmpty)
              const Padding(padding: EdgeInsets.all(12), child: Text('Sem dados no período.', style: TextStyle(color: Colors.grey, fontSize: 12)))
            else
              SizedBox(
                height: 180,
                child: LineChart(LineChartData(
                  lineTouchData: lineTouchPadrao(formatarY: (v) => formatarMoeda(v, casas: 3)),
                  lineBarsData: [
                    LineChartBarData(
                      spots: pontos.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.precoMedio)).toList(),
                      isCurved: false,
                      color: const Color(0xFF0F2A4A),
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44, getTitlesWidget: (v, _) => _rotuloEixoY(v.toStringAsFixed(2)))),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: 5, getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= pontos.length) return const SizedBox.shrink();
                      return Text(pontos[i].diaLabel, style: const TextStyle(fontSize: 8));
                    })),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                )),
              ),
          ],
        ),
      ),
    );
  }

  // Item 4 — Evolutivo de volume, Top 5 postos (multi-linha).
  Widget _item4EvolutivoPostos(IndicadoresAvancadosDados dados) {
    final pontos = dados.evolutivoPostos;
    final postos = dados.postosNomes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloItem('4. Evolutivo de volume — Top 5 postos'),
            if (pontos.isEmpty || postos.isEmpty)
              const Padding(padding: EdgeInsets.all(12), child: Text('Sem abastecimentos em postos no período.', style: TextStyle(color: Colors.grey, fontSize: 12)))
            else ...[
              SizedBox(
                height: 200,
                child: LineChart(LineChartData(
                  lineTouchData: lineTouchPadrao(formatarY: (v) => '${_numero.format(v.round())} L'),
                  lineBarsData: postos.asMap().entries.map((pe) {
                    final cor = _coresPostos[pe.key % _coresPostos.length];
                    final spots = <FlSpot>[];
                    for (var i = 0; i < pontos.length; i++) {
                      final valor = pontos[i].valores[pe.value];
                      if (valor != null) spots.add(FlSpot(i.toDouble(), valor));
                    }
                    return LineChartBarData(spots: spots, isCurved: false, color: cor, barWidth: 2, dotData: const FlDotData(show: false));
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44, getTitlesWidget: (v, _) => _rotuloEixoY(_numero.format(v.round())))),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: 5, getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= pontos.length) return const SizedBox.shrink();
                      return Text(pontos[i].diaLabel, style: const TextStyle(fontSize: 8));
                    })),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                )),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: postos.asMap().entries.map((pe) {
                  final cor = _coresPostos[pe.key % _coresPostos.length];
                  return Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(truncarTexto(pe.value, 20), style: const TextStyle(fontSize: 10)),
                  ]);
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Item 5 — Top 5 postos por volume.
  Widget _item5TopPostos(IndicadoresAvancadosDados dados) {
    final top = dados.topPostos;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloItem('5. Top 5 postos — maior volume no período'),
            if (top.isEmpty)
              const Padding(padding: EdgeInsets.all(12), child: Text('Sem abastecimentos em postos no período.', style: TextStyle(color: Colors.grey, fontSize: 12)))
            else
              SizedBox(
                height: 200,
                child: BarChart(BarChartData(
                  barTouchData: barTouchPadrao(formatarY: (v) => '${_numero.format(v.round())} L'),
                  barGroups: top.asMap().entries.map((e) {
                    return BarChartGroupData(x: e.key, barRods: [
                      BarChartRodData(toY: e.value.litros, color: const Color(0xFF0EA5E9), width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
                    ]);
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, _) => _rotuloEixoY(_numero.format(v.round())))),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 46, getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= top.length) return const SizedBox.shrink();
                      return Padding(padding: const EdgeInsets.only(top: 4), child: _rotuloEixoX(truncarTexto(top[i].posto, 8)));
                    })),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                )),
              ),
          ],
        ),
      ),
    );
  }

  Widget _rankingGasto(String titulo, List<ItemRankingGasto> itens, String colunaExtra) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloItem(titulo, subtitulo: 'Top 10 no gráfico; frota completa não cabe num único painel.'),
            if (itens.isEmpty)
              const Padding(padding: EdgeInsets.all(12), child: Text('Sem abastecimentos no período.', style: TextStyle(color: Colors.grey, fontSize: 12)))
            else ...[
              SizedBox(
                height: 220,
                child: BarChart(BarChartData(
                  barTouchData: barTouchPadrao(
                    formatarY: (v) => formatarMoeda(v, casas: 2),
                    formatarX: (i) => i >= 0 && i < itens.length ? itens[i].label : '',
                  ),
                  barGroups: itens.asMap().entries.map((e) {
                    return BarChartGroupData(x: e.key, barRods: [
                      BarChartRodData(toY: e.value.gasto, color: const Color(0xFF0F2A4A), width: 14, borderRadius: const BorderRadius.vertical(top: Radius.circular(2))),
                    ]);
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 52, getTitlesWidget: (v, _) => _rotuloEixoY(formatarMoeda(v, casas: 2), fontSize: 8))),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 42, getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= itens.length) return const SizedBox.shrink();
                      return Padding(padding: const EdgeInsets.only(top: 4), child: _rotuloEixoX(truncarTexto(itens[i].label, 8)));
                    })),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                )),
              ),
              const SizedBox(height: 10),
              TabelaSimples(
                colunas: [colunaExtra, 'Qtd', 'Litros', 'Gasto'],
                flexColunas: const [3, 1, 2, 2],
                linhas: itens
                    .map((i) => [
                          i.sub != null ? '${i.label} · ${i.sub}' : i.label,
                          '${i.qtd}',
                          formatarInt(i.litros.round()),
                          formatarMoeda(i.gasto, casas: 2),
                        ])
                    .toList(),
                maxHeight: 240,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _item6RankingVeiculos(IndicadoresAvancadosDados dados) =>
      _rankingGasto('6. Ranking de veículos — maior gasto no período', dados.rankingVeiculos, 'Placa');

  Widget _item7RankingMotoristas(IndicadoresAvancadosDados dados) =>
      _rankingGasto('7. Ranking de motoristas — maior gasto no período', dados.rankingMotoristas, 'Motorista');

  // Item 8 — Eficiência real por veículo (km rodado e km/L via hodômetros
  // consecutivos reais). Tercis (q33/q66) coloram o gráfico de km/L: verde
  // (bom), laranja (médio), vermelho (ruim) — mesmos limiares da web.
  Widget _item8EficienciaVeiculos(IndicadoresAvancadosDados dados) {
    final itens = dados.eficienciaVeiculos;
    final comKmL = itens.where((i) => i.mediaKmL != null).map((i) => i.mediaKmL!).toList();
    final q33 = quantil(comKmL, 0.33);
    final q66 = quantil(comKmL, 0.66);
    Color corKmL(double v) {
      if (v >= q66) return const Color(0xFF43A047);
      if (v >= q33) return const Color(0xFFF57C00);
      return const Color(0xFFE53935);
    }

    final top15KmMedio = [...itens]..sort((a, b) => b.kmMedio.compareTo(a.kmMedio));
    final top15KmL = itens.where((i) => i.mediaKmL != null).toList()..sort((a, b) => b.mediaKmL!.compareTo(a.mediaKmL!));

    Widget miniBarChart(List<ItemEficienciaVeiculo> lista, double Function(ItemEficienciaVeiculo) valor, Color Function(ItemEficienciaVeiculo) cor, String Function(double) formatarY) {
      final top = lista.take(15).toList();
      return SizedBox(
        height: 200,
        child: BarChart(BarChartData(
          barTouchData: barTouchPadrao(formatarY: formatarY, formatarX: (i) => i >= 0 && i < top.length ? top[i].placa : ''),
          barGroups: top.asMap().entries.map((e) {
            return BarChartGroupData(x: e.key, barRods: [
              BarChartRodData(toY: valor(e.value), color: cor(e.value), width: 10, borderRadius: const BorderRadius.vertical(top: Radius.circular(2))),
            ]);
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36, getTitlesWidget: (v, _) => _rotuloEixoY(v.toStringAsFixed(0)))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36, getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= top.length) return const SizedBox.shrink();
              return Padding(padding: const EdgeInsets.only(top: 4), child: _rotuloEixoX(top[i].placa));
            })),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(drawVerticalLine: false),
          borderData: FlBorderData(show: false),
        )),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloItem('8. Eficiência real por veículo',
                subtitulo: 'KM rodado e km/L a partir de hodômetros consecutivos reais dos abastecimentos (integração PróFrotas). Sem dado de GPS/trajetória.'),
            if (itens.isEmpty)
              const Padding(padding: EdgeInsets.all(12), child: Text('Sem dados suficientes no período.', style: TextStyle(color: Colors.grey, fontSize: 12)))
            else ...[
              Text('Top 15 — KM médio por abastecimento', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 6),
              miniBarChart(top15KmMedio, (i) => i.kmMedio, (_) => const Color(0xFF2E7D32), (v) => '${v.toStringAsFixed(0)} km'),
              const SizedBox(height: 16),
              Text('Top 15 — km/L (🟢 ≥ q66 · 🟠 ≥ q33 · 🔴 abaixo)', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 6),
              miniBarChart(top15KmL, (i) => i.mediaKmL!, (i) => corKmL(i.mediaKmL!), (v) => '${v.toStringAsFixed(2)} km/l'),
              const SizedBox(height: 12),
              TabelaSimples(
                colunas: const ['Placa', 'Km total', 'Km médio', 'km/l', 'Custo'],
                flexColunas: const [2, 2, 2, 2, 2],
                linhas: itens
                    .map((i) => [
                          i.placa,
                          formatarInt(i.kmTotal.round()),
                          i.kmMedio.toStringAsFixed(0),
                          i.mediaKmL != null ? i.mediaKmL!.toStringAsFixed(2) : '—',
                          _moeda2.format(i.custoTotal),
                        ])
                    .toList(),
                maxHeight: 260,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
