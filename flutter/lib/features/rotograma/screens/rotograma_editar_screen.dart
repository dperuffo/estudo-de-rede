import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/rotograma_provider.dart';
import 'rotograma_form.dart';

import '../../../core/theme/app_theme.dart';

class RotogramaEditarScreen extends ConsumerWidget {
  final String id;
  const RotogramaEditarScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalheAsync = ref.watch(rotogramaDetalheProvider(id));
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Editar Rotograma')),
      body: detalheAsync.when(
        data: (v) {
          if (v == null)
            return const Center(child: Text('Rotograma não encontrado.'));
          return RotogramaForm(existente: v);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
      ),
    );
  }
}
