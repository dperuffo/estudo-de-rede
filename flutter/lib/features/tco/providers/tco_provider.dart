import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase TCO (29/07/2026) — Custo Total de Propriedade por veículo (cliente),
// porta de tco/page.tsx + tco/[placa]/page.tsx. RPCs tco_frota_resumo/
// tco_veiculo não são SECURITY DEFINER — rodam com o privilégio de quem
// chama, protegidas pela RLS de baixo (cadastro_veiculos,
// abastecimentos_unificado, manutencoes_realizadas, multas, contas_pagar,
// custos_fixos), mesmo espírito de manutencao_preditiva_provider.dart.

class VeiculoResumoTco {
  final String placa;
  final String? marca, modelo, centroCustoId, centroCustoNome;
  final int? anoFabricacao;
  final double? valorAquisicao, kmPeriodo, custoPorKm, custoDepreciacao, custoCapital;
  final double custoCombustivel, custoManutencao, custoMultas, custoOficinas, custoFixos, tcoTotal;
  // Fase TCO 2 (29/07/2026) — 'fipe_curva_real' | 'linear_estimado' | null.
  final String? fonteDepreciacao;
  final bool tcoCompleto;
  final int totalCount;
  const VeiculoResumoTco({
    required this.placa,
    this.marca,
    this.modelo,
    this.centroCustoId,
    this.centroCustoNome,
    this.anoFabricacao,
    this.valorAquisicao,
    this.kmPeriodo,
    this.custoPorKm,
    this.custoDepreciacao,
    this.custoCapital,
    this.fonteDepreciacao,
    required this.custoCombustivel,
    required this.custoManutencao,
    required this.custoMultas,
    required this.custoOficinas,
    required this.custoFixos,
    required this.tcoTotal,
    required this.tcoCompleto,
    required this.totalCount,
  });
  factory VeiculoResumoTco.fromMap(Map<String, dynamic> m) => VeiculoResumoTco(
        placa: m['placa'] as String,
        marca: m['marca'] as String?,
        modelo: m['modelo'] as String?,
        centroCustoId: m['centro_custo_id'] as String?,
        centroCustoNome: m['centro_custo_nome'] as String?,
        anoFabricacao: (m['ano_fabricacao'] as num?)?.toInt(),
        valorAquisicao: (m['valor_aquisicao'] as num?)?.toDouble(),
        kmPeriodo: (m['km_periodo'] as num?)?.toDouble(),
        custoPorKm: (m['custo_por_km'] as num?)?.toDouble(),
        custoDepreciacao: (m['custo_depreciacao'] as num?)?.toDouble(),
        custoCapital: (m['custo_capital'] as num?)?.toDouble(),
        fonteDepreciacao: m['fonte_depreciacao'] as String?,
        custoCombustivel: (m['custo_combustivel'] as num?)?.toDouble() ?? 0,
        custoManutencao: (m['custo_manutencao'] as num?)?.toDouble() ?? 0,
        custoMultas: (m['custo_multas'] as num?)?.toDouble() ?? 0,
        custoOficinas: (m['custo_oficinas'] as num?)?.toDouble() ?? 0,
        custoFixos: (m['custo_fixos'] as num?)?.toDouble() ?? 0,
        tcoTotal: (m['tco_total'] as num?)?.toDouble() ?? 0,
        tcoCompleto: m['tco_completo'] as bool? ?? false,
        totalCount: (m['total_count'] as num?)?.toInt() ?? 0,
      );
}

// Filtros da listagem — record (equality estrutural, chave de family).
typedef FiltrosTco = ({
  String? busca,
  String? centroCustoId,
  String ordenar,
  int pagina,
  String dataInicio,
  String dataFim,
});

const _tamanhoPaginaTco = 50;

final tcoResumoProvider = FutureProvider.autoDispose.family<List<VeiculoResumoTco>, FiltrosTco>((ref, filtros) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client.rpc('tco_frota_resumo', params: {
    'p_empresa_id': empresaId,
    'p_data_inicio': filtros.dataInicio,
    'p_data_fim': filtros.dataFim,
    'p_centro_custo_id': filtros.centroCustoId,
    'p_busca': (filtros.busca == null || filtros.busca!.trim().isEmpty) ? null : filtros.busca!.trim(),
    'p_ordenar': filtros.ordenar,
    'p_limit': _tamanhoPaginaTco,
    'p_offset': (filtros.pagina - 1) * _tamanhoPaginaTco,
  }) as List;
  return rows.map((r) => VeiculoResumoTco.fromMap(r as Map<String, dynamic>)).toList();
});

