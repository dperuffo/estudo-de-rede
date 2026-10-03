import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/negados_pdv_provider.dart';

// Fase 5 PDV (03/10/2026) — alerta visual fixo no topo de todas as telas do
// cliente enquanto houver abastecimento negado por regra aguardando
// liberação (o pedido tem validade curta; motorista e posto estão
// esperando). ConsumerWidget próprio pra não reconstruir a shell inteira.
const _vermelho = Color(0xFFEF4444);

class BannerNegadosPdv extends ConsumerWidget {
  const BannerNegadosPdv({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(negadosPdvPendentesProvider).valueOrNull ?? 0;
    if (n == 0) return const SizedBox.shrink();
    return Material(
      color: _vermelho,
      child: InkWell(
        onTap: () => context.go('/abastecimentos-negados'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.gpp_maybe_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  n == 1
                      ? '1 abastecimento negado aguardando sua liberação'
                      : '$n abastecimentos negados aguardando sua liberação',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const Text('Ver', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const Icon(Icons.chevron_right, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
