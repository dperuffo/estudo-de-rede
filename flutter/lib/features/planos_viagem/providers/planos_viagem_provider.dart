import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — Planos de Viagem (cliente), porta de
// planos-viagem/page.tsx + novo/page.tsx + [id]/editar/page.tsx +
// _components/PlanoViagemForm.tsx + actions.ts. RLS conferida antes de
// portar: `planos_viagem` e `planos_viagem_pedagios` têm self-service
// completo por `empresa_id` (ALL) — CRUD direto, sem RPC, igual à web.
// `combustivel_real_periodo` (usada no botão "Revisar" combustível real)
// não é SECURITY DEFINER — roda com o RLS do próprio usuário sobre
// `abastecimentos_unificado`, então pode ser chamada direto do app.
//
// Fora do escopo: seletor de cliente na listagem/criação (a visão cliente
// sempre usa `sessao.empresaId`, mesmo padrão do resto do app — só o
// perfil admin vê múltiplos clientes na web, e essa separação admin x
// cliente segue fora de escopo geral do FLT-3); "Importar de uma rota
// salva" (campo `rota_salva_id`/dropdown `rotasSalvas` do form) — depende
// de `rotas_salvas`, já fora do escopo da Roteirização portada (mesmo
// motivo documentado em roteirizacao_provider.dart e
// rotograma_provider.dart); coluna "Cliente" na tabela (só aparece pra
// admin vendo vários clientes ao mesmo tempo).

const statusPlanoViagem = ['rascunho', 'planejado', 'em_andamento', 'concluido', 'cancelado'];
const statusPlanoViagemLabel = {
  'rascunho': 'Rascunho',
  'planejado': 'Planejado',
  'em_andamento': 'Em andamento',
  'concluido': 'Concluído',
  'cancelado': 'Cancelado',
};

class Pedagio {
  final String pracaNome;
  final double valor;
  const Pedagio({required this.pracaNome, required this.valor});

  factory Pedagio.fromMap(Map<String, dynamic> m) => Pedagio(
        pracaNome: m['praca_nome'] as String? ?? '',
        valor: (m['valor'] as num?)?.toDouble() ?? 0,
      );
}

class PlanoViagem {
  final String id;
  final String empresaId;
  final String nome;
  final String status;
  final String? placa;
  final String? motoristaId;
  final String? motoristaNome;
  final String? rotogramaId;
  final String? centroCustoId;
  final String? dataSaida;
  final String? retornoPrevisto;
  final double kmEstimado;
  final double consumoKmL;
  final double precoCombustivel;
  final double custoCombustivelEstimado;
  final double? custoCombustivelReal;
  final double? combustivelRealLitros;
  final String? combustivelRealRevisadoEm;
  final int nDiarias;
  final double valorRefeicaoDia;
  final double valorPernoiteDia;
  final double valorBanhoDia;
  final double valorLavagemDia;
  final double custoDiarias;
  final double custoManutencaoKm;
  final double custoManutencaoEstimado;
  final double receitaViagem;
  final double pedagiosTotal;
  final double custoTotalEstimado;
  final double? custoTotalReal;
  final String? observacoes;

  const PlanoViagem({
    required this.id,
    required this.empresaId,
    required this.nome,
    required this.status,
    this.placa,
    this.motoristaId,
    this.motoristaNome,
    this.rotogramaId,
    this.centroCustoId,
    this.dataSaida,
    this.retornoPrevisto,
    required this.kmEstimado,
    required this.consumoKmL,
    required this.precoCombustivel,
    required this.custoCombustivelEstimado,
    this.custoCombustivelReal,
    this.combustivelRealLitros,
    this.combustivelRealRevisadoEm,
    required this.nDiarias,
    required this.valorRefeicaoDia,
    required this.valorPernoiteDia,
    required this.valorBanhoDia,
    required this.valorLavagemDia,
    required this.custoDiarias,
    required this.custoManutencaoKm,
    required this.custoManutencaoEstimado,
    required this.receitaViagem,
    required this.pedagiosTotal,
    required this.custoTotalEstimado,
    this.custoTotalReal,
    this.observacoes,
  });

