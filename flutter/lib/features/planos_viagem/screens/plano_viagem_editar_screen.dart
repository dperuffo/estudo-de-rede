import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/planos_viagem_provider.dart';
import '../services/planos_viagem_service.dart';
import 'plano_viagem_form.dart';

import '../../../core/theme/app_theme.dart';

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
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir')),
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
    final prePedidoAsync = ref.watch(prePedidoDoPlanoProvider(id));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
            decoration:
                const BoxDecoration(gradient: AppTheme.glassNavGradient)),
        foregroundColor: AppTheme.glassTexto,
        iconTheme: const IconThemeData(color: AppTheme.glassIcone),
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
          if (plano == null)
            return const Center(child: Text('Plano não encontrado.'));
          return pedagiosAsync.when(
            data: (pedagios) => Column(
              children: [
                prePedidoAsync.maybeWhen(
                  data: (prePedido) => prePedido == null
                      ? const SizedBox()
                      : _cardPrePedido(prePedido),
                  orElse: () => const SizedBox(),
                ),
                Expanded(
                    child: PlanoViagemForm(
                        existente: plano, pedagiosIniciais: pedagios)),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('Erro ao carregar pedágios: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
      ),
    );
  }

  // Fase Pré-Pedido (28/07/2026) — porta do card de Pré-Pedido em
  // planos-viagem/[id]/editar/page.tsx: número, status e paradas
  // pré-agendadas, gerado automaticamente quando o parâmetro de uso está
  // habilitado (ver planos_viagem_service.dart).
  Widget _cardPrePedido(PrePedido prePedido) {
    final statusLabel = prePedido.status == 'ativo'
        ? 'Ativo'
        : prePedido.status == 'concluido'
            ? 'Concluído'
            : 'Cancelado';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Pré-Pedido nº ${prePedido.numero}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF1E3A8A))),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(statusLabel,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF1E40AF))),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Gerado automaticamente a partir da rota calculada. Os postos abaixo têm autorização pré-agendada '
            'pra abastecer este veículo.',
            style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF)),
          ),
          const SizedBox(height: 8),
          ...prePedido.paradas.map((p) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${p.postoNome ?? p.postoCnpj}'
                        '${p.kmPrevisto != null ? " · km ${p.kmPrevisto}" : ""}'
                        '${p.litrosPrevistos != null ? " · ${p.litrosPrevistos} L previstos" : ""}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: p.atendido
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        p.atendido ? 'Abastecido' : 'Pendente',
                        style: TextStyle(
                            fontSize: 10,
                            color: p.atendido
                                ? const Color(0xFF15803D)
                                : Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
