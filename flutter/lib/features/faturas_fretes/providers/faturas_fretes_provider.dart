import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../services/faturas_fretes_service.dart';

final faturasFreteClienteProvider =
    FutureProvider.autoDispose<List<FaturaFrete>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  return FaturasFretesService().buscar(empresaId);
});

final tomadoresComPendentesProvider =
    FutureProvider.autoDispose<List<TomadorComPendentes>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  return FaturasFretesService().buscarTomadoresComPendentes(empresaId);
});
