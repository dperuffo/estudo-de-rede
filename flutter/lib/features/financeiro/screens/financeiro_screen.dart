import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../posto/providers/financeiro_posto_provider.dart'
    show IndicadorProvedor, LinhaContraparte, FaturaFinanceiro;
import '../providers/financeiro_provider.dart';
import 'posto_cobranca_detalhe_screen.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

const _corMeioPagamento = <String, Color>{
  'profrotas': Color(0xFF2563EB),
  'Valecard': Color(0xFF7C3AED),
  'RedeFrota': Color(0xFFEA580C),
  'TicketLog': Color(0xFF0D9488),
  'Veloe': Color(0xFFDB2777),
};
const _corMeioPagamentoFallback = Color(0xFF64748B);
String _nomeProvedor(String p) => p == 'profrotas' ? 'PróFrotas' : p;

String _dataBr(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String _mesLabel(String isoMes) {
  // "mes" volta como yyyy-MM-dd (1º dia do mês) da RPC.
  final d = DateTime.tryParse(isoMes);
  if (d == null) return isoMes;
  const meses = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
  return '${meses[d.month - 1]}/${d.year.toString().substring(2)}';
}

// Fase FLT-3 — reescrita completa (a versão antiga usava ApiService, o
// backend Python legado sem auth funcional — ver README). Porta reduzida
// de financeiro/page.tsx pro Flutter (visão Cliente). Ver escopo completo
// (o que ficou de fora) no comentário de financeiro_provider.dart.
class FinanceiroScreen extends ConsumerWidget {
  const FinanceiroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(financeiroClienteProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Painel Financeiro')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (dados) {
          if (dados == null) return const Center(child: Text('Nenhuma empresa selecionada.'));
          return _buildConteudo(context, dados);
        },
      ),
    );
  }

  Widget _buildConteudo(BuildContext context, FinanceiroClienteDados dados) {
    final ind = dados.indicadores;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const Text('Custos do mês atual, consolidado por meio de pagamento e cobrança em aberto com os postos.',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.9,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _indicador('Custo total', _moeda.format(ind.custoTotal)),
            _indicador('Custo por km', ind.custoPorKm == null ? '—' : '${_moeda.format(ind.custoPorKm)}/km'),
            _indicador('Orçamento planejado', _moeda.format(ind.orcamentoPlanejado)),
            _indicador('Saldo do orçamento', _moeda.format(ind.saldoOrcamento),
                cor: ind.saldoOrcamento < 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
            _indicador('Combustível', _moeda.format(ind.custoCombustivel)),
            _indicador('Manutenção', _moeda.format(ind.custoManutencao)),
            _indicador('Custos fixos', _moeda.format(ind.custoFixos)),
          ],
        ),
        if (dados.evolucao.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Evolução mensal (6 meses)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('Combustível, manutenção e custos fixos por mês.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
              child: _graficoEvolucao(dados.evolucao),
            ),
          ),
        ],
        if (dados.porProvedor.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Consolidado por meio de pagamento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('Abastecimentos do mês, por meio de pagamento usado.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 10),
          if (dados.porProvedor.length > 1)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _donutMeioPagamento(dados.porProvedor),
              ),
            ),
          const SizedBox(height: 8),
          ...dados.porProvedor.map((p) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (_corMeioPagamento[p.provedor] ?? _corMeioPagamentoFallback).withOpacity(0.15),
                    child: Text(_nomeProvedor(p.provedor).substring(0, 1),
                        style: const TextStyle(color: Colors.black87, fontSize: 13)),
                  ),
                  title: Text(_nomeProvedor(p.provedor)),
                  subtitle: Text('${p.qtdAbastecimentos} abastecimento(s) · ${p.litros.toStringAsFixed(0)} L'),
                  trailing: Text(_moeda.format(p.valorTotal), style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              )),
        ],
        const SizedBox(height: 20),
        _buildCobrancaEmAberto(context, dados.linhasPorPosto, dados.faturas),
        const SizedBox(height: 20),
        _buildUltimasFaturas(context, dados.faturas),
      ],
    );
  }

  // Cobrança em Aberto (visão Cliente) — mesmo espírito de Ciclos por
  // Cliente do Financeiro Posto, com posto no lugar de cliente. "Ver
  // detalhamento" (ciclo em andamento) leva pro CicloAbertoClienteDetalheScreen
  // (rota /ciclos-abertos/:negociacaoId). "Ver histórico" (pedido do
  // Daniel) leva pro PostoCobrancaDetalheScreen novo, com TODAS as faturas
  // desse posto — escopo mais enxuto que /posto/clientes/:id (sem
  // cadastro/negociações, que dependem da futura tela Postos
  // Revendedores).
  Widget _buildCobrancaEmAberto(BuildContext context, List<LinhaContraparte> linhas, List<FaturaFinanceiro> todasFaturas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cobrança em Aberto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 4),
        const Text('Ciclo atual (em andamento) e resumo de faturas com cada posto.',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 10),
        if (linhas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Nenhum posto com ciclo ainda.', style: TextStyle(color: Colors.grey)),
          )
        else
          ...linhas.map((l) => _linhaContraparte(context, l, todasFaturas)),
      ],
    );
  }

  // Pedido do Daniel — lista de faturas individuais (não só o resumo
  // agrupado por posto acima), cada uma levando pro extrato completo em
  // FaturaDetalheScreen (rota /faturas/:id). Mostra só as mais recentes
  // pra não sobrecarregar a tela (mesmo limite "recente" usado noutras
  // listas do app).
  Widget _buildUltimasFaturas(BuildContext context, List<FaturaFinanceiro> faturas) {
    final recentes = faturas.take(10).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Últimas faturas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 4),
        const Text('Toque numa fatura pra ver o extrato de abastecimentos.',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 10),
        if (recentes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Nenhuma fatura ainda.', style: TextStyle(color: Colors.grey)),
          )
        else
          ...recentes.map((f) => _linhaFatura(context, f)),
      ],
    );
  }

  Widget _linhaFatura(BuildContext context, FaturaFinanceiro f) {
    final cor = switch (f.status) {
      'paga' => const Color(0xFF16A34A),
      'cancelada' => Colors.grey,
      'fechada' => const Color(0xFF64748B),
      _ => const Color(0xFF92400E),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('/faturas/${f.id}'),
        title: Text(f.clienteNome ?? '—'),
        subtitle: Text('Vence ${_dataBr(f.vencimento)}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_moeda.format(f.valorTotal), style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(f.status, style: TextStyle(fontSize: 11, color: cor, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _linhaContraparte(BuildContext context, LinhaContraparte l, List<FaturaFinanceiro> todasFaturas) {
    final ciclo = l.cicloAtual;
    final faturasDoPosto = todasFaturas.where((f) => f.empresaClienteId == l.contraparteId).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.contraparteNome, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            if (l.cicloFaturamentoDias > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Ciclo de ${l.cicloFaturamentoDias} dias',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            const SizedBox(height: 8),
            if (ciclo != null) ...[
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Em andamento',
                      style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                '${ciclo.periodoInicio != null ? _dataBr(ciclo.periodoInicio!) : '—'} – ${ciclo.periodoFimPrevisto != null ? _dataBr(ciclo.periodoFimPrevisto!) : '—'} · '
                '${ciclo.quantidadeAbastecimentos} abastecimento${ciclo.quantidadeAbastecimentos == 1 ? '' : 's'} · '
                '${_moeda.format(ciclo.valorAcumulado)}',
                style: const TextStyle(fontSize: 12),
              ),
              if (ciclo.quantidadePendenteNfe > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${_moeda.format(ciclo.valorPendenteNfe)} (${ciclo.quantidadePendenteNfe}) esperando NF-e',
                    style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: GestureDetector(
                  onTap: () => context.push('/ciclos-abertos/${ciclo.negociacaoId}'),
                  child: const Text('Ver detalhamento',
                      style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                ),
              ),
            ] else
              const Text('Sem ciclo em andamento', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (l.contagem.vencida > 0) _chipContagem('${l.contagem.vencida} vencida(s)', const Color(0xFFDC2626)),
                if (l.contagem.fechada > 0) _chipContagem('${l.contagem.fechada} fechada(s)', const Color(0xFF64748B)),
                if (l.contagem.aVencer > 0) _chipContagem('${l.contagem.aVencer} a vencer', const Color(0xFF64748B)),
                if (l.contagem.paga > 0) _chipContagem('${l.contagem.paga} paga(s)', const Color(0xFF16A34A)),
                if (l.contagem.vencida == 0 && l.contagem.fechada == 0 && l.contagem.aVencer == 0 && l.contagem.paga == 0)
                  const Text('Nenhuma ainda', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            if (l.valorEmAberto > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    children: [
                      const TextSpan(text: 'Em aberto: '),
                      TextSpan(
                          text: _moeda.format(l.valorEmAberto), style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (l.valorVencido > 0)
                        TextSpan(
                          text: ' (${_moeda.format(l.valorVencido)} vencido)',
                          style: const TextStyle(color: Color(0xFFDC2626)),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push(
                  '/postos-cobranca/detalhe',
                  extra: PostoCobrancaDetalheScreen(
                    postoNome: l.contraparteNome,
                    cicloFaturamentoDias: l.cicloFaturamentoDias,
                    cicloAtual: l.cicloAtual,
                    faturas: faturasDoPosto,
                  ),
                ),
                child: const Text('Ver histórico'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // BarChart agrupado (3 barras/mês) — combustível/manutenção/custos fixos.
  Widget _graficoEvolucao(List<PontoEvolucaoFinanceira> pontos) {
    const corCombustivel = Color(0xFF2563EB);
    const corManutencao = Color(0xFFEA580C);
    const corFixos = Color(0xFF64748B);
    final maxVal = pontos
        .map((p) => [p.custoCombustivel, p.custoManutencao, p.custoFixos].reduce((a, b) => a > b ? a : b))
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Column(children: [
      SizedBox(
        height: 200,
        child: BarChart(BarChartData(
          maxY: maxVal <= 0 ? 1 : maxVal * 1.2,
          barGroups: pontos.asMap().entries.map((e) {
            final i = e.key;
            final p = e.value;
            return BarChartGroupData(x: i, barsSpace: 3, barRods: [
              BarChartRodData(
                  toY: p.custoCombustivel,
                  color: corCombustivel,
                  width: 6,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(2))),
              BarChartRodData(
                  toY: p.custoManutencao,
                  color: corManutencao,
                  width: 6,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(2))),
              BarChartRodData(
                  toY: p.custoFixos,
                  color: corFixos,
                  width: 6,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(2))),
            ]);
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, _) => Text('R\$${v.round()}', style: const TextStyle(fontSize: 9)),
            )),
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= pontos.length) return const SizedBox();
                return Text(_mesLabel(pontos[idx].mes), style: const TextStyle(fontSize: 9));
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
              // Achado do Daniel — texto colorido em cima do fundo escuro
              // padrão do tooltip ficava ilegível. Corrigido: fundo escuro
              // explícito + texto branco, cor só na bolinha.
              getTooltipColor: (_) => const Color(0xFF1E293B),
              getTooltipItem: (group, groupIdx, rod, rodIdx) {
                const labels = ['Combustível', 'Manutenção', 'Fixos'];
                final cores = [corCombustivel, corManutencao, corFixos];
                return BarTooltipItem(
                  '● ',
                  TextStyle(color: cores[rodIdx], fontSize: 11),
                  children: [
                    TextSpan(
                      text: '${labels[rodIdx]}\n${_moeda.format(rod.toY)}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                );
              },
            ),
          ),
        )),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 12, children: const [
        _Legenda(cor: corCombustivel, rotulo: 'Combustível'),
        _Legenda(cor: corManutencao, rotulo: 'Manutenção'),
        _Legenda(cor: corFixos, rotulo: 'Custos fixos'),
      ]),
    ]);
  }

  Widget _donutMeioPagamento(List<IndicadorProvedor> lista) {
    return SizedBox(
      height: 170,
      child: Row(children: [
        Expanded(
          child: PieChart(PieChartData(
            sections: lista.map((p) {
              final totalGeral = lista.fold<double>(0, (s, x) => s + x.valorTotal);
              final pct = totalGeral > 0 ? (p.valorTotal / totalGeral) * 100 : 0.0;
              return PieChartSectionData(
                value: p.valorTotal,
                title: '${pct.toStringAsFixed(0)}%',
                color: _corMeioPagamento[p.provedor] ?? _corMeioPagamentoFallback,
                radius: 55,
                titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              );
            }).toList(),
            centerSpaceRadius: 30,
            sectionsSpace: 2,
          )),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lista.map((p) {
              final cor = _corMeioPagamento[p.provedor] ?? _corMeioPagamentoFallback;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_nomeProvedor(p.provedor),
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

  Widget _chipContagem(String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(texto, style: TextStyle(fontSize: 11, color: cor, fontWeight: FontWeight.w600)),
    );
  }

  Widget _indicador(String label, String valor, {Color? cor}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(valor,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cor),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  final Color cor;
  final String rotulo;
  const _Legenda({required this.cor, required this.rotulo});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(rotulo, style: const TextStyle(fontSize: 11)),
      ]);
}
