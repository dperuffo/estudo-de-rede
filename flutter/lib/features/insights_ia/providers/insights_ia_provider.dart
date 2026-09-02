import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../services/insights_ia_service.dart';

final insightsIaListaProvider =
    FutureProvider.autoDispose<List<InsightIA>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  return InsightsIaService().listar(empresaId);
});

final insightsIaAcessoProvider = FutureProvider.autoDispose<bool>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return false;
  return InsightsIaService().temAcessoPorPlano(empresaId, sessao.perfil);
});
