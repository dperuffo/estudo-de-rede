import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ajustes_pdv_provider.dart';

// Alerta fixo no topo enquanto houver pedido de ajuste de abastecimento PDV
// aguardando a decisão do usuário. A decisão (aprovar/recusar) é feita no painel
// web, em "Pedidos de Ajuste (PDV)" — o toque abre a página.
const _ambar = Color(0xFFD97706);
final _urlAjustes = Uri.parse('https://fxgestaodefrotasonline.com/ajustes-pdv');

class BannerAjustesPdv extends ConsumerWidget {
  const BannerAjustesPdv({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(ajustesPdvPendentesProvider).valueOrNull ?? 0;
    if (n == 0) return const SizedBox.shrink();
    return Material(
      color: _ambar,
      child: InkWell(
        onTap: () => launchUrl(_urlAjustes, mode: LaunchMode.externalApplication),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.edit_note, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  n == 1
                      ? '1 pedido de ajuste de abastecimento aguardando sua decisão'
                      : '$n pedidos de ajuste de abastecimento aguardando sua decisão',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const Text('Decidir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const Icon(Icons.open_in_new, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
