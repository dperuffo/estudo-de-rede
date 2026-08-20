import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sessao_provider.dart';
import 'item_parceria_form.dart';

import '../../../core/theme/app_theme.dart';

class ItemParceriaNovoScreen extends ConsumerWidget {
  const ItemParceriaNovoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessaoProvider).valueOrNull;
    final empresaId = sessao?.empresaId;

    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Novo Benefício')),
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
