import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../services/pneus_service.dart';

// Mesmo padrão de veiculoDetalheProvider (features/veiculos/providers) —
// usado só pra pré-preencher o form de edição a partir do id da rota
// (/pneus/:id/editar), sem duplicar a busca da lista principal.
final pneusClienteProvider =
    FutureProvider.autoDispose<List<Pneu>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  return PneusService().buscar(empresaId);
});

final pneuDetalheProvider =
    FutureProvider.autoDispose.family<Pneu?, String>((ref, id) async {
  final lista = await ref.watch(pneusClienteProvider.future);
  for (final p in lista) {
    if (p.id == id) return p;
  }
  return null;
});
