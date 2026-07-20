import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Pedido do Daniel: "Aba de combustível ideal tem que estar disponível
// para a família Diesel também. Mostrar se vale a pena utilizar o Diesel
// S10, o S10 aditivado, assim como o S500 e o S500 aditivado". Porta de
// ListaVeiculosDieselIdeal.tsx (web) — mesma RPC comparador_diesel_ideal.
class ItemComparadorDiesel {
  final String placa;
  final String? marca;
  final String? modelo;
  final String? uf;
  final String familia; // 'S10' | 'S500'
  final double? precoComum;
  final double? precoAditivado;
  final String? precoFonte;
  final double? rendimentoComum;
  final double? rendimentoAditivado;
  final double? custoKmComum;
  final double? custoKmAditivado;
  final String? recomendacao; // 'aditivado' | 'comum' | null
  final double? premioAditivadoPct;

  const ItemComparadorDiesel({
    required this.placa,
    required this.marca,
    required this.modelo,
    required this.uf,
    required this.familia,
    required this.precoComum,
    required this.precoAditivado,
    required this.precoFonte,
    required this.rendimentoComum,
    required this.rendimentoAditivado,
    required this.custoKmComum,
    required this.custoKmAditivado,
    required this.recomendacao,
    required this.premioAditivadoPct,
  });

  factory ItemComparadorDiesel.fromMap(Map<String, dynamic> m) {
    return ItemComparadorDiesel(
      placa: m['placa'] as String,
      marca: m['marca'] as String?,
      modelo: m['modelo'] as String?,
      uf: m['uf'] as String?,
      familia: m['familia'] as String,
      precoComum: (m['preco_comum'] as num?)?.toDouble(),
      precoAditivado: (m['preco_aditivado'] as num?)?.toDouble(),
      precoFonte: m['preco_fonte'] as String?,
      rendimentoComum: (m['rendimento_comum'] as num?)?.toDouble(),
      rendimentoAditivado: (m['rendimento_aditivado'] as num?)?.toDouble(),
      custoKmComum: (m['custo_km_comum'] as num?)?.toDouble(),
      custoKmAditivado: (m['custo_km_aditivado'] as num?)?.toDouble(),
      recomendacao: m['recomendacao'] as String?,
      premioAditivadoPct: (m['premio_aditivado_pct'] as num?)?.toDouble(),
    );
  }
}

final dieselIdealProvider = FutureProvider.autoDispose<List<ItemComparadorDiesel>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];

  final rows = await SupabaseService.client.rpc('comparador_diesel_ideal', params: {'p_empresa_id': empresaId}) as List;
  return rows.map((r) => ItemComparadorDiesel.fromMap(r as Map<String, dynamic>)).toList();
});
