import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../services/bolsa_fretes_service.dart';

final minhaCapacidadeProvider =
    FutureProvider.autoDispose<List<CapacidadeOciosa>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  return BolsaFretesService().buscarMinhaCapacidade(empresaId);
});

final fretesDoGrupoProvider =
    FutureProvider.autoDispose<({List<FreteDoGrupo> fretes, String? erro})>(
        (ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return (fretes: <FreteDoGrupo>[], erro: null);
  return BolsaFretesService().buscarFretesDoGrupo(empresaId);
});
