import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase Indicadores-da-Frota (30/07/2026) — porta de indicadores-frota/page.tsx.
// RPC kpis_frota_resumo não é SECURITY DEFINER — roda com o privilégio de
// quem chama, protegida pela RLS de baixo, mesmo espírito de tco_provider.dart.

class KpisFrota {
  final int totalVeiculos, diasPeriodo, diasParadoTotal, diasDisponivelTotal, diasComMovimentoTotal;
  final double? disponibilidadePct, kmTotal, cpkOperacional, litrosTotal, mediaKmL, utilizacaoPct, pctCorretiva;
  final double custoOperacionalTotal, manutencaoPreventivaCusto, manutencaoCorretivaCusto, manutencaoNaoClassificadaCusto;
  const KpisFrota({
    required this.totalVeiculos,
    required this.diasPeriodo,
    required this.diasParadoTotal,
    required this.diasDisponivelTotal,
    required this.diasComMovimentoTotal,
    this.disponibilidadePct,
    this.kmTotal,
    this.cpkOperacional,
    this.litrosTotal,
    this.mediaKmL,
    this.utilizacaoPct,
    this.pctCorretiva,
    required this.custoOperacionalTotal,
    required this.manutencaoPreventivaCusto,
    required this.manutencaoCorretivaCusto,
    required this.manutencaoNaoClassificadaCusto,
  });
  factory KpisFrota.fromMap(Map<String, dynamic> m) => KpisFrota(
        totalVeiculos: (m['total_veiculos'] as num?)?.toInt() ?? 0,
        diasPeriodo: (m['dias_periodo'] as num?)?.toInt() ?? 0,
        diasParadoTotal: (m['dias_parado_total'] as num?)?.toInt() ?? 0,
        diasDisponivelTotal: (m['dias_disponivel_total'] as num?)?.toInt() ?? 0,
        diasComMovimentoTotal: (m['dias_com_movimento_total'] as num?)?.toInt() ?? 0,
        disponibilidadePct: (m['disponibilidade_pct'] as num?)?.toDouble(),
        kmTotal: (m['km_total'] as num?)?.toDouble(),
        cpkOperacional: (m['cpk_operacional'] as num?)?.toDouble(),
        litrosTotal: (m['litros_total'] as num?)?.toDouble(),
        mediaKmL: (m['media_km_l'] as num?)?.toDouble(),
        utilizacaoPct: (m['utilizacao_pct'] as num?)?.toDouble(),
        pctCorretiva: (m['pct_corretiva'] as num?)?.toDouble(),
        custoOperacionalTotal: (m['custo_operacional_total'] as num?)?.toDouble() ?? 0,
        manutencaoPreventivaCusto: (m['manutencao_preventiva_custo'] as num?)?.toDouble() ?? 0,
        manutencaoCorretivaCusto: (m['manutencao_corretiva_custo'] as num?)?.toDouble() ?? 0,
        manutencaoNaoClassificadaCusto: (m['manutencao_nao_classificada_custo'] as num?)?.toDouble() ?? 0,
      );
}

typedef FiltroKpisFrota = ({String dataInicio, String dataFim});

final kpisFrotaProvider = FutureProvider.autoDispose.family<KpisFrota?, FiltroKpisFrota>((ref, filtro) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return null;
  final rows = await SupabaseService.client.rpc('kpis_frota_resumo', params: {
    'p_empresa_id': empresaId,
    'p_data_inicio': filtro.dataInicio,
    'p_data_fim': filtro.dataFim,
  }) as List;
  if (rows.isEmpty) return null;
  return KpisFrota.fromMap(rows.first as Map<String, dynamic>);
});
