import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase Onda-2 (benchmark TicketLog, item #6 — "Comparador combustível ideal
// por região") — pedido do Daniel: "Implementar estas duas iniciativas na
// web e PWA cliente". Porta de combustivel-ideal/page.tsx (web): mesma RPC
// comparador_combustivel_ideal, mesmo padrão simples de
// indicadores_avancados_provider.dart (sem service próprio, é só leitura).
class ItemComparadorCombustivel {
  final String placa;
  final String? marca;
  final String? modelo;
  final String? uf;
  final double? rendimentoGasolina;
  final double? rendimentoEtanol;
  final bool rendimentoEstimado;
  final double? precoGasolina;
  final double? precoEtanol;
  final String? precoFonte;
  final double? custoKmGasolina;
  final double? custoKmEtanol;
  final String? recomendacao; // 'etanol' | 'gasolina' | null
  final double? economiaPct;

  const ItemComparadorCombustivel({
    required this.placa,
    required this.marca,
    required this.modelo,
    required this.uf,
    required this.rendimentoGasolina,
    required this.rendimentoEtanol,
    required this.rendimentoEstimado,
    required this.precoGasolina,
    required this.precoEtanol,
    required this.precoFonte,
    required this.custoKmGasolina,
    required this.custoKmEtanol,
    required this.recomendacao,
    required this.economiaPct,
  });

  factory ItemComparadorCombustivel.fromMap(Map<String, dynamic> m) {
    return ItemComparadorCombustivel(
      placa: m['placa'] as String,
      marca: m['marca'] as String?,
      modelo: m['modelo'] as String?,
      uf: m['uf'] as String?,
      rendimentoGasolina: (m['rendimento_gasolina'] as num?)?.toDouble(),
      rendimentoEtanol: (m['rendimento_etanol'] as num?)?.toDouble(),
      rendimentoEstimado: m['rendimento_estimado'] as bool? ?? false,
      precoGasolina: (m['preco_gasolina'] as num?)?.toDouble(),
      precoEtanol: (m['preco_etanol'] as num?)?.toDouble(),
      precoFonte: m['preco_fonte'] as String?,
      custoKmGasolina: (m['custo_km_gasolina'] as num?)?.toDouble(),
      custoKmEtanol: (m['custo_km_etanol'] as num?)?.toDouble(),
      recomendacao: m['recomendacao'] as String?,
      economiaPct: (m['economia_pct'] as num?)?.toDouble(),
    );
  }
}

final combustivelIdealProvider = FutureProvider.autoDispose<List<ItemComparadorCombustivel>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];

  final rows = await SupabaseService.client
      .rpc('comparador_combustivel_ideal', params: {'p_empresa_id': empresaId}) as List;
  return rows.map((r) => ItemComparadorCombustivel.fromMap(r as Map<String, dynamic>)).toList();
});
