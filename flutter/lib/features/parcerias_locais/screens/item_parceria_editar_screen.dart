import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/parcerias_locais_provider.dart';
import 'item_parceria_form.dart';

class ItemParceriaEditarScreen extends ConsumerWidget {
  final String id;
  const ItemParceriaEditarScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessaoProvider).valueOrNull;
    final itemAsync = ref.watch(itemParceriaDetalheProvider(id));

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Benefício')),
      body: sessao?.empresaId == null
          ? const Center(child: Text('Selecione uma empresa primeiro.'))
          : itemAsync.when(
              data: (item) => item == null
                  ? const Center(child: Text('Benefício não encontrado.'))
                  : ItemParceriaForm(
                      empresaId: sessao!.empresaId!,
                      item: item,
                      onSalvo: () {
                        ref.invalidate(itemParceriaDetalheProvider(id));
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/parcerias-locais');
                        }
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
            ),
    );
  }
}