class VeiculoDetalheTco {
  final String placa;
  final String? marca, modelo, centroCustoNome, dataAquisicao, codigoFipe;
  final int? anoFabricacao;
  final double? valorAquisicao, valorResidualEstimado, valorFipe, kmPeriodo, custoPorKm, custoDepreciacao, custoCapital;
  final double custoCombustivel, custoManutencao, custoMultas, custoOficinas, custoFixos, tcoTotal;
  // Fase TCO 2 (29/07/2026) — 'fipe_curva_real' | 'linear_estimado' | null.
  final String? fonteDepreciacao;
  final bool tcoCompleto;
  const VeiculoDetalheTco({
    required this.placa,
    this.marca,
    this.modelo,
    this.centroCustoNome,
    this.dataAquisicao,
    this.codigoFipe,
    this.anoFabricacao,
    this.valorAquisicao,
    this.valorResidualEstimado,
    this.valorFipe,
    this.kmPeriodo,
    this.custoPorKm,
    this.custoDepreciacao,
    this.custoCapital,
    this.fonteDepreciacao,
    required this.custoCombustivel,
    required this.custoManutencao,
    required this.custoMultas,
    required this.custoOficinas,
    required this.custoFixos,
    required this.tcoTotal,
    required this.tcoCompleto,
  });
  factory VeiculoDetalheTco.fromMap(Map<String, dynamic> m) => VeiculoDetalheTco(
        placa: m['placa'] as String,
        marca: m['marca'] as String?,
        modelo: m['modelo'] as String?,
        centroCustoNome: m['centro_custo_nome'] as String?,
        dataAquisicao: m['data_aquisicao'] as String?,
        codigoFipe: m['codigo_fipe'] as String?,
        anoFabricacao: (m['ano_fabricacao'] as num?)?.toInt(),
        valorAquisicao: (m['valor_aquisicao'] as num?)?.toDouble(),
        valorResidualEstimado: (m['valor_residual_estimado'] as num?)?.toDouble(),
        valorFipe: (m['valor_fipe'] as num?)?.toDouble(),
        kmPeriodo: (m['km_periodo'] as num?)?.toDouble(),
        custoPorKm: (m['custo_por_km'] as num?)?.toDouble(),
        custoDepreciacao: (m['custo_depreciacao'] as num?)?.toDouble(),
        custoCapital: (m['custo_capital'] as num?)?.toDouble(),
        fonteDepreciacao: m['fonte_depreciacao'] as String?,
        custoCombustivel: (m['custo_combustivel'] as num?)?.toDouble() ?? 0,
        custoManutencao: (m['custo_manutencao'] as num?)?.toDouble() ?? 0,
        custoMultas: (m['custo_multas'] as num?)?.toDouble() ?? 0,
        custoOficinas: (m['custo_oficinas'] as num?)?.toDouble() ?? 0,
        custoFixos: (m['custo_fixos'] as num?)?.toDouble() ?? 0,
        tcoTotal: (m['tco_total'] as num?)?.toDouble() ?? 0,
        tcoCompleto: m['tco_completo'] as bool? ?? false,
      );
}

typedef FiltroDetalheTco = ({String placa, String dataInicio, String dataFim});

final tcoDetalheProvider = FutureProvider.autoDispose.family<VeiculoDetalheTco?, FiltroDetalheTco>((ref, filtro) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return null;
  final rows = await SupabaseService.client.rpc('tco_veiculo', params: {
    'p_empresa_id': empresaId,
    'p_placa': filtro.placa,
    'p_data_inicio': filtro.dataInicio,
    'p_data_fim': filtro.dataFim,
  }) as List;
  if (rows.isEmpty) return null;
  return VeiculoDetalheTco.fromMap(rows.first as Map<String, dynamic>);
});
