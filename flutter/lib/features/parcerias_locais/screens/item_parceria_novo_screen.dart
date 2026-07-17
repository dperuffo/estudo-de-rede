import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sessao_provider.dart';
import 'item_parceria_form.dart';

class ItemParceriaNovoScreen extends ConsumerWidget {
  const ItemParceriaNovoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessaoProvider).valueOrNull;
    final empresaId = sessao?.empresaId;

    return Scaffold(
      appBar: AppBar(title: const Text('Novo Benefício')),
      body: empresaId == null
          ? const Center(child: Text('Selecione uma empresa primeiro.'))
          : ItemParceriaForm(
              empresaId: empresaId,
              onSalvo: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/parcerias-locais');
                }
              },
            ),
    );
  }
}
