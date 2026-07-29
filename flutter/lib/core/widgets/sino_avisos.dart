import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/avisos_provider.dart';
import '../services/sessao_provider.dart';

// Fase Central-Avisos (28/07/2026) — sino no AppBar dos dois shells (cliente
// em home_screen.dart, posto em posto_home_screen.dart), com badge de não
// lidos. Ao tocar, navega pra tela cheia de avisos (mesma ideia do drawer da
// web, mas como rota própria — o app não usa bottom sheet/drawer lateral pra
// esse tipo de conteúdo, ver chamados_cliente_screen.dart).
class SinoAvisos extends ConsumerWidget {
  const SinoAvisos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final naoLidos = ref.watch(avisosNaoLidosProvider);
    final sessao = ref.watch(sessaoProvider).valueOrNull;
    final rota = (sessao?.ehPosto ?? false) ? '/posto/avisos' : '/avisos';

    return IconButton(
      tooltip: 'Avisos',
      onPressed: () => context.push(rota),
      icon: Badge(
        label: Text('$naoLidos'),
        isLabelVisible: naoLidos > 0,
        backgroundColor: const Color(0xFFEF4444),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