  double get margemEstimada => receitaViagem - custoTotalEstimado;
  double? get margemReal => custoTotalReal != null ? receitaViagem - custoTotalReal! : null;

  factory PlanoViagem.fromMap(Map<String, dynamic> m) {
    final motorista = m['motoristas'] as Map<String, dynamic>?;
    num? n(String k) => m[k] as num?;
    return PlanoViagem(
      id: m['id'] as String,
      empresaId: m['empresa_id'] as String? ?? '',
      nome: m['nome'] as String? ?? '',
      status: m['status'] as String? ?? 'rascunho',
      placa: m['placa'] as String?,
      motoristaId: m['motorista_id'] as String?,
      motoristaNome: motorista?['nome_completo'] as String?,
      rotogramaId: m['rotograma_id'] as String?,
      centroCustoId: m['centro_custo_id'] as String?,
      dataSaida: m['data_saida'] as String?,
      retornoPrevisto: m['retorno_previsto'] as String?,
      kmEstimado: (n('km_estimado') ?? 0).toDouble(),
      consumoKmL: (n('consumo_km_l') ?? 0).toDouble(),
      precoCombustivel: (n('preco_combustivel') ?? 0).toDouble(),
      custoCombustivelEstimado: (n('custo_combustivel_estimado') ?? 0).toDouble(),
      custoCombustivelReal: n('custo_combustivel_real')?.toDouble(),
      combustivelRealLitros: n('combustivel_real_litros')?.toDouble(),
      combustivelRealRevisadoEm: m['combustivel_real_revisado_em'] as String?,
      nDiarias: (n('n_diarias') ?? 0).toInt(),
      valorRefeicaoDia: (n('valor_refeicao_dia') ?? 0).toDouble(),
      valorPernoiteDia: (n('valor_pernoite_dia') ?? 0).toDouble(),
      valorBanhoDia: (n('valor_banho_dia') ?? 0).toDouble(),
      valorLavagemDia: (n('valor_lavagem_dia') ?? 0).toDouble(),
      custoDiarias: (n('custo_diarias') ?? 0).toDouble(),
      custoManutencaoKm: (n('custo_manutencao_km') ?? 0).toDouble(),
      custoManutencaoEstimado: (n('custo_manutencao_estimado') ?? 0).toDouble(),
      receitaViagem: (n('receita_viagem') ?? 0).toDouble(),
      pedagiosTotal: (n('pedagios_total') ?? 0).toDouble(),
      custoTotalEstimado: (n('custo_total_estimado') ?? 0).toDouble(),
      custoTotalReal: n('custo_total_real')?.toDouble(),
      observacoes: m['observacoes'] as String?,
    );
  }
}

// Filtros da listagem — record como chave de family (mesmo padrão já usado
// em manutencao_preditiva_provider.dart), dá igualdade estrutural de graça.
typedef FiltrosPlanosViagem = ({String? status, String? placa});

final planosViagemListaProvider =
    FutureProvider.autoDispose.family<List<PlanoViagem>, FiltrosPlanosViagem>((ref, filtros) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];

  var query = SupabaseService.client
      .from('planos_viagem')
      .select(
          'id, empresa_id, nome, status, placa, motorista_id, motoristas(nome_completo), rotograma_id, centro_custo_id, '
          'data_saida, retorno_previsto, km_estimado, consumo_km_l, preco_combustivel, custo_combustivel_estimado, '
          'custo_combustivel_real, combustivel_real_litros, combustivel_real_revisado_em, n_diarias, valor_refeicao_dia, '
          'valor_pernoite_dia, valor_banho_dia, valor_lavagem_dia, custo_diarias, custo_manutencao_km, '
          'custo_manutencao_estimado, receita_viagem, pedagios_total, custo_total_estimado, custo_total_real, observacoes')
      .eq('empresa_id', empresaId);

  if (filtros.status != null && filtros.status!.isNotEmpty) {
    query = query.eq('status', filtros.status!);
  }
  if (filtros.placa != null && filtros.placa!.trim().isNotEmpty) {
    query = query.ilike('placa', '%${filtros.placa!.trim()}%');
  }

  final rows = await query.order('criado_em', ascending: false).limit(500) as List;
  return rows.map((r) => PlanoViagem.fromMap(r as Map<String, dynamic>)).toList();
});

