import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/financeiro_posto_provider.dart';
import '../services/financeiro_posto_service.dart';

enum _FiltroCiclo { todos, andamento, aberta, vencida, paga }

const _filtroCicloLabel = <_FiltroCiclo, String>{
  _FiltroCiclo.todos: 'Todos',
  _FiltroCiclo.andamento: 'Em andamento',
  _FiltroCiclo.aberta: 'Em aberto',
  _FiltroCiclo.vencida: 'Vencida',
  _FiltroCiclo.paga: 'Paga',
};

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

const _corMeioPagamento = <String, Color>{
  'profrotas': Color(0xFFDBEAFE),
  'Valecard': Color(0xFFEDE9FE),
  'RedeFrota': Color(0xFFFFEDD5),
  'TicketLog': Color(0xFFCCFBF1),
  'Veloe': Color(0xFFFCE7F3),
};

// Indicador gráfico (pedido do Daniel) — versão "sólida" da paleta acima
// (que é pastel, pensada pra fundo de avatar) só pro donut/legenda, onde
// precisa de mais contraste. Mesma correspondência de chaves.
const _corSolidaMeioPagamento = <String, Color>{
  'profrotas': Color(0xFF2563EB),
  'Valecard': Color(0xFF7C3AED),
  'RedeFrota': Color(0xFFEA580C),
  'TicketLog': Color(0xFF0D9488),
  'Veloe': Color(0xFFDB2777),
};
const _corSolidaMeioPagamentoFallback = Color(0xFF64748B);

String _nomeProvedor(String p) => p == 'profrotas' ? 'PróFrotas' : p;

