import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/cotacoes_provider.dart';
import '../services/cotacoes_service.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

// Fase FLT-Cotações (02/09/2026) — porta de cotacoes/page.tsx +
// ConverterCotacaoButton + DescartarCotacaoButton. Sem a aba "Piso Mínimo
// ANTT" da web (tabela de referência estática, baixa prioridade pro v1
// mobile) — o alerta de piso já aparece por cotação quando aplicável.
class CotacoesScreen extends ConsumerWidget {
  const CotacoesScreen({super.key});

  Future<void> _descartar(
      BuildContext context, WidgetRef ref, Cotacao c) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar cotação'),
        content: Text(
            'Descartar a cotação ${c.origemLabel} → ${c.destinoLabel}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Descartar')),
        ],
      ),
    );
    if (confirmado != true) return;
    final erro = await CotacoesService().descartar(c.id);
    if (context.mounted) {
      if (erro != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(erro)));
      } else {
        ref.invalidate(cotacoesClienteProvider);
      }
    }
  }

  Future<void> _converter(
      BuildContext context, WidgetRef ref, Cotacao c) async {
    final empresaId = ref.read(sessaoProvider).valueOrNull?.empresaId;
    if (empresaId == null) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Converter em frete'),
        content: const Text(
            'Isso cria um frete disponível para motoristas a partir desta cotação. Confirma?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Converter')),
        ],
      ),
    );
    if (confirmado != true) return;
    final resultado = await CotacoesService().converterEmFrete(c, empresaId);
    if (!context.mounted) return;
    if (resultado.erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(resultado.erro!)));
    } else {
      ref.invalidate(cotacoesClienteProvider);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Frete criado a partir da cotação.')));
    }
  }

  void _abrirAcoes(BuildContext context, WidgetRef ref, Cotacao c) {
    if (c.status != 'simulada') return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: const Text('Converter em frete'),
              onTap: () {
                Navigator.pop(ctx);
                _converter(context, ref, c);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
              title: Text('Descartar', style: TextStyle(color: Colors.red.shade700)),
              onTap: () {
                Navigator.pop(ctx);
                _descartar(context, ref, c);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cotacoesClienteProvider);
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('🧮 Cotações')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/cotacoes/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Nova Cotação'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(cotacoesClienteProvider),
        child: async.when(
          data: (cotacoes) {
            if (cotacoes.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                            'Nenhuma cotação simulada ainda. Toque em "Nova Cotação" para começar.',
                            style: TextStyle(color: Colors.grey.shade600),
                            textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: cotacoes.map((c) => _card(context, ref, c)).toList(),
            );
          },
          loading: () => const Center(
              child: Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: CircularProgressIndicator())),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Não deu pra carregar: $e', textAlign: TextAlign.center)
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, Cotacao c) {
    final corStatus = switch (c.status) {
      'convertida' => const Color(0xFFDCFCE7),
      'descartada' => const Color(0xFFF3F4F6),
      _ => const Color(0xFFDBEAFE),
    };
    final corStatusTexto = switch (c.status) {
      'convertida' => const Color(0xFF15803D),
      'descartada' => Colors.grey.shade600,
      _ => const Color(0xFF1D4ED8),
    };
    final statusLabel = switch (c.status) {
      'convertida' => 'Convertida',
      'descartada' => 'Descartada',
      _ => 'Simulada',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _abrirAcoes(context, ref, c),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('${c.origemLabel} → ${c.destinoLabel}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: corStatus, borderRadius: BorderRadius.circular(12)),
                    child: Text(statusLabel,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: corStatusTexto)),
                  ),
                  if (c.status == 'simulada') ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text('${c.pesoKg.toStringAsFixed(0)} kg',
                      style: const TextStyle(fontSize: 12)),
                  if (c.kmEstimado != null)
                    Text('${c.kmEstimado!.toStringAsFixed(0)} km',
                        style: const TextStyle(fontSize: 12)),
                  Text('Total: ${_moeda.format(c.valorTotal)}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              if (c.pisoAnttAlerta) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(
                      '⚠️ Abaixo do piso mínimo ANTT (${_moeda.format(c.pisoAnttValor)})',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF92400E))),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
