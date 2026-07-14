import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../posto/providers/financeiro_posto_provider.dart'
    show FaturaFinanceiro, IndicadorProvedor, CicloAbertoResumo, LinhaContraparte, ContagemFaturas, agruparPorContraparte;

// Fase FLT-3 — porta de src/app/(dashboard)/financeiro/page.tsx pro Flutter
// (visão Cliente), escopo bem reduzido em relação à web (tela mais densa
// da web depois da própria financeiro-posto): mantém os 7 KPIs do mês
// (indicadores_financeiros), o consolidado por meio de pagamento
// (indicadores_financeiros_por_provedor), a evolução mensal de 6 meses
// (indicadores_financeiros_evolucao) e a "Cobrança em Aberto" — aqui
// reaproveitando DIRETO `agruparPorContraparte`/`LinhaContraparte` já
// portados pro Financeiro do Posto (FLT-2): lá a contraparte é o cliente,
// aqui é o posto — a função é agnóstica, só lê os campos do mapa que a
// gente monta. Fora do escopo desta versão (igual ao espírito das outras
// telas FLT-3): os 2 formulários de CRUD (Planejar orçamento / Lançar
// custo fixo — cada um merece sua própria iteração, com validação e
// edição), a tabela de Orçamento por categoria (indicadores_financeiros_
// por_centro_custo), o card de link pra Planos de Viagem (tela que nem
// existe ainda no Flutter) e o ramo só-admin de indicadores FNI
// (mostrarFni na web). Período fixo: KPIs/provedor no mês atual,
// evolução nos últimos 6 meses — sem seletor de período customizado por
// ora (mesma decisão da Financeiro Posto).

String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

class IndicadoresFinanceiros {
  final double custoCombustivel;
  final double litrosAbastecidos;
  final double kmRodado;
  final double custoManutencao;
  final double custoFixos;
  final double custoTotal;
  final double? custoPorKm;
  final double orcamentoPlanejado;
  const IndicadoresFinanceiros({
    required this.custoCombustivel,
    required this.litrosAbastecidos,
    required this.kmRodado,
    required this.custoManutencao,
    required this.custoFixos,
    required this.custoTotal,
    required this.custoPorKm,
    required this.orcamentoPlanejado,
  });
  static const vazio = IndicadoresFinanceiros(
    custoCombustivel: 0,
    litrosAbastecidos: 0,
    kmRodado: 0,
    custoManutencao: 0,
    custoFixos: 0,
    custoTotal: 0,
    custoPorKm: null,
    orcamentoPlanejado: 0,
  );
  factory IndicadoresFinanceiros.fromMap(Map<String, dynamic> m) => IndicadoresFinanceiros(
        custoCombustivel: (m['custo_combustivel'] as num?)?.toDouble() ?? 0,
        litrosAbastecidos: (m['litros_abastecidos'] as num?)?.toDouble() ?? 0,
        kmRodado: (m['km_rodado'] as num?)?.toDouble() ?? 0,
        custoManutencao: (m['custo_manutencao'] as num?)?.toDouble() ?? 0,
        custoFixos: (m['custo_fixos'] as num?)?.toDouble() ?? 0,
        custoTotal: (m['custo_total'] as num?)?.toDouble() ?? 0,
        custoPorKm: (m['custo_por_km'] as num?)?.toDouble(),
        orcamentoPlanejado: (m['orcamento_planejado'] as num?)?.toDouble() ?? 0,
      );

  double get saldoOrcamento => orcamentoPlanejado - custoTotal;
}

class PontoEvolucaoFinanceira {
  final String mes;
  final double custoCombustivel;
  final double custoManutencao;
  final double custoFixos;
  const PontoEvolucaoFinanceira({
    required this.mes,
    required this.custoCombustivel,
    required this.custoManutencao,
    required this.custoFixos,
  });
  factory PontoEvolucaoFinanceira.fromMap(Map<String, dynamic> m) => PontoEvolucaoFinanceira(
        mes: m['mes'] as String,
        custoCombustivel: (m['custo_combustivel'] as num?)?.toDouble() ?? 0,
        custoManutencao: (m['custo_manutencao'] as num?)?.toDouble() ?? 0,
        custoFixos: (m['custo_fixos'] as num?)?.toDouble() ?? 0,
      );
}

class FinanceiroClienteDados {
  final IndicadoresFinanceiros indicadores;
  final List<IndicadorProvedor> porProvedor;
  final List<PontoEvolucaoFinanceira> evolucao;
  final List<LinhaContraparte> linhasPorPosto;
  // Fase FLT-3 — pedido do Daniel: tela de detalhamento das faturas (não
  // só o resumo agrupado por posto). Lista crua, mais recentes primeiro.
  final List<FaturaFinanceiro> faturas;
  const FinanceiroClienteDados({
    required this.indicadores,
    required this.porProvedor,
    required this.evolucao,
    required this.linhasPorPosto,
    required this.faturas,
  });
}

