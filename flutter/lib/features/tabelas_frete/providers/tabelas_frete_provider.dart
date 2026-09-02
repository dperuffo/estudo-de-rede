import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../services/tabelas_frete_service.dart';

final tabelasFreteClienteProvider =
    FutureProvider.autoDispose<List<TabelaFreteDetalhe>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  return TabelasFreteService().buscar(empresaId);
});
