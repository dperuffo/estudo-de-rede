import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../services/apolices_seguro_service.dart';

// Mesmo padrão de pneuDetalheProvider — usado só pra pré-preencher o form
// de edição a partir do id da rota (/apolices-seguro/:id/editar).
final apolicesSeguroClienteProvider =
    FutureProvider.autoDispose<List<ApoliceSeguro>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  return ApolicesSeguroService().buscar(empresaId);
});

final apoliceSeguroDetalheProvider = FutureProvider.autoDispose
    .family<ApoliceSeguro?, String>((ref, id) async {
  final lista = await ref.watch(apolicesSeguroClienteProvider.future);
  for (final a in lista) {
    if (a.id == id) return a;
  }
  return null;
});