String _dataBr(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// Fase FLT-2 — porta reduzida de financeiro-posto/page.tsx (ver escopo
// completo no comentário de financeiro_posto_provider.dart).
class FinanceiroPostoScreen extends ConsumerStatefulWidget {
  const FinanceiroPostoScreen({super.key});

  @override
  ConsumerState<FinanceiroPostoScreen> createState() => _FinanceiroPostoScreenState();
}

class _FinanceiroPostoScreenState extends ConsumerState<FinanceiroPostoScreen> {
  PeriodoFinanceiro _periodo = PeriodoFinanceiro.quinzeDias;
  bool _formularioAberto = false;
  _FiltroCiclo _filtroCiclo = _FiltroCiclo.todos;
  final _buscaCiclosCtrl = TextEditingController();

  @override
  void dispose() {
    _buscaCiclosCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(financeiroPostoProvider(_periodo));
    final sessaoAsync = ref.watch(sessaoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Financeiro')),
      floatingActionButton: sessaoAsync.maybeWhen(
        data: (sessao) => sessao.empresaId == null
            ? null
            : FloatingActionButton.extended(
                onPressed: () => setState(() => _formularioAberto = !_formularioAberto),
                icon: Icon(_formularioAberto ? Icons.close : Icons.add),
                label: Text(_formularioAberto ? 'Fechar' : 'Lançar despesa'),
              ),
        orElse: () => null,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (dados) {
          if (dados == null) return const Center(child: Text('Nenhuma empresa selecionada.'));
          final empresaPostoId = sessaoAsync.value?.empresaId;
          return _buildConteudo(context, dados, empresaPostoId);
        },
      ),
    );
  }

  Widget _buildConteudo(BuildContext context, FinanceiroPostoDetalhe dados, String? empresaPostoId) {
    final hojeIso = DateTime.now().toIso8601String().substring(0, 10);
    final janela = resolverPeriodo(_periodo);
    final janelaPrevista = resolverJanelaPrevista(_periodo, janela.inicio, janela.fim, hojeIso);

    final aReceberAberto = dados.faturas.where((f) => f.status == 'aberta').fold<double>(0, (s, f) => s + f.valorTotal) +
        dados.cicloAbertoValorTotal;
    final vencido = dados.faturas
        .where((f) => f.status == 'aberta' && f.vencimento.compareTo(hojeIso) < 0)
        .fold<double>(0, (s, f) => s + f.valorTotal);
    final recebidoNoPeriodo = dados.faturas
        .where((f) =>
            f.status == 'paga' &&
            f.pagoEm != null &&
            f.pagoEm!.substring(0, 10).compareTo(janela.inicio) >= 0 &&
            f.pagoEm!.substring(0, 10).compareTo(janela.fim) <= 0)
        .fold<double>(0, (s, f) => s + f.valorTotal);
    final aPagarAberto = dados.despesas.where((d) => d.status == 'aberta').fold<double>(0, (s, d) => s + d.valor);
    final pagoNoPeriodo = dados.despesas
        .where((d) =>
            d.status == 'paga' &&
            d.pagoEm != null &&
            d.pagoEm!.substring(0, 10).compareTo(janela.inicio) >= 0 &&
            d.pagoEm!.substring(0, 10).compareTo(janela.fim) <= 0)
        .fold<double>(0, (s, d) => s + d.valor);
    final aReceberVencendo = dados.faturas
        .where((f) =>
            f.status == 'aberta' &&
            f.vencimento.compareTo(janelaPrevista.inicio) >= 0 &&
            f.vencimento.compareTo(janelaPrevista.fim) <= 0)
        .fold<double>(0, (s, f) => s + f.valorTotal);
    final aPagarVencendo = dados.despesas
        .where((d) =>
            d.status == 'aberta' &&
            d.vencimento.compareTo(janelaPrevista.inicio) >= 0 &&
            d.vencimento.compareTo(janelaPrevista.fim) <= 0)
        .fold<double>(0, (s, d) => s + d.valor);
    final saldoPrevisto = aReceberVencendo - aPagarVencendo;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        const Text('Contas a receber (faturas dos clientes) e contas a pagar (despesas do posto).',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: PeriodoFinanceiro.values
              .map((p) => ChoiceChip(
                    label: Text(periodoFinanceiroLabel[p]!),
                    selected: _periodo == p,
                    onSelected: (_) => setState(() => _periodo = p),
                  ))
              .toList(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Período: ${_dataBr(janela.inicio)} – ${_dataBr(janela.fim)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.9,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _indicador('A receber (aberto)', _moeda.format(aReceberAberto)),
            _indicador('Vencido', _moeda.format(vencido), cor: const Color(0xFFDC2626)),
            _indicador('Recebido no período', _moeda.format(recebidoNoPeriodo), cor: const Color(0xFF16A34A)),
            _indicador('A pagar (aberto)', _moeda.format(aPagarAberto)),
            _indicador('Pago no período', _moeda.format(pagoNoPeriodo), cor: const Color(0xFF16A34A)),
            _indicador('Saldo previsto', _moeda.format(saldoPrevisto),
                cor: saldoPrevisto < 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
          ],
        ),
        if (_dadosFluxoCaixa(dados, janelaPrevista).isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Fluxo de caixa previsto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text('A receber x a pagar por dia de vencimento (${_dataBr(janelaPrevista.inicio)} – ${_dataBr(janelaPrevista.fim)}).',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
              child: _graficoFluxoCaixa(_dadosFluxoCaixa(dados, janelaPrevista)),
            ),
          ),
        ],
        if (dados.indicadoresPorProvedor.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Consolidado por meio de pagamento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('Abastecimentos que você forneceu no período, por meio de pagamento usado pelo cliente.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 10),
          if (dados.indicadoresPorProvedor.length > 1)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _donutMeioPagamento(dados.indicadoresPorProvedor),
              ),
            ),
          const SizedBox(height: 8),
          ...dados.indicadoresPorProvedor.map((p) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _corMeioPagamento[p.provedor] ?? const Color(0xFFF1F5F9),
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
        _buildCiclosPorCliente(context, dados.linhasPorCliente),
        const SizedBox(height: 20),
        if (_formularioAberto && empresaPostoId != null) ...[
          _FormularioDespesa(
            empresaPostoId: empresaPostoId,
            onSalvo: () {
              setState(() => _formularioAberto = false);
              ref.invalidate(financeiroPostoProvider(_periodo));
            },
          ),
          const SizedBox(height: 20),
        ],
        const Text('Contas a pagar (despesas do posto)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
        if (dados.despesas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Nenhuma despesa lançada ainda.', style: TextStyle(color: Colors.grey)),
          )
        else
          ...dados.despesas.map((d) => _linhaDespesa(d)),
      ],
    );
  }

  Widget _linhaDespesa(DespesaFinanceiro d) {
    final hojeIso = DateTime.now().toIso8601String().substring(0, 10);
    final vencida = d.status == 'aberta' && d.vencimento.compareTo(hojeIso) < 0;
    final statusLabel = d.status == 'paga' ? 'Paga' : (vencida ? 'Vencida' : 'Em aberto');
    final statusCor = d.status == 'paga'
        ? const Color(0xFF16A34A)
        : (vencida ? const Color(0xFFDC2626) : const Color(0xFF64748B));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(tipoDespesaPostoLabel[d.tipo] ?? d.tipo,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                Text(_moeda.format(d.valor), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            if (d.descricao != null && d.descricao!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(d.descricao!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('Vence ${_dataBr(d.vencimento)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusCor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(statusLabel, style: TextStyle(fontSize: 11, color: statusCor, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            if (d.status == 'aberta') ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () async {
                      final erro = await FinanceiroPostoService().marcarDespesaPaga(d.id);
                      if (!mounted) return;
                      if (erro != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
                      } else {
                        ref.invalidate(financeiroPostoProvider(_periodo));
                      }
                    },
                    child: const Text('Marcar como paga'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final erro = await FinanceiroPostoService().excluirDespesa(d.id);
                      if (!mounted) return;
                      if (erro != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
                      } else {
                        ref.invalidate(financeiroPostoProvider(_periodo));
                      }
                    },
                    child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Ciclos por Cliente (VisaoCiclosPorContraparte na web) — pedido do
  // Daniel: tinha ficado de fora do escopo reduzido; restaurado com filtros
  // por status + busca por nome (client-side, igual à web) e drill-down
  // pras telas já existentes de ciclo aberto/fatura/cliente.
  Widget _buildCiclosPorCliente(BuildContext context, List<LinhaContraparte> linhas) {
    final busca = _buscaCiclosCtrl.text.trim().toLowerCase();
    var filtradas = linhas.where((l) {
      switch (_filtroCiclo) {
        case _FiltroCiclo.todos:
          return true;
        case _FiltroCiclo.andamento:
          return l.cicloAtual != null;
        case _FiltroCiclo.aberta:
          return l.contagem.aberta > 0;
        case _FiltroCiclo.vencida:
          return l.contagem.vencida > 0;
        case _FiltroCiclo.paga:
          return l.contagem.paga > 0;
      }
    }).toList();
    if (busca.isNotEmpty) {
      filtradas = filtradas.where((l) => l.contraparteNome.toLowerCase().contains(busca)).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ciclos por Cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 4),
        const Text('Ciclo atual (em andamento) e resumo de faturas de cada cliente.',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 10),
        TextField(
          controller: _buscaCiclosCtrl,
          decoration: const InputDecoration(
            hintText: 'Buscar cliente...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _FiltroCiclo.values
              .map((f) => ChoiceChip(
                    label: Text(_filtroCicloLabel[f]!),
                    selected: _filtroCiclo == f,
                    onSelected: (_) => setState(() => _filtroCiclo = f),
                  ))
              .toList(),
        ),
        const SizedBox(height: 10),
        if (linhas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Nenhum cliente com ciclo ainda.', style: TextStyle(color: Colors.grey)),
          )
        else if (filtradas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Nenhum resultado para esse filtro/busca.', style: TextStyle(color: Colors.grey)),
          )
        else
          ...filtradas.map((l) => _linhaContraparte(context, l)),
      ],
    );
  }

  Widget _linhaContraparte(BuildContext context, LinhaContraparte l) {
    final ciclo = l.cicloAtual;
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
                child: Text('Ciclo ${l.cicloFaturamentoDias}+${l.prazoVencimentoDias} dias',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            const SizedBox(height: 8),
            if (ciclo != null) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Em andamento',
                        style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
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
                  onTap: () => context.push('/posto/ciclos-abertos/${ciclo.negociacaoId}'),
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
                if (l.contagem.aberta > 0) _chipContagem('${l.contagem.aberta} em aberto', const Color(0xFF64748B)),
                if (l.contagem.paga > 0) _chipContagem('${l.contagem.paga} paga(s)', const Color(0xFF16A34A)),
                if (l.contagem.vencida == 0 && l.contagem.aberta == 0 && l.contagem.paga == 0)
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
                onPressed: () => context.push('/posto/clientes/${l.contraparteId}'),
                child: const Text('Ver histórico'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Porta de GraficoFluxoCaixaPosto.tsx — mesma janela PROSPECTIVA
  // (janelaPrevista) já usada pros KPIs "vencendo no período"/"saldo
  // previsto" acima, só que quebrada por dia em vez de só o total.
  List<_PontoFluxoCaixa> _dadosFluxoCaixa(
      FinanceiroPostoDetalhe dados, ({String inicio, String fim}) janelaPrevista) {
    final porDia = <String, ({double aReceber, double aPagar})>{};
    for (final f in dados.faturas) {
      if (f.status != 'aberta') continue;
      if (f.vencimento.compareTo(janelaPrevista.inicio) < 0 || f.vencimento.compareTo(janelaPrevista.fim) > 0) continue;
      final atual = porDia[f.vencimento] ?? (aReceber: 0.0, aPagar: 0.0);
      porDia[f.vencimento] = (aReceber: atual.aReceber + f.valorTotal, aPagar: atual.aPagar);
    }
    for (final d in dados.despesas) {
      if (d.status != 'aberta') continue;
      if (d.vencimento.compareTo(janelaPrevista.inicio) < 0 || d.vencimento.compareTo(janelaPrevista.fim) > 0) continue;
      final atual = porDia[d.vencimento] ?? (aReceber: 0.0, aPagar: 0.0);
      porDia[d.vencimento] = (aReceber: atual.aReceber, aPagar: atual.aPagar + d.valor);
    }
    final lista = porDia.entries
        .map((e) => _PontoFluxoCaixa(dia: e.key, aReceber: e.value.aReceber, aPagar: e.value.aPagar))
        .toList()
      ..sort((a, b) => a.dia.compareTo(b.dia));
    return lista;
  }

  // BarChart agrupado (2 barras/dia) — mesmo espírito do BarChart da web
  // (grupos, não linha: só 2 séries, o interesse é comparar dia a dia).
  Widget _graficoFluxoCaixa(List<_PontoFluxoCaixa> pontos) {
    const corReceber = Color(0xFF16A34A);
    const corPagar = Color(0xFFDC2626);
    final maxVal = pontos
        .map((p) => p.aReceber > p.aPagar ? p.aReceber : p.aPagar)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Column(children: [
      SizedBox(
        height: 200,
        child: BarChart(BarChartData(
          maxY: maxVal <= 0 ? 1 : maxVal * 1.2,
          barGroups: pontos.asMap().entries.map((e) {
            final i = e.key;
            final p = e.value;
            return BarChartGroupData(x: i, barsSpace: 4, barRods: [
              BarChartRodData(
                toY: p.aReceber,
                color: corReceber,
                width: 8,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
              BarChartRodData(
                toY: p.aPagar,
                color: corPagar,
                width: 8,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
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
              interval: pontos.length > 6 ? (pontos.length / 6).ceilToDouble() : 1,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= pontos.length) return const SizedBox();
                return Text(_dataBr(pontos[idx].dia).substring(0, 5), style: const TextStyle(fontSize: 9));
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
              getTooltipItem: (group, groupIdx, rod, rodIdx) => BarTooltipItem(
                _moeda.format(rod.toY),
                TextStyle(color: rodIdx == 0 ? corReceber : corPagar, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        )),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 12, children: [
        Row(mainAxisSize: MainAxisSize.min, children: const [
          _LegendaDot(cor: corReceber),
          SizedBox(width: 4),
          Text('A receber', style: TextStyle(fontSize: 11)),
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: const [
          _LegendaDot(cor: corPagar),
          SizedBox(width: 4),
          Text('A pagar', style: TextStyle(fontSize: 11)),
        ]),
      ]),
    ]);
  }

  // Donut de consolidado por meio de pagamento — sem equivalente direto na
  // web ainda; dado já vinha calculado no provider (indicadoresPorProvedor).
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
                color: _corSolidaMeioPagamento[p.provedor] ?? _corSolidaMeioPagamentoFallback,
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
              final cor = _corSolidaMeioPagamento[p.provedor] ?? _corSolidaMeioPagamentoFallback;
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

class _PontoFluxoCaixa {
  final String dia; // yyyy-MM-dd
  final double aReceber;
  final double aPagar;
  const _PontoFluxoCaixa({required this.dia, required this.aReceber, required this.aPagar});
}

class _LegendaDot extends StatelessWidget {
  final Color cor;
  const _LegendaDot({required this.cor});
  @override
  Widget build(BuildContext context) =>
      Container(width: 10, height: 10, decoration: BoxDecoration(color: cor, shape: BoxShape.circle));
}

// Formulário "Lançar despesa" — mesmos campos de LancarDespesaForm (web),
// menos o campo de anexo/comprovante (fora do escopo desta versão).
class _FormularioDespesa extends StatefulWidget {
  final String empresaPostoId;
  final VoidCallback onSalvo;
  const _FormularioDespesa({required this.empresaPostoId, required this.onSalvo});

  @override
  State<_FormularioDespesa> createState() => _FormularioDespesaState();
}

class _FormularioDespesaState extends State<_FormularioDespesa> {
  String? _tipo;
  final _valorCtrl = TextEditingController();
  final _competenciaCtrl = TextEditingController();
  final _vencimentoCtrl = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  bool _recorrente = false;
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _valorCtrl.dispose();
    _competenciaCtrl.dispose();
    _vencimentoCtrl.dispose();
    _descricaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _selecionarData(TextEditingController controller) async {
    final atual = DateTime.tryParse(controller.text) ?? DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (escolhida != null) {
      setState(() => controller.text = DateFormat('yyyy-MM-dd').format(escolhida));
    }
  }

  Future<void> _salvar() async {
    final valor = double.tryParse(_valorCtrl.text.trim().replaceAll(',', '.'));
    if (_tipo == null) {
      setState(() => _erro = 'Selecione o tipo.');
      return;
    }
    if (valor == null || valor <= 0) {
      setState(() => _erro = 'Valor inválido.');
      return;
    }
    if (_competenciaCtrl.text.trim().isEmpty) {
      setState(() => _erro = 'Informe a competência.');
      return;
    }
    if (_vencimentoCtrl.text.trim().isEmpty) {
      setState(() => _erro = 'Informe o vencimento.');
      return;
    }

    setState(() {
      _salvando = true;
      _erro = null;
    });

    final erro = await FinanceiroPostoService().lancarDespesa(
      empresaPostoId: widget.empresaPostoId,
      tipo: _tipo!,
      valor: valor,
      competencia: _competenciaCtrl.text.trim(),
      vencimento: _vencimentoCtrl.text.trim(),
      descricao: _descricaoCtrl.text,
      recorrente: _recorrente,
    );

    if (!mounted) return;
    if (erro != null) {
      setState(() {
        _salvando = false;
        _erro = erro;
      });
      return;
    }
    widget.onSalvo();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lançar despesa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
              items: tiposDespesaPosto
                  .map((t) => DropdownMenuItem(value: t, child: Text(tipoDespesaPostoLabel[t] ?? t)))
                  .toList(),
              onChanged: (v) => setState(() => _tipo = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _valorCtrl,
              decoration: const InputDecoration(labelText: 'Valor (R\$)', border: OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _competenciaCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Competência (mês da despesa)',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: () => _selecionarData(_competenciaCtrl),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _vencimentoCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Vencimento',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: () => _selecionarData(_vencimentoCtrl),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descricaoCtrl,
              decoration: const InputDecoration(labelText: 'Descrição (opcional)', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 6),
            CheckboxListTile(
              value: _recorrente,
              onChanged: (v) => setState(() => _recorrente = v ?? false),
              title: const Text('Despesa recorrente (todo mês)'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_erro!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                child: Text(_salvando ? 'Salvando...' : 'Salvar despesa'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
