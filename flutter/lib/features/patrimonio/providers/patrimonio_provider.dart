import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase Grupo 2 (Rodopar/Datapar, item 6, 03/08/2026) — Patrimônio formal:
// depreciação contábil (linha reta pela vida útil) e correções do ativo
// (reavaliação/melhoria/baixa), complementando o TCO (que usa depreciação
// ECONÔMICA via curva FIPE só pra custo/km). Porta de /patrimonio e
// /patrimonio/[placa] (web). RPCs patrimonio_veiculo/patrimonio_frota_resumo
// não são SECURITY DEFINER — mesmo espírito de tco_provider.dart.

class VeiculoPatrimonio {
  final String placa;
  final String? marca,
      modelo,
      centroCustoId,
      centroCustoNome,
      dataAquisicao,
      dataBaixa;
  final int? anoFabricacao, mesesDecorridos;
  final int mesesVidaUtil;
  final double? valorAquisicao,
      valorResidualEstimado,
      depreciacaoAcumulada,
      valorContabilLiquido,
      percentualDepreciado,
      valorBaixa;
  final double vidaUtilAnos, valorMelhorias, valorReavaliacoes, baseDepreciavel;
  final bool baixado, patrimonioCompleto;
  final int totalCount;

  const VeiculoPatrimonio({
    required this.placa,
    this.marca,
    this.modelo,
    this.centroCustoId,
    this.centroCustoNome,
    this.dataAquisicao,
    this.dataBaixa,
    this.anoFabricacao,
    this.mesesDecorridos,
    required this.mesesVidaUtil,
    this.valorAquisicao,
    this.valorResidualEstimado,
    this.depreciacaoAcumulada,
    this.valorContabilLiquido,
    this.percentualDepreciado,
    this.valorBaixa,
    required this.vidaUtilAnos,
    required this.valorMelhorias,
    required this.valorReavaliacoes,
    required this.baseDepreciavel,
    required this.baixado,
    required this.patrimonioCompleto,
    this.totalCount = 0,
  });

  factory VeiculoPatrimonio.fromMap(Map<String, dynamic> m) =>
      VeiculoPatrimonio(
        placa: m['placa'] as String,
        marca: m['marca'] as String?,
        modelo: m['modelo'] as String?,
        centroCustoId: m['centro_custo_id'] as String?,
        centroCustoNome: m['centro_custo_nome'] as String?,
        dataAquisicao: m['data_aquisicao'] as String?,
        dataBaixa: m['data_baixa'] as String?,
        anoFabricacao: (m['ano_fabricacao'] as num?)?.toInt(),
        mesesDecorridos: (m['meses_decorridos'] as num?)?.toInt(),
        mesesVidaUtil: (m['meses_vida_util'] as num?)?.toInt() ?? 60,
        valorAquisicao: (m['valor_aquisicao'] as num?)?.toDouble(),
        valorResidualEstimado:
            (m['valor_residual_estimado'] as num?)?.toDouble(),
        depreciacaoAcumulada: (m['depreciacao_acumulada'] as num?)?.toDouble(),
        valorContabilLiquido: (m['valor_contabil_liquido'] as num?)?.toDouble(),
        percentualDepreciado: (m['percentual_depreciado'] as num?)?.toDouble(),
        valorBaixa: (m['valor_baixa'] as num?)?.toDouble(),
        vidaUtilAnos: (m['vida_util_anos'] as num?)?.toDouble() ?? 5,
        valorMelhorias: (m['valor_melhorias'] as num?)?.toDouble() ?? 0,
        valorReavaliacoes: (m['valor_reavaliacoes'] as num?)?.toDouble() ?? 0,
        baseDepreciavel: (m['base_depreciavel'] as num?)?.toDouble() ?? 0,
        baixado: m['baixado'] as bool? ?? false,
        patrimonioCompleto: m['patrimonio_completo'] as bool? ?? false,
        totalCount: (m['total_count'] as num?)?.toInt() ?? 0,
      );
}

typedef FiltrosPatrimonio = ({String? busca, String ordenar});

final patrimonioResumoProvider = FutureProvider.autoDispose
    .family<List<VeiculoPatrimonio>, FiltrosPatrimonio>((ref, filtros) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows =
      await SupabaseService.client.rpc('patrimonio_frota_resumo', params: {
    'p_empresa_id': empresaId,
    'p_busca': (filtros.busca == null || filtros.busca!.trim().isEmpty)
        ? null
        : filtros.busca!.trim(),
    'p_ordenar': filtros.ordenar.isEmpty ? null : filtros.ordenar,
  }) as List;
  return rows
      .map((r) => VeiculoPatrimonio.fromMap(r as Map<String, dynamic>))
      .toList();
});

final patrimonioVeiculoProvider = FutureProvider.autoDispose
    .family<VeiculoPatrimonio?, String>((ref, placa) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return null;
  final rows = await SupabaseService.client.rpc('patrimonio_veiculo', params: {
    'p_empresa_id': empresaId,
    'p_placa': placa,
  }) as List;
  if (rows.isEmpty) return null;
  return VeiculoPatrimonio.fromMap(rows.first as Map<String, dynamic>);
});

// Resolve o id (uuid) do veículo a partir da placa — a RPC não devolve, mas
// patrimonio_ajustes.veiculo_id é FK e precisa dele pra criar/listar ajustes.
final patrimonioVeiculoIdProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, placa) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return null;
  final empresa = await SupabaseService.client
      .from('empresas')
      .select('cnpj')
      .eq('id', empresaId)
      .maybeSingle();
  final cnpjEmpresa = _normalizarCnpj(empresa?['cnpj'] as String?);
  final candidatos = await SupabaseService.client
      .from('cadastro_veiculos')
      .select('id, cnpj_frota')
      .eq('placa', placa) as List;
  for (final c in candidatos) {
    final row = c as Map<String, dynamic>;
    if (_normalizarCnpj(row['cnpj_frota'] as String?) == cnpjEmpresa)
      return row['id'] as String;
  }
  return null;
});

String _normalizarCnpj(String? v) =>
    (v ?? '').replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();

class AjustePatrimonio {
  final String id;
  final String tipo;
  final double valor;
  final String dataAjuste;
  final String? motivo;

  const AjustePatrimonio(
      {required this.id,
      required this.tipo,
      required this.valor,
      required this.dataAjuste,
      this.motivo});

  factory AjustePatrimonio.fromMap(Map<String, dynamic> m) => AjustePatrimonio(
        id: m['id'] as String,
        tipo: m['tipo'] as String,
        valor: (m['valor'] as num).toDouble(),
        dataAjuste: m['data_ajuste'] as String,
        motivo: m['motivo'] as String?,
      );
}

final ajustesPatrimonioProvider = FutureProvider.autoDispose
    .family<List<AjustePatrimonio>, String>((ref, veiculoId) async {
  final rows = await SupabaseService.client
      .from('patrimonio_ajustes')
      .select('id, tipo, valor, data_ajuste, motivo')
      .eq('veiculo_id', veiculoId)
      .order('data_ajuste', ascending: false) as List;
  return rows
      .map((r) => AjustePatrimonio.fromMap(r as Map<String, dynamic>))
      .toList();
});
