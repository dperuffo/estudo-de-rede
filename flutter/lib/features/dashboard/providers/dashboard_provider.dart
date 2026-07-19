import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-6 — porta o restante de src/app/(dashboard)/dashboard/page.tsx
// que tinha ficado de fora na Fase FLT-3 (ver comentário antigo, removido
// aqui): Ajustes de Abastecimento, Primeiros Passos, Desempenho por Centro
// de Custo e Manutenção Preditiva (resumo). Os 8 "Indicadores avançados"
// (variação de preços, previsão de consumo, evolução de preço médio,
// evolutivo/top postos, ranking veículos/motoristas, eficiência por
// veículo) ficam em indicadores_avancados_provider.dart — são todos
// escopados por período (mês/ano) e viraram uma aba própria na tela
// ("Indicadores Avançados"), com seletor de mês independente.
//
// Igual à web: nem todo perfil "cliente" tem necessariamente uma única
// empresa vinculada — a resolução de qual empresa mostrar já acontece antes
// desta tela (sessaoProvider + /selecionar-empresa) — aqui só usamos
// `sessao.empresaId` já resolvido, sem repetir o seletor de cliente que a
// web tem no topo da página.
//
// Decisão de escopo (Centro de Custo x seletor de período): na web, Centro
// de Custo usa o MESMO seletor único de mês/ano do topo da página que
// também direciona os 8 indicadores avançados. Como o Daniel pediu pra
// separar em 2 abas (Visão Geral x Indicadores Avançados) e o seletor de
// período fica só na 2ª aba, Centro de Custo aqui na Visão Geral sempre
// mostra o MÊS ATUAL (sem seletor próprio) — simplificação deliberada pra
// não duplicar o seletor nem espalhar estado entre abas. Se o Daniel quiser
// escolher outro mês pro Centro de Custo, dá pra reavaliar depois.

const _janelaConsumoMeses = 6;
const _janelaCnhDias = 30;
const _janelaAjustesDias = 30;

const _mesesAbrev = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez',
];

String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

class ProvedorValorMes {
  final String provedor;
  final double valor;
  const ProvedorValorMes({required this.provedor, required this.valor});
}

class PontoConsumoMensal {
  final String mesLabel; // "jan/25"
  final double litros;
  final double valor;
  const PontoConsumoMensal({required this.mesLabel, required this.litros, required this.valor});
}

class CnhVencendo {
  final String id;
  final String nome;
  final String vencimento;
  const CnhVencendo({required this.id, required this.nome, required this.vencimento});
}

class ClienteGasto {
  final String nome;
  final double valor;
  const ClienteGasto({required this.nome, required this.valor});
}

// Fase FLT-6 — item da lista "Últimos ajustes" (porta ItemResumoAjuste de
// ajustesAbastecimentos.ts). Achado real (Daniel, print do Dashboard): ajustes
// de provedor externo (Valecard/RedeFrota/TicketLog/Veloe) apareciam na lista
// sem o link "Ver", porque a chave da rota /abastecimentos/:chave precisa do
// nome do provedor (ex.: "ticket:123"), e só sabíamos 'profrotas' | 'externo'
// (o `tipo`, que só diz qual coluna da tabela ajustes_abastecimentos foi
// preenchida). Corrigido: o provider agora resolve o provedor real dos
// ajustes externos com 1 consulta extra em lote (abastecimentos_externos),
// então `provedor` já vem pronto pra montar a chave — igual à web, que
// sempre mostra "Ver" (ver caminhoAbastecimento em ajustesAbastecimentos.ts).
class ItemAjuste {
  final String id;
  final String tipo; // 'profrotas' | 'externo'
  final int abastecimentoId;
  final String status;
  final String origem; // 'cliente' | 'posto'
  final double? valorOriginal;
  final String criadoEm;
  final String atualizadoEm;
  // Nome real do provedor pra montar a chave da rota — 'profrotas' ou o
  // provedor do abastecimento externo (ex.: 'ticket'). Null só se a busca
  // em lote não encontrou o registro (ex.: linha excluída nesse meio tempo).
  final String? provedor;
  const ItemAjuste({
    required this.id,
    required this.tipo,
    required this.abastecimentoId,
    required this.status,
    required this.origem,
    required this.valorOriginal,
    required this.criadoEm,
    required this.atualizadoEm,
    required this.provedor,
  });

  String? get chaveRota => provedor != null ? '$provedor:$abastecimentoId' : null;
}

