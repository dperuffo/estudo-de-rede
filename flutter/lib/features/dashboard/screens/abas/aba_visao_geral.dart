import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/sessao_provider.dart';
import '../../../inteligencia_rede/widgets/inteligencia_shared.dart';
import '../../providers/dashboard_provider.dart';

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

// Fase FLT-6 — 1ª aba do Dashboard ("Visão Geral"): o que já existia na
// Fase FLT-3 (KPIs, meios de pagamento, gráfico de consumo, CNH vencendo,
// top clientes) mais as 4 seções que tinham ficado de fora: Ajustes de
// Abastecimento, Desempenho por Centro de Custo, Manutenção Preditiva
// (resumo) e Primeiros Passos. Os 8 "Indicadores avançados" (período
// próprio) viraram a 2ª aba — ver aba_indicadores_avancados.dart.
class AbaVisaoGeral extends ConsumerWidget {
  const AbaVisaoGeral({super.key});

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

            if (dados.mostrarPrimeirosPassos) ...[
              _cardPrimeirosPassos(context, dados),
              const SizedBox(height: 20),
            ],

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

            if (dados.resumoAjustes != null) ...[
              const SizedBox(height: 20),
              _secaoAjustes(context, dados.resumoAjustes!),
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

            if (dados.centroCusto != null) ...[
              const SizedBox(height: 20),
              _secaoCentroCusto(dados.centroCusto!),
            ],

            if (dados.manutencao != null) ...[
              const SizedBox(height: 20),
              _secaoManutencao(context, dados.manutencao!),
            ],
          ],
        ),
      ),
    );
  }

  // Primeiros passos — porta PrimeirosPassos.tsx. Some sozinho quando
  // veículos e motoristas já estão cadastrados (dados.mostrarPrimeirosPassos).
  Widget _cardPrimeirosPassos(BuildContext context, DashboardClienteDados dados) {
    final veiculosOk = dados.totalVeiculos > 0;
    final motoristasOk = dados.totalMotoristas > 0;
    final postosOk = dados.totalPostosProprios > 0;

    Widget passo({
      required bool feito,
      bool opcional = false,
      required String titulo,
      required String descricao,
      required String href,
      required String textoAcao,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 8),
              child: Opacity(opacity: feito ? 1 : 0.4, child: Text(feito ? '✅' : '⬜', style: const TextStyle(fontSize: 16))),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(TextSpan(children: [
                    TextSpan(text: titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    if (opcional) const TextSpan(text: '  (opcional)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ])),
                  const SizedBox(height: 2),
                  Text(descricao, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            if (!feito) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => context.push(href),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Text(textoAcao, style: const TextStyle(fontSize: 11)),
              ),
            ],
          ],
        ),
      );
    }

    return Card(
      color: const Color(0xFFF0F9F5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🚀 Primeiros passos na plataforma', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
              'O essencial pra começar a operar. Você já pode consultar rotas e preços de combustível agora mesmo — não precisa esperar terminar esta lista.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            passo(
              feito: veiculosOk,
              titulo: 'Cadastre os veículos da frota',
              descricao: veiculosOk
                  ? '${dados.totalVeiculos} veículo(s) cadastrado(s).'
                  : 'Necessário pra registrar abastecimentos, manutenção e custos por veículo.',
              href: '/veiculos/novo',
              textoAcao: 'Cadastrar veículo',
            ),
            passo(
              feito: motoristasOk,
              titulo: 'Cadastre os motoristas',
              descricao: motoristasOk
                  ? '${dados.totalMotoristas} motorista(s) cadastrado(s).'
                  : 'Necessário pra vincular abastecimentos e acompanhar CNH/desempenho por motorista.',
              href: '/motoristas/novo',
              textoAcao: 'Cadastrar motorista',
            ),
            passo(
              feito: postosOk,
              opcional: true,
              titulo: 'Carregue os postos revendedores do seu relacionamento',
              descricao: postosOk
                  ? '${dados.totalPostosProprios} posto(s) próprio(s) cadastrado(s).'
                  : 'Opcional: sem isso, Roteirização e consulta de Postos já funcionam com a base pública de preços ANP (por UF/município).',
              href: '/postos',
              textoAcao: 'Ver postos',
            ),
          ],
        ),
      ),
    );
  }

  // Ajustes de abastecimento — porta SecaoAjustesAbastecimentos.tsx.
  Widget _secaoAjustes(BuildContext context, ResumoAjustes resumo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSecao('Ajustes de abastecimento — últimos 30 dias'),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            CartaoIndicador(label: 'Pendentes de resposta', valor: '${resumo.pendentes}', mini: true),
            CartaoIndicador(label: 'Aceitos no período', valor: '${resumo.aceitosNoPeriodo}', mini: true),
            CartaoIndicador(label: 'Impacto financeiro', valor: _moeda.format(resumo.impactoFinanceiro), mini: true),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Align(alignment: Alignment.centerLeft, child: Text('Últimos ajustes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
              ),
              if (resumo.ultimos.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Nenhum ajuste registrado ainda.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                )
              else
                ...resumo.ultimos.map((a) => ListTile(
                      dense: true,
                      title: Text('#${a.abastecimentoId} · ${a.origem == 'cliente' ? 'Cliente' : 'Posto'}'),
                      subtitle: Text('${statusAjusteLabel[a.status] ?? a.status} · ${_formatarData(a.atualizadoEm)}',
                          style: const TextStyle(fontSize: 11)),
                      trailing: a.chaveRota != null
                          ? TextButton(
                              onPressed: () => context.push('/abastecimentos/${a.chaveRota}'),
                              child: const Text('Ver', style: TextStyle(fontSize: 12)),
                            )
                          : null,
                    )),
            ],
          ),
        ),
      ],
    );
  }

  // Centro de custo — porta a seção "Desempenho por centro de custo" (mês
  // atual — ver decisão de escopo no comentário de dashboard_provider.dart).
  Widget _secaoCentroCusto(CentroCustoDados centro) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSecao('Desempenho por centro de custo (mês atual)'),
        if (centro.linhas.isEmpty)
          _cardVazio('Nenhum centro de custo cadastrado para este cliente.')
        else ...[
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: [
              CartaoIndicador(label: 'Veículos alocados', valor: '${centro.totalVeiculos}', mini: true),
              CartaoIndicador(label: 'Custo abastecimento', valor: _moeda.format(centro.totalAbastecimento), mini: true),
              CartaoIndicador(label: 'Custo manutenção', valor: _moeda.format(centro.totalManutencao), mini: true),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TabelaSimples(
                colunas: const ['Centro de custo', 'Veíc.', 'Abastec.', 'Manut.', 'R\$/km', 'km/l'],
                flexColunas: const [3, 1, 2, 2, 2, 2],
                linhas: centro.linhas
                    .map((c) => [
                          c.nome,
                          '${c.qtdVeiculos}',
                          _moeda.format(c.custoAbastecimento),
                          _moeda.format(c.custoManutencao),
                          c.custoPorKm != null ? 'R\$ ${c.custoPorKm!.toStringAsFixed(3)}' : '—',
                          c.consumoMedio != null ? c.consumoMedio!.toStringAsFixed(2) : '—',
                        ])
                    .toList(),
                maxHeight: 260,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Manutenção preditiva (resumo) — porta o card "Manutenção preditiva" do
  // Dashboard (estado atual da frota, não depende de período).
  Widget _secaoManutencao(BuildContext context, ManutencaoResumo m) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _tituloSecao('Manutenção preditiva'),
            TextButton(
              onPressed: () => context.push('/manutencao-preditiva'),
              child: const Text('Ver frota completa →', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        if (m.totalCriticos > 0)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              border: Border.all(color: const Color(0xFFFECACA)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '🚨 ${m.totalCriticos} veículo(s) em estado crítico — pelo menos um componente vencido pelo km rodado.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
            ),
          ),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            CartaoIndicador(label: 'Veículos analisados', valor: '${m.totalVeiculos}', mini: true),
            CartaoIndicador(label: '🔴 Críticos', valor: '${m.totalCriticos}', mini: true),
            CartaoIndicador(label: '🟡 Em alerta', valor: '${m.totalAlertas}', mini: true),
            CartaoIndicador(label: 'Score médio', valor: '${m.scoreMedio.round()}/100', mini: true),
          ],
        ),
      ],
    );
  }

  // BarChart de litros/mês — a web usa um gráfico de barras com 2 eixos Y
  // (litros à esquerda, valor à direita). Simplificado aqui pra 1 eixo
  // (litros, o principal) + valor exposto no tooltip e no total abaixo.
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
              getTooltipColor: (_) => const Color(0xFF263238),
              getTooltipItem: (group, groupIdx, rod, rodIdx) {
                final p = pontos[group.x];
                return BarTooltipItem(
                  '${_numero.format(p.litros.round())} L\n${_moeda.format(p.valor)}',
                  const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
