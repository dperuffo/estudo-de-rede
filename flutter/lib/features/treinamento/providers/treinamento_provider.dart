import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../services/treinamento_service.dart';

final licoesTreinamentoProvider =
    FutureProvider.autoDispose<List<LicaoTreinamento>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  return TreinamentoService().buscarLicoes(sessao.perfil);
});
