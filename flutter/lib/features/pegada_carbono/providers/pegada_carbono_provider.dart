import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase Onda-3 (benchmark TicketLog, item #10) — porta de
// pegada-carbono/page.tsx (web). Pedido do Daniel: "Implementar estas duas
// iniciativas na web e PWA cliente".
class ItemPegadaCarbono {
  final String categoria;
  final double litrosTotal;
  final double? fatorKgCo2PorLitro;
  final double? co2EstimadoKg;
  const ItemPegadaCarbono({
    required this.categoria,
    required this.litrosTotal,
    required this.fatorKgCo2PorLitro,
    required this.co2EstimadoKg,
  });

  factory ItemPegadaCarbono.fromMap(Map<String, dynamic> m) => ItemPegadaCarbono(
        categoria: m['categoria'] as String,
        litrosTotal: (m['litros_total'] as num?)?.toDouble() ?? 0,
        fatorKgCo2PorLitro: (m['fator_kg_co2_por_litro'] as num?)?.toDouble(),
        co2EstimadoKg: (m['co2_estimado_kg'] as num?)?.toDouble(),
      );
}

class FiltroPeriodoCarbono {
  final DateTime inicio;
  final DateTime fim;
  const FiltroPeriodoCarbono({required this.inicio, required this.fim});

  @override
  bool operator ==(Object other) =>
      other is FiltroPeriodoCarbono && other.inicio == inicio && other.fim == fim;
  @override
  int get hashCode => Object.hash(inicio, fim);
}

FiltroPeriodoCarbono periodoPadraoCarbono() {
  final hoje = DateTime.now();
  return FiltroPeriodoCarbono(inicio: hoje.subtract(const Duration(days: 90)), fim: hoje);
}

String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

final pegadaCarbonoProvider =
    FutureProvider.autoDispose.family<List<ItemPegadaCarbono>, FiltroPeriodoCarbono>((ref, periodo) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];

  final rows = await SupabaseService.client.rpc('pegada_carbono_periodo', params: {
    'p_empresa_id': empresaId,
    'p_data_inicio': _iso(periodo.inicio),
    'p_data_fim': _iso(periodo.fim),
  }) as List;
  return rows.map((r) => ItemPegadaCarbono.fromMap(r as Map<String, dynamic>)).toList();
});
