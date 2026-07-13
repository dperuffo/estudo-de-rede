import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — porta de src/app/(dashboard)/financeiro-posto/page.tsx +
// src/lib/financeiroPostos.ts pro Flutter, escopo bem reduzido (tela mais
// complexa da web até agora): mantém os KPIs principais (a receber/vencido/
// recebido/a pagar/pago/saldo previsto), o consolidado por meio de
// pagamento e as contas a pagar (despesas) com lançar/marcar paga/excluir.
// Fora do escopo desta versão: gráfico de fluxo de caixa por dia
// (GraficoFluxoCaixaPosto), tabela de aging (faixas de atraso) e a visão
// agrupada por cliente (VisaoCiclosPorContraparte — já dá pra ver o ciclo/
// fatura de cada cliente em /posto/clientes/:id) e o resumo de ajustes de
// abastecimento (SecaoAjustesAbastecimentos — cada ajuste específico já é
// visto no detalhe do abastecimento). Período "personalizado" (datas
// escolhidas à mão) também fora do escopo — só as 4 opções rápidas.

enum PeriodoFinanceiro { hoje, seteDias, quinzeDias, mes }

const periodoFinanceiroLabel = <PeriodoFinanceiro, String>{
  PeriodoFinanceiro.hoje: 'Hoje',
  PeriodoFinanceiro.seteDias: '7 dias',
  PeriodoFinanceiro.quinzeDias: '15 dias',
  PeriodoFinanceiro.mes: 'Mês atual',
};

const tiposDespesaPosto = <String>[
  'combustivel_distribuidora',
  'salarios',
  'manutencao',
  'impostos',
  'aluguel',
  'energia',
  'outro',
];

const tipoDespesaPostoLabel = <String, String>{
  'combustivel_distribuidora': 'Combustível / Distribuidora',
  'salarios': 'Salários',
  'manutencao': 'Manutenção',
  'impostos': 'Impostos',
  'aluguel': 'Aluguel',
  'energia': 'Energia',
  'outro': 'Outro',
};

String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

// Espelha resolverPeriodoFinanceiro (financeiroPostos.ts), sem o caminho
// "personalizado".
({String inicio, String fim}) resolverPeriodo(PeriodoFinanceiro periodo) {
  final hoje = DateTime.now();
  final fim = _iso(hoje);
  DateTime inicioData;
  switch (periodo) {
    case PeriodoFinanceiro.hoje:
      inicioData = hoje;
      break;
    case PeriodoFinanceiro.seteDias:
      inicioData = hoje.subtract(const Duration(days: 6));
      break;
    case PeriodoFinanceiro.mes:
      inicioData = DateTime(hoje.year, hoje.month, 1);
      break;
    case PeriodoFinanceiro.quinzeDias:
      inicioData = hoje.subtract(const Duration(days: 14));
      break;
  }
  return (inicio: _iso(inicioData), fim: fim);
}

// Espelha resolverJanelaPrevista — janela PROSPECTIVA (pra frente, a partir
// de hoje) usada só pros indicadores "vencendo no período"/"saldo previsto"
// (retrospectivos como "recebido no período" usam a janela normal acima).
({String inicio, String fim}) resolverJanelaPrevista(PeriodoFinanceiro periodo, String inicio, String fim, String hojeIso) {
  if (periodo == PeriodoFinanceiro.mes) {
    final hoje = DateTime.parse(hojeIso);
    final fimMes = DateTime(hoje.year, hoje.month + 1, 0);
    return (inicio: hojeIso, fim: _iso(fimMes));
  }
  final qtdDias = DateTime.parse(fim).difference(DateTime.parse(inicio)).inDays;
  final fimPrevisto = DateTime.parse(hojeIso).add(Duration(days: qtdDias));
  return (inicio: hojeIso, fim: _iso(fimPrevisto));
}

class FaturaFinanceiro {
  final String id;
  final double valorTotal;
  final String status;
  final String vencimento;
  final String? pagoEm;
  const FaturaFinanceiro({
    required this.id,
    required this.valorTotal,
    required this.status,
    required this.vencimento,
    required this.pagoEm,
  });
  factory FaturaFinanceiro.fromMap(Map<String, dynamic> m) => FaturaFinanceiro(
        id: m['id'] as String,
        valorTotal: (m['valor_total'] as num?)?.toDouble() ?? 0,
        status: m['status'] as String? ?? 'aberta',
        vencimento: m['vencimento'] as String,
        pagoEm: m['pago_em'] as String?,
      );
}

