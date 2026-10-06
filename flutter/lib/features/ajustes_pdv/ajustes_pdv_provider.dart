import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/supabase_service.dart';

// 05/10/2026 (pedido do Daniel: pedido de ajuste do PDV não notificava o gestor)
// — quantidade de pedidos de ajuste de abastecimento PDV aguardando a decisão
// deste usuário (ele é a contraparte de quem pediu). Atualiza na hora via
// Realtime (pdv_ajustes, já filtrado por RLS) e a cada 60 s por segurança.
final ajustesPdvPendentesProvider = StreamProvider.autoDispose<int>((ref) async* {
  final controller = StreamController<int>();

  Future<void> recontar() async {
    try {
      final r = await SupabaseService.client.rpc('contar_ajustes_pdv_pendentes_para_mim');
      if (!controller.isClosed) controller.add((r as num?)?.toInt() ?? 0);
    } catch (_) {
      // best-effort: tenta de novo no próximo ciclo
    }
  }

  final sub = SupabaseService.client
      .from('pdv_ajustes')
      .stream(primaryKey: ['id'])
      .listen((_) => recontar(), onError: (_) {});
  final timer = Timer.periodic(const Duration(seconds: 60), (_) => recontar());
  ref.onDispose(() {
    timer.cancel();
    sub.cancel();
    controller.close();
  });

  await recontar();
  yield* controller.stream;
});
