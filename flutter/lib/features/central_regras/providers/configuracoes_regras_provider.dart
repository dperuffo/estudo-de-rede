import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../services/configuracoes_regras_service.dart';

final configuracoesRegrasOverridesProvider =
    FutureProvider.autoDispose<Map<String, double>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return {};
  return ConfiguracoesRegrasService().buscarOverrides(empresaId);
});