// KPIs sobre o resultado já filtrado — mesmo cálculo do page.tsx.
class KpisPlanosViagem {
  final int totalPlanos;
  final double orcamentoTotalEstimado;
  final double receitaTotal;
  final double margemEstimada;
  final double custoMedioPorKm;
  const KpisPlanosViagem({
    required this.totalPlanos,
    required this.orcamentoTotalEstimado,
    required this.receitaTotal,
    required this.margemEstimada,
    required this.custoMedioPorKm,
  });
}

KpisPlanosViagem calcularKpisPlanos(List<PlanoViagem> planos) {
  final totalPlanos = planos.length;
  final orcamentoTotalEstimado = planos.fold<double>(0, (s, p) => s + p.custoTotalEstimado);
  final receitaTotal = planos.fold<double>(0, (s, p) => s + p.receitaViagem);
  final margemEstimada = receitaTotal - orcamentoTotalEstimado;
  final kmTotalEstimado = planos.fold<double>(0, (s, p) => s + p.kmEstimado);
  final custoMedioPorKm = kmTotalEstimado > 0 ? orcamentoTotalEstimado / kmTotalEstimado : 0.0;
  return KpisPlanosViagem(
    totalPlanos: totalPlanos,
    orcamentoTotalEstimado: orcamentoTotalEstimado,
    receitaTotal: receitaTotal,
    margemEstimada: margemEstimada,
    custoMedioPorKm: custoMedioPorKm,
  );
}

class DesempenhoVeiculo {
  final String placa;
  final int planos;
  final double km;
  final double custo;
  const DesempenhoVeiculo({required this.placa, required this.planos, required this.km, required this.custo});
}

// "Desempenho por Veículo" — agrupado em memória, mesmo espírito do
// page.tsx (volume baixo, sem necessidade de RPC dedicado).
List<DesempenhoVeiculo> agruparPorVeiculo(List<PlanoViagem> planos) {
  final mapa = <String, DesempenhoVeiculo>{};
  for (final p in planos) {
    final placa = p.placa;
    if (placa == null || placa.isEmpty) continue;
    final atual = mapa[placa] ?? DesempenhoVeiculo(placa: placa, planos: 0, km: 0, custo: 0);
    mapa[placa] = DesempenhoVeiculo(
      placa: placa,
      planos: atual.planos + 1,
      km: atual.km + p.kmEstimado,
      custo: atual.custo + p.custoTotalEstimado,
    );
  }
  final lista = mapa.values.toList()..sort((a, b) => b.custo.compareTo(a.custo));
  return lista;
}

final planoViagemDetalheProvider = FutureProvider.autoDispose.family<PlanoViagem?, String>((ref, id) async {
  final row = await SupabaseService.client.from('planos_viagem').select('*').eq('id', id).maybeSingle();
  if (row == null) return null;
  return PlanoViagem.fromMap(row);
});

final pedagiosPlanoProvider = FutureProvider.autoDispose.family<List<Pedagio>, String>((ref, planoId) async {
  final rows = await SupabaseService.client
      .from('planos_viagem_pedagios')
      .select('praca_nome, valor')
      .eq('plano_viagem_id', planoId)
      .order('ordem') as List;
  return rows.map((r) => Pedagio.fromMap(r as Map<String, dynamic>)).toList();
});
