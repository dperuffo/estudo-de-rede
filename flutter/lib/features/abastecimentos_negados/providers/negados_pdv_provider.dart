import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../services/negados_pdv_service.dart';

final negadosPdvProvider = FutureProvider.autoDispose<List<AbastecimentoNegadoPdv>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  return NegadosPdvService().listar(empresaId);
});

// Contagem de pedidos aguardando liberação — alimenta a bolinha do menu e o
// banner de alerta. Atualiza na hora via Realtime (abastecimentos_pdv da
// empresa) e, por segurança, a cada 30s (o pedido vence com o tempo, sem
// nenhum evento no banco).
final negadosPdvPendentesProvider = StreamProvider.autoDispose<int>((ref) async* {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) {
    yield 0;
    return;
  }
  final service = NegadosPdvService();
  final controller = StreamController<int>();

  Future<void> recontar() async {
    try {
      if (!controller.isClosed) controller.add(await service.contarPendentes(empresaId));
    } catch (_) {
      // best-effort: tenta de novo no próximo ciclo
    }
  }

  final sub = SupabaseService.client
      .from('abastecimentos_pdv')
      .stream(primaryKey: ['id'])
      .eq('empresa_id', empresaId)
      .listen((_) => recontar(), onError: (_) {});
  final timer = Timer.periodic(const Duration(seconds: 30), (_) => recontar());
  ref.onDispose(() {
    timer.cancel();
    sub.cancel();
    controller.close();
  });

  await recontar();
  yield* controller.stream;
});