const statusAjusteLabel = <String, String>{
  'pendente_posto': 'Aguardando posto',
  'pendente_cliente': 'Aguardando cliente',
  'aceito': 'Aceito',
  'recusado': 'Recusado',
  'cancelado': 'Cancelado',
};

class ResumoAjustes {
  final int pendentes;
  final int aceitosNoPeriodo;
  final double impactoFinanceiro;
  final List<ItemAjuste> ultimos;
  const ResumoAjustes({
    required this.pendentes,
    required this.aceitosNoPeriodo,
    required this.impactoFinanceiro,
    required this.ultimos,
  });
  static const vazio = ResumoAjustes(pendentes: 0, aceitosNoPeriodo: 0, impactoFinanceiro: 0, ultimos: []);
}

class LinhaCentroCusto {
  final String id;
  final String nome;
  final int qtdVeiculos;
  final double custoAbastecimento;
  final double custoManutencao;
  final double? custoPorKm;
  final double? consumoMedio;
  const LinhaCentroCusto({
    required this.id,
    required this.nome,
    required this.qtdVeiculos,
    required this.custoAbastecimento,
    required this.custoManutencao,
    required this.custoPorKm,
    required this.consumoMedio,
  });
}

class CentroCustoDados {
  final List<LinhaCentroCusto> linhas;
  final int totalVeiculos;
  final double totalAbastecimento;
  final double totalManutencao;
  const CentroCustoDados({
    required this.linhas,
    required this.totalVeiculos,
    required this.totalAbastecimento,
    required this.totalManutencao,
  });
  static const vazio = CentroCustoDados(linhas: [], totalVeiculos: 0, totalAbastecimento: 0, totalManutencao: 0);
}

class ManutencaoResumo {
  final int totalVeiculos;
  final int totalCriticos;
  final int totalAlertas;
  final double scoreMedio;
  const ManutencaoResumo({
    required this.totalVeiculos,
    required this.totalCriticos,
    required this.totalAlertas,
    required this.scoreMedio,
  });
}

class DashboardClienteDados {
  final int totalClientes;
  final int clientesAtivos;
  final int totalMotoristas;
  final int motoristasAtivos;
  final int totalVeiculos;
  final int veiculosAtivos;
  final int totalPostosProprios;
  final double litrosMes;
  final double valorMes;
  final double custoMedioLitroMes;
  final List<ProvedorValorMes> provedoresMes;
  final List<PontoConsumoMensal> serieConsumo;
  final List<CnhVencendo> cnhVencendo;
  final List<ClienteGasto> topClientes;
  final ResumoAjustes? resumoAjustes;
  final CentroCustoDados? centroCusto;
  final ManutencaoResumo? manutencao;

  const DashboardClienteDados({
    required this.totalClientes,
    required this.clientesAtivos,
    required this.totalMotoristas,
    required this.motoristasAtivos,
    required this.totalVeiculos,
    required this.veiculosAtivos,
    required this.totalPostosProprios,
    required this.litrosMes,
    required this.valorMes,
    required this.custoMedioLitroMes,
    required this.provedoresMes,
    required this.serieConsumo,
    required this.cnhVencendo,
    required this.topClientes,
    required this.resumoAjustes,
    required this.centroCusto,
    required this.manutencao,
  });

  static const vazio = DashboardClienteDados(
    totalClientes: 0,
    clientesAtivos: 0,
    totalMotoristas: 0,
    motoristasAtivos: 0,
    totalVeiculos: 0,
    veiculosAtivos: 0,
    totalPostosProprios: 0,
    litrosMes: 0,
    valorMes: 0,
    custoMedioLitroMes: 0,
    provedoresMes: [],
    serieConsumo: [],
    cnhVencendo: [],
    topClientes: [],
    resumoAjustes: null,
    centroCusto: null,
    manutencao: null,
  );

  // Onboarding some sozinho assim que veículos E motoristas já estiverem
  // cadastrados — mesma condição de saída de PrimeirosPassos.tsx.
  bool get mostrarPrimeirosPassos => !(totalVeiculos > 0 && totalMotoristas > 0);
}

