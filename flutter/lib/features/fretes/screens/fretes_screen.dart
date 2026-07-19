import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/fretes_provider.dart';
import '../services/fretes_service.dart';

final _formatoMoedaFrete = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

// Fase Fretes-Cliente-3-Abas (19/07) — pedido do Daniel: mesma divisão em 3
// abas já feita no painel web (fretes/page.tsx) e no PWA Motorista
// (fretes_screen.dart do estrada-que-cuida) — Em Negociação (mercado
// aberto + aguardando confirmação do motorista), Aceitos/Em Andamento e
// Concluídos (mantém cancelado/recusado no histórico, não some da lista).
List<FreteRow> _emNegociacao(List<FreteRow> fretes) =>
    fretes.where((f) => f.status == 'disponivel' || f.status == 'aguardando_confirmacao').toList();
List<FreteRow> _emAndamento(List<FreteRow> fretes) =>
    fretes.where((f) => f.status == 'aceito' || f.status == 'em_andamento').toList();
List<FreteRow> _concluidos(List<FreteRow> fretes) => fretes
    .where((f) => f.status == 'concluido' || f.status == 'cancelado' || f.status == 'recusado')
    .toList();

// Fase PWA-Fretes — porta de fretes/page.tsx: lista de fretes da empresa,
// com "+ Publicar frete" e ações rápidas de cancelar/reabrir.
class FretesScreen extends ConsumerWidget {
  const FretesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessaoProvider).valueOrNull;
    final fretesAsync = ref.watch(meusFretesProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fretes'),
          bottom: fretesAsync.maybeWhen(
            data: (fretes) => TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 12.5),
              tabs: [
                Tab(text: 'Em Negociação${_negText(_emNegociacao(fretes).length)}'),
                Tab(text: 'Aceitos/Em Andamento${_negText(_emAndamento(fretes).length)}'),
                Tab(text: 'Concluídos${_negText(_concluidos(fretes).length)}'),
              ],
            ),
            orElse: () => null,
          ),
        ),
        floatingActionButton: sessao?.empresaId == null
            ? null
            : FloatingActionButton.extended(
                onPressed: () => context.push('/fretes/novo'),
                icon: const Icon(Icons.add),
                label: const Text('Publicar frete'),
              ),
        body: sessao?.empresaId == null
            ? const Center(child: Text('Selecione uma empresa primeiro.'))
            : fretesAsync.when(
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
                  return TabBarView(
                    children: [
                      _ListaFretes(
                        fretes: _emNegociacao(fretes),
                        mensagemVazia: 'Nenhum frete em negociação no momento.',
                      ),
                      _ListaFretes(
                        fretes: _emAndamento(fretes),
                        mensagemVazia: 'Nenhum frete aceito ou em andamento agora.',
                      ),
                      _ListaFretes(
                        fretes: _concluidos(fretes),
                        mensagemVazia: 'Nenhum frete concluído ainda.',
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

String _negText(int n) => n > 0 ? ' ($n)' : '';

class _ListaFretes extends ConsumerWidget {
  final List<FreteRow> fretes;
  final String mensagemVazia;
  const _ListaFretes({required this.fretes, required this.mensagemVazia});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(meusFretesProvider),
      child: fretes.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 80),
                Center(child: Text(mensagemVazia, style: const TextStyle(color: Colors.black45))),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: fretes.length,
              itemBuilder: (context, i) => _CardFrete(frete: fretes[i]),
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
