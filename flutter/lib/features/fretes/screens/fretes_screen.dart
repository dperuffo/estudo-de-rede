import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/fretes_provider.dart';
import '../services/fretes_service.dart';

final _formatoMoedaFrete = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

// Fase PWA-Fretes — porta de fretes/page.tsx: lista de fretes da empresa,
// com "+ Publicar frete" e ações rápidas de cancelar/reabrir.
class FretesScreen extends ConsumerWidget {
  const FretesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessaoProvider).valueOrNull;
    final fretesAsync = ref.watch(meusFretesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fretes')),
      floatingActionButton: sessao?.empresaId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/fretes/novo'),
              icon: const Icon(Icons.add),
              label: const Text('Publicar frete'),
            ),
      body: sessao?.empresaId == null
          ? const Center(child: Text('Selecione uma empresa primeiro.'))
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(meusFretesProvider),
              child: fretesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(children: [const SizedBox(height: 80), Center(child: Text('Erro: $e'))]),
                data: (fretes) {
                  if (fretes.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Nenhum frete publicado ainda. Toque em "Publicar frete" pra começar.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                    itemCount: fretes.length,
                    itemBuilder: (context, i) => _CardFrete(frete: fretes[i]),
                  );
                },
              ),
            ),
    );
  }
}

class _CardFrete extends ConsumerWidget {
  final FreteRow frete;
  const _CardFrete({required this.frete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(frete.titulo, style: const TextStyle(fontWeight: FontWeight.bold))),
                _ChipStatusFrete(status: frete.status),
              ],
            ),
            const SizedBox(height: 6),
            Text('${frete.origemLabel} → ${frete.destinoLabel}', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatoMoedaFrete.format(frete.valorOferecido), style: const TextStyle(fontWeight: FontWeight.bold)),
                if (frete.kmEstimado != null) Text('${frete.kmEstimado!.toStringAsFixed(0)} km', style: const TextStyle(fontSize: 12)),
              ],
            ),
            if (frete.nomeMotorista != null) ...[
              const SizedBox(height: 4),
              Text('Motorista: ${frete.nomeMotorista}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
            const Divider(height: 20),
            Row(
              children: [
                if (frete.status == 'disponivel' || frete.status == 'aguardando_confirmacao')
                  TextButton(
                    onPressed: () => context.push('/fretes/${frete.id}'),
                    child: Text(frete.status == 'disponivel' ? 'Ver propostas' : 'Ver detalhes'),
                  ),
                if (frete.status == 'aceito' || frete.status == 'em_andamento' || frete.status == 'concluido')
                  TextButton(onPressed: () => context.push('/fretes/${frete.id}'), child: const Text('Ver detalhes')),
                const Spacer(),
                if (frete.status == 'disponivel' || frete.status == 'aguardando_confirmacao' || frete.status == 'aceito')
                  TextButton(
                    onPressed: () async {
                      final confirmar = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Cancelar este frete?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancelar frete')),
                          ],
                        ),
                      );
                      if (confirmar == true) {
                        await FretesService().cancelarFrete(frete.id);
                        ref.invalidate(meusFretesProvider);
                      }
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Cancelar'),
                  ),
                if (frete.status == 'recusado')
                  TextButton(
                    onPressed: () async {
                      await FretesService().reabrirFreteParaMercado(frete.id);
                      ref.invalidate(meusFretesProvider);
                    },
                    child: const Text('Abrir pro mercado'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipStatusFrete extends StatelessWidget {
  final String status;
  const _ChipStatusFrete({required this.status});

  @override
  Widget build(BuildContext context) {
    final cor = switch (status) {
      'disponivel' => Colors.blue,
      'aguardando_confirmacao' => Colors.orange,
      'aceito' => Colors.green,
      'em_andamento' => Colors.green,
      'concluido' => Colors.grey,
      'cancelado' => Colors.red,
      'recusado' => Colors.red,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: cor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: Text(
        labelStatusFrete[status] ?? status,
        style: TextStyle(color: cor, fontSize: 10.5, fontWeight: FontWeight.bold),
      ),
    );
  }
}