class DespesaFinanceiro {
  final String id;
  final String tipo;
  final String? descricao;
  final double valor;
  final String competencia;
  final String vencimento;
  final String status;
  final String? pagoEm;
  final bool recorrente;
  const DespesaFinanceiro({
    required this.id,
    required this.tipo,
    required this.descricao,
    required this.valor,
    required this.competencia,
    required this.vencimento,
    required this.status,
    required this.pagoEm,
    required this.recorrente,
  });
  factory DespesaFinanceiro.fromMap(Map<String, dynamic> m) => DespesaFinanceiro(
        id: m['id'] as String,
        tipo: m['tipo'] as String? ?? 'outro',
        descricao: m['descricao'] as String?,
        valor: (m['valor'] as num?)?.toDouble() ?? 0,
        competencia: m['competencia'] as String,
        vencimento: m['vencimento'] as String,
        status: m['status'] as String? ?? 'aberta',
        pagoEm: m['pago_em'] as String?,
        recorrente: m['recorrente'] as bool? ?? false,
      );
}

class IndicadorProvedor {
  final String provedor;
  final double valorTotal;
  final double litros;
  final int qtdAbastecimentos;
  const IndicadorProvedor({
    required this.provedor,
    required this.valorTotal,
    required this.litros,
    required this.qtdAbastecimentos,
  });
}

class FinanceiroPostoDetalhe {
  final List<FaturaFinanceiro> faturas;
  final List<DespesaFinanceiro> despesas;
  final List<IndicadorProvedor> indicadoresPorProvedor;
  final double cicloAbertoValorTotal;
  const FinanceiroPostoDetalhe({
    required this.faturas,
    required this.despesas,
    required this.indicadoresPorProvedor,
    required this.cicloAbertoValorTotal,
  });
}

final financeiroPostoProvider =
    FutureProvider.autoDispose.family<FinanceiroPostoDetalhe?, PeriodoFinanceiro>((ref, periodo) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return null;
  final supabase = SupabaseService.client;

  final janela = resolverPeriodo(periodo);

  final faturasRaw = await supabase
      .from('faturas_postos')
      .select('id, valor_total, status, vencimento, pago_em')
      .eq('empresa_posto_id', empresaId)
      .order('vencimento', ascending: false)
      .limit(500) as List;
  final faturas = faturasRaw.map((m) => FaturaFinanceiro.fromMap(m as Map<String, dynamic>)).toList();

  final despesasRaw = await supabase
      .from('despesas_postos')
      .select('id, tipo, descricao, valor, competencia, vencimento, status, pago_em, recorrente')
      .eq('empresa_posto_id', empresaId)
      .order('vencimento', ascending: false)
      .limit(500) as List;
  final despesas = despesasRaw.map((m) => DespesaFinanceiro.fromMap(m as Map<String, dynamic>)).toList();

  // Consolidado por meio de pagamento — mesma fonte/filtro de
  // AbastecimentosPosto.tsx: abastecimentos_unificado por posto_cnpj.
  var indicadoresPorProvedor = <IndicadorProvedor>[];
  final empresa = await supabase.from('empresas').select('cnpj').eq('id', empresaId).maybeSingle();
  final meuCnpj = empresa?['cnpj'] as String?;
  if (meuCnpj != null && meuCnpj.isNotEmpty) {
    final unificadoRaw = await supabase
        .from('abastecimentos_unificado')
        .select('provedor, valor_total, litros')
        .eq('posto_cnpj', meuCnpj)
        .gte('data_abastecimento', '${janela.inicio}T00:00:00')
        .lte('data_abastecimento', '${janela.fim}T23:59:59')
        .limit(50000) as List;
    final porProvedor = <String, ({double valorTotal, double litros, int qtd})>{};
    for (final r in unificadoRaw) {
      final m = r as Map<String, dynamic>;
      final provedor = m['provedor'] as String? ?? 'outro';
      final atual = porProvedor[provedor] ?? (valorTotal: 0.0, litros: 0.0, qtd: 0);
      porProvedor[provedor] = (
        valorTotal: atual.valorTotal + ((m['valor_total'] as num?)?.toDouble() ?? 0),
        litros: atual.litros + ((m['litros'] as num?)?.toDouble() ?? 0),
        qtd: atual.qtd + 1,
      );
    }
    indicadoresPorProvedor = porProvedor.entries
        .map((e) => IndicadorProvedor(
              provedor: e.key,
              valorTotal: e.value.valorTotal,
              litros: e.value.litros,
              qtdAbastecimentos: e.value.qtd,
            ))
        .toList()
      ..sort((a, b) => b.valorTotal.compareTo(a.valorTotal));
  }

  // Ciclo em andamento (ainda não fechado pelo robô) — já representa valor
  // devido; soma no "A receber (em aberto)" (Fase 27.91 na web).
  final ciclosRaw = await supabase.rpc('ciclos_abertos_postos') as List;
  double cicloAbertoValorTotal = 0;
  for (final m in ciclosRaw) {
    final mm = m as Map<String, dynamic>;
    if (mm['empresa_posto_id'] == empresaId) {
      cicloAbertoValorTotal += (mm['valor_acumulado'] as num?)?.toDouble() ?? 0;
    }
  }

  return FinanceiroPostoDetalhe(
    faturas: faturas,
    despesas: despesas,
    indicadoresPorProvedor: indicadoresPorProvedor,
    cicloAbertoValorTotal: cicloAbertoValorTotal,
  );
});
