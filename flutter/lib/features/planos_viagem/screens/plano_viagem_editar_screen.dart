import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/planos_viagem_provider.dart';
import '../services/planos_viagem_service.dart';
import 'plano_viagem_form.dart';

// Fase FLT-3 — Editar Plano de Viagem (cliente), porta de
// planos-viagem/[id]/editar/page.tsx. Carrega o plano + pedágios já
// salvos antes de montar o form (o form precisa dos pedágios prontos pra
// inicializar os controllers de cada linha).
//
// "Excluir" (BotaoExcluirPlano.tsx na web, com confirmação inline na
// linha da tabela) foi movido pra cá, como ação da AppBar com diálogo de
// confirmação — mesmo padrão já usado em rotograma_detalhe_screen.dart;
// mais natural em mobile do que confirmar dentro da lista.
class PlanoViagemEditarScreen extends ConsumerWidget {
  final String id;
  const PlanoViagemEditarScreen({super.key, required this.id});

  Future<void> _excluir(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Plano de Viagem?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;
    await PlanosViagemService().excluir(id);
    ref.invalidate(planosViagemListaProvider);
    if (!context.mounted) return;
    context.go('/planos-viagem');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planoAsync = ref.watch(planoViagemDetalheProvider(id));
    final pedagiosAsync = ref.watch(pedagiosPlanoProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Plano de Viagem'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Excluir',
            onPressed: () => _excluir(context, ref),
          ),
        ],
      ),
      body: planoAsync.when(
        data: (plano) {
          if (plano == null) return const Center(child: Text('Plano não encontrado.'));
          return pedagiosAsync.when(
            data: (pedagios) => PlanoViagemForm(existente: plano, pedagiosIniciais: pedagios),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro ao carregar pedágios: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
      ),
    );
  }
}