final dashboardClienteProvider = FutureProvider.autoDispose<DashboardClienteDados>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return DashboardClienteDados.vazio;

  final supabase = SupabaseService.client;
  final agora = DateTime.now();
  final inicioMesAtual = DateTime(agora.year, agora.month, 1);
  final seisMesesAtras = DateTime(agora.year, agora.month - (_janelaConsumoMeses - 1), 1);
  final daqui30Dias = agora.add(const Duration(days: _janelaCnhDias));
  final desdeAjustes = agora.subtract(const Duration(days: _janelaAjustesDias));

  // Chamadas sequenciais (não Future.wait) — tipos de retorno diferentes
  // por consulta tornam o Future.wait tipado chato de escrever em Dart;
  // sequencial é mais simples de ler e o ganho de latência aqui é pequeno.
  final totalClientesResp = await supabase.from('empresas').select('id').count(CountOption.exact);
  final clientesAtivosResp =
      await supabase.from('empresas').select('id').eq('status', 'ativo').count(CountOption.exact);
  final totalMotoristasResp =
      await supabase.from('motoristas').select('id').eq('empresa_id', empresaId).count(CountOption.exact);
  final motoristasAtivosResp = await supabase
      .from('motoristas')
      .select('id')
      .eq('empresa_id', empresaId)
      .eq('status', 'Ativo')
      .count(CountOption.exact);
  // Fase FLT-6 (hotfix) — achado real (reportado pelo Daniel: "canceling
  // statement due to statement timeout" derrubando a aba inteira): a partir
  // daqui, cada seção NOVA (Primeiros Passos, Ajustes de Abastecimento,
  // Centro de Custo, Manutenção Preditiva) é "best effort" — try/catch
  // próprio, defaulta pra vazio/null em vez de propagar a exceção. Antes,
  // uma única RPC lenta ou travando (ex.: `manutencao_preditiva_kpis`, que
  // faz várias janelas/joins sobre o histórico inteiro de abastecimentos e
  // manutenções da empresa — mais pesada sob RLS real do que testado via
  // bypass de service role) derrubava a tela inteira, inclusive os 6 KPIs
  // principais que já funcionavam desde a Fase FLT-3.
  var totalPostosProprios = 0;
  try {
    final totalPostosPropriosResp =
        await supabase.from('postos_gf').select('cnpj').eq('empresa_id', empresaId).count(CountOption.exact);
    totalPostosProprios = totalPostosPropriosResp.count;
  } catch (_) {
    // Só afeta o 3º passo (opcional) de Primeiros Passos — assume "ainda
    // não carregado" em vez de derrubar o resto do Dashboard.
  }

  final veiculosRaw = await supabase.rpc('veiculos_da_empresa', params: {'p_empresa_id': empresaId}) as List;
  final totalVeiculos = veiculosRaw.length;
  final veiculosAtivos =
      veiculosRaw.where((v) => (v as Map<String, dynamic>)['ativo'] == true).length;

  // Abastecimentos do CLIENTE selecionado — alimenta KPIs do mês, meios de
  // pagamento e o gráfico de consumo de 6 meses.
  final abastecimentosClienteRaw = await supabase
      .from('abastecimentos_unificado')
      .select('data_abastecimento, litros, valor_total, provedor')
      .eq('empresa_id', empresaId)
      .gte('data_abastecimento', seisMesesAtras.toIso8601String())
      .limit(5000) as List;

  // Fase FLT-3 (otimização em relação à web) — a página web busca os
  // abastecimentos de TODA a rede (sem filtro de empresa) só pra somar o
  // "Top 5 clientes por gasto", trazendo litros/data/provedor que esse
  // ranking não usa. Aqui filtramos só empresa_id+valor_total (payload bem
  // menor — relevante no celular). O resultado final é o mesmo, sempre em
  // nível de rede (não escopado ao cliente selecionado), igual à web.
  final abastecimentosRedeRaw = await supabase
      .from('abastecimentos_unificado')
      .select('empresa_id, valor_total')
      .gte('data_abastecimento', seisMesesAtras.toIso8601String())
      .limit(5000) as List;

  final cnhVencendoRaw = await supabase
      .from('motoristas')
      .select('id, nome_completo, cnh_vencimento')
      .eq('empresa_id', empresaId)
      .eq('status', 'Ativo')
      .not('cnh_vencimento', 'is', null)
      .lte('cnh_vencimento', _iso(daqui30Dias))
      .order('cnh_vencimento', ascending: true)
      .limit(5) as List;

  // Ajustes de abastecimento — porta resumoAjustesAbastecimentos()
  // (ajustesAbastecimentos.ts), lado "cliente" (coluna empresa_cliente_id).
  // "Best effort" (ver comentário acima) — null em caso de erro.
  ResumoAjustes? resumoAjustes;
  try {
    final pendentesResp = await supabase
        .from('ajustes_abastecimentos')
        .select('id')
        .eq('empresa_cliente_id', empresaId)
        .inFilter('status', ['pendente_posto', 'pendente_cliente'])
        .count(CountOption.exact);
    final aceitosNoPeriodoRaw = await supabase
        .from('ajustes_abastecimentos')
        .select('id, valor_original')
        .eq('empresa_cliente_id', empresaId)
        .eq('status', 'aceito')
        .gte('atualizado_em', desdeAjustes.toIso8601String()) as List;
    final ultimosAjustesRaw = await supabase
        .from('ajustes_abastecimentos')
        .select('id, abastecimento_id, abastecimento_externo_id, status, origem, valor_original, criado_em, atualizado_em')
        .eq('empresa_cliente_id', empresaId)
        .order('atualizado_em', ascending: false)
        .limit(5) as List;

    // Resolve o provedor real dos ajustes externos (Valecard/RedeFrota/
    // TicketLog/Veloe) em 1 consulta em lote — a lista é sempre pequena
    // (limit 5), então isso não vira N+1.
    final idsExternos = ultimosAjustesRaw
        .map((u) => (u as Map<String, dynamic>)['abastecimento_externo_id'] as num?)
        .whereType<num>()
        .map((n) => n.toInt())
        .toList();
    final provedorPorIdExterno = <int, String>{};
    if (idsExternos.isNotEmpty) {
      final provedoresRaw = await supabase
          .from('abastecimentos_externos')
          .select('id, provedor')
          .inFilter('id', idsExternos) as List;
      for (final p in provedoresRaw) {
        final m = p as Map<String, dynamic>;
        provedorPorIdExterno[(m['id'] as num).toInt()] = m['provedor'] as String;
      }
    }

    // Impacto financeiro real = valor que FOI de fato aceito em cada ajuste
    // (rodada com decisao='aceita') menos o valor_original — não dá pra usar
    // só o cabeçalho (só guarda o valor de ANTES).
    final idsAceitos = aceitosNoPeriodoRaw.map((a) => (a as Map<String, dynamic>)['id'] as String).toList();
    var impactoFinanceiro = 0.0;
    if (idsAceitos.isNotEmpty) {
      final rodadasAceitasRaw = await supabase
          .from('ajustes_abastecimentos_rodadas')
          .select('ajuste_id, item_valor_total, decisao')
          .inFilter('ajuste_id', idsAceitos)
          .eq('decisao', 'aceita') as List;
      final valorAceitoPorAjuste = <String, double?>{};
      for (final r in rodadasAceitasRaw) {
        final m = r as Map<String, dynamic>;
        valorAceitoPorAjuste[m['ajuste_id'] as String] = (m['item_valor_total'] as num?)?.toDouble();
      }
      for (final a in aceitosNoPeriodoRaw) {
        final m = a as Map<String, dynamic>;
        final valorOriginal = (m['valor_original'] as num?)?.toDouble();
        final valorAceito = valorAceitoPorAjuste[m['id'] as String];
        if (valorAceito != null && valorOriginal != null) {
          impactoFinanceiro += valorAceito - valorOriginal;
        }
      }
    }

    resumoAjustes = ResumoAjustes(
      pendentes: pendentesResp.count,
      aceitosNoPeriodo: aceitosNoPeriodoRaw.length,
      impactoFinanceiro: impactoFinanceiro,
      ultimos: ultimosAjustesRaw.map((u) {
        final m = u as Map<String, dynamic>;
        final abastecimentoId = (m['abastecimento_id'] as num?)?.toInt();
        final externoId = (m['abastecimento_externo_id'] as num?)?.toInt();
        final tipo = abastecimentoId != null ? 'profrotas' : 'externo';
        return ItemAjuste(
          id: m['id'] as String,
          tipo: tipo,
          abastecimentoId: abastecimentoId ?? externoId ?? 0,
          status: m['status'] as String,
          origem: m['origem'] as String,
          valorOriginal: (m['valor_original'] as num?)?.toDouble(),
          criadoEm: m['criado_em'] as String,
          atualizadoEm: m['atualizado_em'] as String,
          provedor: tipo == 'profrotas' ? 'profrotas' : provedorPorIdExterno[externoId],
        );
      }).toList(),
    );
  } catch (_) {
    resumoAjustes = null;
  }

  // Centro de custo — mês atual (ver decisão de escopo no comentário do
  // topo do arquivo). "Best effort".
  CentroCustoDados? centroCusto;
  try {
    final centroCustoRaw = await supabase.rpc('indicadores_centro_custo', params: {
      'p_empresa_id': empresaId,
      'p_data_inicio': _iso(inicioMesAtual),
      'p_data_fim': _iso(agora),
    }) as List;
    final linhasCentroCusto = centroCustoRaw.map((c) {
      final m = c as Map<String, dynamic>;
      return LinhaCentroCusto(
        id: m['centro_custo_id'] as String,
        nome: m['centro_custo_nome'] as String? ?? '—',
        qtdVeiculos: (m['qtd_veiculos'] as num?)?.toInt() ?? 0,
        custoAbastecimento: (m['custo_abastecimento'] as num?)?.toDouble() ?? 0,
        custoManutencao: (m['custo_manutencao'] as num?)?.toDouble() ?? 0,
        custoPorKm: (m['custo_por_km'] as num?)?.toDouble(),
        consumoMedio: (m['consumo_medio'] as num?)?.toDouble(),
      );
    }).toList();
    centroCusto = CentroCustoDados(
      linhas: linhasCentroCusto,
      totalVeiculos: linhasCentroCusto.fold<int>(0, (s, l) => s + l.qtdVeiculos),
      totalAbastecimento: linhasCentroCusto.fold<double>(0, (s, l) => s + l.custoAbastecimento),
      totalManutencao: linhasCentroCusto.fold<double>(0, (s, l) => s + l.custoManutencao),
    );
  } catch (_) {
    centroCusto = null;
  }

  // Manutenção preditiva — estado atual da frota (não depende de período).
  // "Best effort": achado real (Daniel) — esta RPC (`manutencao_preditiva_kpis`
  // → `manutencao_preditiva_base`) recalcula vários componentes de
  // manutenção sobre TODO o histórico de abastecimentos/manutenções da
  // empresa (janelas, joins, unnest) e é sensivelmente mais pesada sob RLS
  // real do que os ~650ms medidos via bypass de service role — é a
  // principal suspeita de estourar o `statement_timeout` de 8s da role
  // `authenticated`. Aqui ela nunca mais derruba o resto do Dashboard; se
  // continuar demorando, o card de Manutenção Preditiva some (mostra o
  // resto normalmente) e vale otimizar a RPC em si depois.
  ManutencaoResumo? manutencao;
  try {
    final manutencaoRaw = await supabase.rpc('manutencao_preditiva_kpis', params: {
      'p_empresa_id': empresaId,
    }) as List;
    if (manutencaoRaw.isNotEmpty) {
      final m = manutencaoRaw.first as Map<String, dynamic>;
      manutencao = ManutencaoResumo(
        totalVeiculos: (m['total_veiculos'] as num?)?.toInt() ?? 0,
        totalCriticos: (m['total_criticos'] as num?)?.toInt() ?? 0,
        totalAlertas: (m['total_alertas'] as num?)?.toInt() ?? 0,
        scoreMedio: (m['score_medio'] as num?)?.toDouble() ?? 0,
      );
    }
  } catch (_) {
    manutencao = null;
  }

  final totalClientes = totalClientesResp.count;
  final clientesAtivos = clientesAtivosResp.count;
  final totalMotoristas = totalMotoristasResp.count;
  final motoristasAtivos = motoristasAtivosResp.count;
  // totalPostosProprios já foi resolvido acima (best effort, com fallback 0).

  // KPIs do mês atual.
  final doMesAtual = abastecimentosClienteRaw.where((a) {
    final m = a as Map<String, dynamic>;
    final data = DateTime.tryParse(m['data_abastecimento'] as String? ?? '');
    return data != null && !data.isBefore(inicioMesAtual);
  }).toList();
  var litrosMes = 0.0;
  var valorMes = 0.0;
  final porProvedorMes = <String, double>{};
  for (final a in doMesAtual) {
    final m = a as Map<String, dynamic>;
    final litros = (m['litros'] as num?)?.toDouble() ?? 0;
    final valor = (m['valor_total'] as num?)?.toDouble() ?? 0;
    litrosMes += litros;
    valorMes += valor;
    final provedor = m['provedor'] as String?;
    if (provedor != null) {
      porProvedorMes[provedor] = (porProvedorMes[provedor] ?? 0) + valor;
    }
  }
  final custoMedioLitroMes = litrosMes > 0 ? valorMes / litrosMes : 0.0;
  final provedoresMes = porProvedorMes.entries
      .map((e) => ProvedorValorMes(provedor: e.key, valor: e.value))
      .toList()
    ..sort((a, b) => b.valor.compareTo(a.valor));

  // Gráfico de consumo — agrupa por mês (últimos 6 meses, incluindo o
  // atual), na ordem certa mesmo com meses sem abastecimento.
  final porMes = <String, ({double litros, double valor})>{};
  final ordemMeses = <String>[];
  for (var i = _janelaConsumoMeses - 1; i >= 0; i--) {
    final d = DateTime(agora.year, agora.month - i, 1);
    final chave = '${d.year}-${d.month.toString().padLeft(2, '0')}';
    ordemMeses.add(chave);
    porMes[chave] = (litros: 0, valor: 0);
  }
  for (final a in abastecimentosClienteRaw) {
    final m = a as Map<String, dynamic>;
    final data = DateTime.tryParse(m['data_abastecimento'] as String? ?? '');
    if (data == null) continue;
    final chave = '${data.year}-${data.month.toString().padLeft(2, '0')}';
    final atual = porMes[chave];
    if (atual == null) continue; // fora da janela de 6 meses (não deve acontecer, já filtrado na query)
    porMes[chave] = (
      litros: atual.litros + ((m['litros'] as num?)?.toDouble() ?? 0),
      valor: atual.valor + ((m['valor_total'] as num?)?.toDouble() ?? 0),
    );
  }
  final serieConsumo = ordemMeses.map((chave) {
    final partes = chave.split('-');
    final mesIdx = int.parse(partes[1]) - 1;
    final anoAbrev = partes[0].substring(2);
    final p = porMes[chave]!;
    return PontoConsumoMensal(mesLabel: '${_mesesAbrev[mesIdx]}/$anoAbrev', litros: p.litros, valor: p.valor);
  }).toList();

  // CNH vencendo.
  final cnhVencendo = cnhVencendoRaw.map((m) {
    final mm = m as Map<String, dynamic>;
    return CnhVencendo(
      id: mm['id'] as String,
      nome: mm['nome_completo'] as String? ?? '—',
      vencimento: mm['cnh_vencimento'] as String,
    );
  }).toList();

  // Top 5 clientes por gasto (rede toda, sempre — mesmo espírito da web).
  final gastoPorEmpresa = <String, double>{};
  for (final a in abastecimentosRedeRaw) {
    final m = a as Map<String, dynamic>;
    final id = m['empresa_id'] as String?;
    if (id == null) continue;
    gastoPorEmpresa[id] = (gastoPorEmpresa[id] ?? 0) + ((m['valor_total'] as num?)?.toDouble() ?? 0);
  }
  final idsTop = gastoPorEmpresa.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final top5Ids = idsTop.take(5).toList();
  // Fase Perf-19-07 (achado do Daniel: "lentidão excessiva em muitos
  // pontos") — antes eram até 5 chamadas RPC individuais dentro deste loop
  // (uma por cliente do ranking). `nomes_empresas_publico` (mesma RPC já
  // usada na versão web) resolve todos de uma vez só.
  final nomesRows = top5Ids.isEmpty
      ? const []
      : await supabase.rpc('nomes_empresas_publico', params: {
          'p_empresa_ids': top5Ids.map((e) => e.key).toList(),
        }) as List;
  final nomePorId = <String, String?>{
    for (final r in nomesRows) (r as Map<String, dynamic>)['id'] as String: r['nome'] as String?,
  };
  final topClientes = top5Ids
      .map((entry) => ClienteGasto(nome: nomePorId[entry.key] ?? entry.key, valor: entry.value))
      .toList();

  return DashboardClienteDados(
    totalClientes: totalClientes,
    clientesAtivos: clientesAtivos,
    totalMotoristas: totalMotoristas,
    motoristasAtivos: motoristasAtivos,
    totalVeiculos: totalVeiculos,
    veiculosAtivos: veiculosAtivos,
    totalPostosProprios: totalPostosProprios,
    litrosMes: litrosMes,
    valorMes: valorMes,
    custoMedioLitroMes: custoMedioLitroMes,
    provedoresMes: provedoresMes,
    serieConsumo: serieConsumo,
    cnhVencendo: cnhVencendo,
    topClientes: topClientes,
    resumoAjustes: resumoAjustes,
    centroCusto: centroCusto,
    manutencao: manutencao,
  );
});
