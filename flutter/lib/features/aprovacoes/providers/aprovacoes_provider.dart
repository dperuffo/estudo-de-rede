import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../services/aprovacoes_service.dart';

final aprovacoesClienteProvider =
    FutureProvider.autoDispose<List<SolicitacaoAprovacao>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  return AprovacoesService().buscar(empresaId);
});

final aprovacoesAprovadasManutencaoProvider =
    FutureProvider.autoDispose<List<SolicitacaoAprovacao>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  return AprovacoesService().buscarAprovadasDeManutencao(empresaId);
});