final financeiroClienteProvider = FutureProvider.autoDispose<FinanceiroClienteDados?>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return null;
  final supabase = SupabaseService.client;

  final hoje = DateTime.now();
  final inicioMes = _iso(DateTime(hoje.year, hoje.month, 1));
  final hojeIso = _iso(hoje);
  final inicioEvolucao = _iso(DateTime(hoje.year, hoje.month - 5, 1));

  final indicadoresRaw = await supabase.rpc('indicadores_financeiros', params: {
    'p_empresa_id': empresaId,
    'p_data_inicio': inicioMes,
    'p_data_fim': hojeIso,
  }) as List;
  final indicadores = indicadoresRaw.isEmpty
      ? IndicadoresFinanceiros.vazio
      : IndicadoresFinanceiros.fromMap(indicadoresRaw.first as Map<String, dynamic>);

  final provedorRaw = await supabase.rpc('indicadores_financeiros_por_provedor', params: {
    'p_empresa_id': empresaId,
    'p_data_inicio': inicioMes,
    'p_data_fim': hojeIso,
  }) as List;
  final porProvedor = provedorRaw
      .map((m) {
        final mm = m as Map<String, dynamic>;
        return IndicadorProvedor(
          provedor: mm['provedor'] as String? ?? 'outro',
          valorTotal: (mm['custo_combustivel'] as num?)?.toDouble() ?? 0,
          litros: (mm['litros'] as num?)?.toDouble() ?? 0,
          qtdAbastecimentos: (mm['qtd_abastecimentos'] as num?)?.toInt() ?? 0,
        );
      })
      .toList()
    ..sort((a, b) => b.valorTotal.compareTo(a.valorTotal));

  final evolucaoRaw = await supabase.rpc('indicadores_financeiros_evolucao', params: {
    'p_empresa_id': empresaId,
    'p_data_inicio': inicioEvolucao,
    'p_data_fim': hojeIso,
  }) as List;
  final evolucao = evolucaoRaw.map((m) => PontoEvolucaoFinanceira.fromMap(m as Map<String, dynamic>)).toList();

  // Cobrança em Aberto (visão Cliente) — mesma lógica de
  // VisaoCiclosPorContraparte da Financeiro Posto, com posto no lugar de
  // cliente: negociações aceitas (empresa_cliente_id = eu) trazem
  // posto_nome já denormalizado; ciclo/prazo de faturamento é o MEU
  // próprio (empresas.ciclo_faturamento_dias/prazo_vencimento_dias),
  // igual pra qualquer posto que me fatura.
  final minhaEmpresa =
      await supabase.from('empresas').select('ciclo_faturamento_dias').eq('id', empresaId).maybeSingle();
  final meuCiclo = (minhaEmpresa?['ciclo_faturamento_dias'] as num?)?.toInt() ?? 30;

  final negociacoesRaw = await supabase
      .from('negociacoes_postos')
      .select('empresa_posto_id, posto_nome')
      .eq('empresa_cliente_id', empresaId)
      .eq('status', 'aceita') as List;
  final nomePorPosto = <String, String?>{};
  for (final n in negociacoesRaw) {
    final nn = n as Map<String, dynamic>;
    final postoId = nn['empresa_posto_id'] as String?;
    if (postoId != null) nomePorPosto[postoId] = nn['posto_nome'] as String?;
  }
  final negociacoesParaAgrupar = nomePorPosto.entries
      .map((e) => (
            contraparteId: e.key,
            contraparteNome: e.value,
            cicloFaturamentoDias: meuCiclo,
          ))
      .toList();

  final faturasRaw = await supabase
      .from('faturas_postos')
      .select('id, empresa_posto_id, valor_total, status, vencimento, pago_em')
      .eq('empresa_cliente_id', empresaId)
      .order('vencimento', ascending: false)
      .limit(500) as List;
  // Remapeado pra reaproveitar FaturaFinanceiro/agruparPorContraparte
  // (que leem "empresa_cliente_id"/"cliente_nome" como o ID/nome da
  // CONTRAPARTE) — aqui a contraparte é o posto.
  final faturas = faturasRaw.map((m) {
    final mm = m as Map<String, dynamic>;
    final postoId = mm['empresa_posto_id'] as String?;
    return FaturaFinanceiro.fromMap({
      'id': mm['id'],
      'empresa_cliente_id': postoId,
      'cliente_nome': nomePorPosto[postoId],
      'valor_total': mm['valor_total'],
      'status': mm['status'],
      'vencimento': mm['vencimento'],
      'pago_em': mm['pago_em'],
    });
  }).toList();

  final ciclosRaw = await supabase.rpc('ciclos_abertos_postos') as List;
  final ciclosAbertosPorPosto = <String, CicloAbertoResumo>{};
  for (final m in ciclosRaw) {
    final mm = m as Map<String, dynamic>;
    if (mm['empresa_cliente_id'] == empresaId) {
      final postoId = mm['empresa_posto_id'] as String?;
      if (postoId != null) {
        ciclosAbertosPorPosto[postoId] = CicloAbertoResumo.fromMap(mm);
      }
    }
  }

  final linhasPorPosto = agruparPorContraparte(
    negociacoes: negociacoesParaAgrupar,
    faturas: faturas,
    ciclosAbertosPorContraparte: ciclosAbertosPorPosto,
    hojeIso: hojeIso,
  );

  return FinanceiroClienteDados(
    indicadores: indicadores,
    porProvedor: porProvedor,
    evolucao: evolucao,
    linhasPorPosto: linhasPorPosto,
    faturas: faturas,
  );
});
