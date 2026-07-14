import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — porta de src/app/(dashboard)/financeiro-posto/page.tsx +
// src/lib/financeiroPostos.ts pro Flutter, escopo reduzido (tela mais
// complexa da web até agora): mantém os KPIs principais (a receber/vencido/
// recebido/a pagar/pago/saldo previsto), o consolidado por meio de
// pagamento, a visão "Ciclos por Cliente" (VisaoCiclosPorContraparte — 1
// linha por cliente com o ciclo atual + resumo de faturas, com drill-down
// pra /posto/ciclos-abertos/:negociacaoId, /posto/faturas/:id e
// /posto/clientes/:id) e as contas a pagar (despesas) com lançar/marcar
// paga/excluir. **Achado do Daniel:** "Ciclos por Cliente" tinha sido
// cortado do escopo por engano (achando que /posto/clientes/:id já cobria
// sozinho) — restaurado nesta revisão, igual à web. Fora do escopo desta
// versão: gráfico de fluxo de caixa por dia (GraficoFluxoCaixaPosto),
// tabela de aging (faixas de atraso) e o resumo de ajustes de
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
  final String? empresaClienteId;
  final String? clienteNome;
  final double valorTotal;
  final String status;
  final String vencimento;
  final String? pagoEm;
  const FaturaFinanceiro({
    required this.id,
    this.empresaClienteId,
    this.clienteNome,
    required this.valorTotal,
    required this.status,
    required this.vencimento,
    required this.pagoEm,
  });
  factory FaturaFinanceiro.fromMap(Map<String, dynamic> m) => FaturaFinanceiro(
        id: m['id'] as String,
        empresaClienteId: m['empresa_cliente_id'] as String?,
        clienteNome: m['cliente_nome'] as String?,
        valorTotal: (m['valor_total'] as num?)?.toDouble() ?? 0,
        status: m['status'] as String? ?? 'fechada',
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

// Ciclo em andamento (ainda não fechado pelo robô), resumido só com o que
// a visão "Ciclos por Cliente" precisa — mesmos campos de
// ciclo_aberto_detalhe_provider.dart (RPC ciclos_abertos_postos).
class CicloAbertoResumo {
  final String negociacaoId;
  final String? periodoInicio;
  final String? periodoFimPrevisto;
  final double valorAcumulado;
  final int quantidadeAbastecimentos;
  final double valorPendenteNfe;
  final int quantidadePendenteNfe;

  const CicloAbertoResumo({
    required this.negociacaoId,
    this.periodoInicio,
    this.periodoFimPrevisto,
    required this.valorAcumulado,
    required this.quantidadeAbastecimentos,
    required this.valorPendenteNfe,
    required this.quantidadePendenteNfe,
  });

  factory CicloAbertoResumo.fromMap(Map<String, dynamic> m) => CicloAbertoResumo(
        negociacaoId: m['negociacao_id'].toString(),
        periodoInicio: m['periodo_inicio'] as String?,
        periodoFimPrevisto: m['periodo_fim_previsto'] as String?,
        valorAcumulado: (m['valor_acumulado'] as num?)?.toDouble() ?? 0,
        quantidadeAbastecimentos: (m['quantidade_abastecimentos'] as num?)?.toInt() ?? 0,
        valorPendenteNfe: (m['valor_pendente_nfe'] as num?)?.toDouble() ?? 0,
        quantidadePendenteNfe: (m['quantidade_pendente_nfe'] as num?)?.toInt() ?? 0,
      );
}

// Fase CICLOS-6 — mesma mudança da web (5 status): "aberta" (fatura real,
// valor travado) virou "aVencer"; ganhou "fechada" (janela terminou mas o
// boleto ainda não foi gerado — valor ainda 0).
class ContagemFaturas {
  int fechada;
  int aVencer;
  int vencida;
  int paga;
  int cancelada;
  ContagemFaturas({this.fechada = 0, this.aVencer = 0, this.vencida = 0, this.paga = 0, this.cancelada = 0});
}

// Espelha LinhaContraparte (ciclosAbertos.ts) — 1 linha por cliente.
// `prazoVencimentoDias` saiu (sempre = cicloFaturamentoDias agora).
class LinhaContraparte {
  final String contraparteId;
  final String contraparteNome;
  final int cicloFaturamentoDias;
  final CicloAbertoResumo? cicloAtual;
  final ContagemFaturas contagem;
  double valorEmAberto;
  double valorVencido;

  LinhaContraparte({
    required this.contraparteId,
    required this.contraparteNome,
    required this.cicloFaturamentoDias,
    required this.cicloAtual,
    required this.contagem,
    this.valorEmAberto = 0,
    this.valorVencido = 0,
  });
}

// Espelha agruparCiclosPorContraparte (ciclosAbertos.ts) 1:1, inclusive a
// ordem de prioridade (vencida > fechada/a_vencer > ciclo em andamento >
// histórico).
List<LinhaContraparte> agruparPorContraparte({
  required List<({String contraparteId, String? contraparteNome, int cicloFaturamentoDias})> negociacoes,
  required List<FaturaFinanceiro> faturas,
  required Map<String, CicloAbertoResumo> ciclosAbertosPorContraparte,
  required String hojeIso,
}) {
  final linhas = <String, LinhaContraparte>{};

  for (final n in negociacoes) {
    linhas[n.contraparteId] = LinhaContraparte(
      contraparteId: n.contraparteId,
      contraparteNome: n.contraparteNome ?? '—',
      cicloFaturamentoDias: n.cicloFaturamentoDias,
      cicloAtual: ciclosAbertosPorContraparte[n.contraparteId],
      contagem: ContagemFaturas(),
    );
  }

  for (final f in faturas) {
    final contraparteId = f.empresaClienteId;
    if (contraparteId == null) continue;
    var linha = linhas[contraparteId];
    if (linha == null) {
      linha = LinhaContraparte(
        contraparteId: contraparteId,
        contraparteNome: f.clienteNome ?? '—',
        cicloFaturamentoDias: 0,
        cicloAtual: null,
        contagem: ContagemFaturas(),
      );
      linhas[contraparteId] = linha;
    }

    final vencida = f.status == 'a_vencer' && f.vencimento.compareTo(hojeIso) < 0;
    if (vencida) {
      linha.contagem.vencida += 1;
    } else if (f.status == 'fechada') {
      linha.contagem.fechada += 1;
    } else if (f.status == 'a_vencer') {
      linha.contagem.aVencer += 1;
    } else if (f.status == 'paga') {
      linha.contagem.paga += 1;
    } else if (f.status == 'cancelada') {
      linha.contagem.cancelada += 1;
    }

    if (f.status == 'fechada' || f.status == 'a_vencer') {
      linha.valorEmAberto += f.valorTotal;
      if (vencida) linha.valorVencido += f.valorTotal;
    }
  }

  // Ciclo em andamento (ainda sem linha em faturas_postos) soma no valor em
  // aberto mesmo antes de virar fatura real (Fase 27.91 na web).
  for (final linha in linhas.values) {
    if (linha.cicloAtual != null) {
      linha.valorEmAberto += linha.cicloAtual!.valorAcumulado;
    }
  }

  int prioridade(LinhaContraparte l) {
    if (l.contagem.vencida > 0) return 0;
    if (l.contagem.fechada > 0 || l.contagem.aVencer > 0) return 1;
    if (l.cicloAtual != null) return 2;
    return 3;
  }

  final lista = linhas.values.toList();
  lista.sort((a, b) {
    final p = prioridade(a) - prioridade(b);
    if (p != 0) return p;
    return a.contraparteNome.compareTo(b.contraparteNome);
  });
  return lista;
}

class FinanceiroPostoDetalhe {
  final List<FaturaFinanceiro> faturas;
  final List<DespesaFinanceiro> despesas;
  final List<IndicadorProvedor> indicadoresPorProvedor;
  final double cicloAbertoValorTotal;
  final List<LinhaContraparte> linhasPorCliente;
  const FinanceiroPostoDetalhe({
    required this.faturas,
    required this.despesas,
    required this.indicadoresPorProvedor,
    required this.cicloAbertoValorTotal,
    required this.linhasPorCliente,
  });
}

final financeiroPostoProvider =
    FutureProvider.autoDispose.family<FinanceiroPostoDetalhe?, PeriodoFinanceiro>((ref, periodo) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return null;
  final supabase = SupabaseService.client;

  final janela = resolverPeriodo(periodo);
  final hojeIso = _iso(DateTime.now());

  final faturasRaw = await supabase
      .from('faturas_postos')
      .select('id, empresa_cliente_id, cliente_nome, valor_total, status, vencimento, pago_em')
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
  // devido; soma no "A receber (em aberto)" (Fase 27.91 na web). Também
  // usado abaixo (por cliente) na visão "Ciclos por Cliente".
  final ciclosRaw = await supabase.rpc('ciclos_abertos_postos') as List;
  double cicloAbertoValorTotal = 0;
  final ciclosAbertosPorCliente = <String, CicloAbertoResumo>{};
  for (final m in ciclosRaw) {
    final mm = m as Map<String, dynamic>;
    if (mm['empresa_posto_id'] == empresaId) {
      cicloAbertoValorTotal += (mm['valor_acumulado'] as num?)?.toDouble() ?? 0;
      final clienteId = mm['empresa_cliente_id'] as String?;
      if (clienteId != null) {
        ciclosAbertosPorCliente[clienteId] = CicloAbertoResumo.fromMap(mm);
      }
    }
  }

  // Ciclos por Cliente (VisaoCiclosPorContraparte na web) — base de
  // negociações aceitas (mesmo sem fatura ainda) + ciclo/prazo do CLIENTE
  // (empresas.ciclo_faturamento_dias/prazo_vencimento_dias, default 30
  // igual à web).
  final negociacoesRaw = await supabase
      .from('negociacoes_postos')
      .select('empresa_cliente_id, cliente_nome')
      .eq('empresa_posto_id', empresaId)
      .eq('status', 'aceita') as List;
  final idsClientes = negociacoesRaw
      .map((m) => (m as Map<String, dynamic>)['empresa_cliente_id'] as String?)
      .whereType<String>()
      .toSet()
      .toList();
  final ciclosPorClienteMap = <String, int>{};
  if (idsClientes.isNotEmpty) {
    final clientesCicloRaw =
        await supabase.from('empresas').select('id, ciclo_faturamento_dias').inFilter('id', idsClientes) as List;
    for (final c in clientesCicloRaw) {
      final cc = c as Map<String, dynamic>;
      ciclosPorClienteMap[cc['id'] as String] = (cc['ciclo_faturamento_dias'] as num?)?.toInt() ?? 30;
    }
  }
  final negociacoesParaAgrupar = negociacoesRaw.map((m) {
    final mm = m as Map<String, dynamic>;
    final clienteId = mm['empresa_cliente_id'] as String;
    return (
      contraparteId: clienteId,
      contraparteNome: mm['cliente_nome'] as String?,
      cicloFaturamentoDias: ciclosPorClienteMap[clienteId] ?? 30,
    );
  }).toList();

  final linhasPorCliente = agruparPorContraparte(
    negociacoes: negociacoesParaAgrupar,
    faturas: faturas,
    ciclosAbertosPorContraparte: ciclosAbertosPorCliente,
    hojeIso: hojeIso,
  );

  return FinanceiroPostoDetalhe(
    faturas: faturas,
    despesas: despesas,
    indicadoresPorProvedor: indicadoresPorProvedor,
    cicloAbertoValorTotal: cicloAbertoValorTotal,
    linhasPorCliente: linhasPorCliente,
  );
});
