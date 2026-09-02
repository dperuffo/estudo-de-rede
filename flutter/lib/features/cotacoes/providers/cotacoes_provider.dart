import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../services/cotacoes_service.dart';

final cotacoesClienteProvider =
    FutureProvider.autoDispose<List<Cotacao>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  return CotacoesService().buscar(empresaId);
});

final tabelasFreteAtivasProvider =
    FutureProvider.autoDispose<List<TabelaFrete>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  return CotacoesService().buscarTabelasFrete(empresaId);
});
