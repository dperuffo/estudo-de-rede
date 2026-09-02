import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/faturas_fretes_provider.dart';
import '../services/faturas_fretes_service.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _data = DateFormat('dd/MM/yyyy');

// Fase FLT-Faturas-Frete (02/09/2026) — porta de faturas-fretes/page.tsx +
// AcoesFaturaFrete.tsx. Sem geração de PDF (mesmo corte já aplicado em
// Notas Fiscais — PDF client-side fica pra depois).
class FaturasFretesScreen extends ConsumerWidget {
  const FaturasFretesScreen({super.key});

  Future<void> _cancelar(
      BuildContext context, WidgetRef ref, FaturaFrete f) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar fatura'),
        content: Text(
            'Cancelar a fatura #${f.numeroFatura.toString().padLeft(6, '0')}? Os CT-es incluídos voltam a ficar disponíveis para uma nova fatura.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Voltar')),
          FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancelar fatura')),
        ],
      ),
    );
    if (confirmado != true) return;
    final erro = await FaturasFretesService().cancelar(f.id);
    if (!context.mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    } else {
      ref.invalidate(faturasFreteClienteProvider);
    }
  }

  Future<void> _marcarPaga(
      BuildContext context, WidgetRef ref, FaturaFrete f) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar como paga'),
        content: Text(
            'Confirmar o recebimento da fatura #${f.numeroFatura.toString().padLeft(6, '0')} (${_moeda.format(f.valorTotal)})?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirmado != true) return;
    final erro = await FaturasFretesService().marcarComoPaga(f.id);
    if (!context.mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    } else {
      ref.invalidate(faturasFreteClienteProvider);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pagamento registrado.')));
    }
  }

  void _abrirAcoes(BuildContext context, WidgetRef ref, FaturaFrete f) {
    if (f.status != 'aberta') return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Marcar como paga'),
              onTap: () {
                Navigator.pop(ctx);
                _marcarPaga(context, ref, f);
              },
            ),
            ListTile(
              leading: Icon(Icons.cancel_outlined, color: Colors.red.shade700),
              title: Text('Cancelar fatura', style: TextStyle(color: Colors.red.shade700)),
              onTap: () {
                Navigator.pop(ctx);
                _cancelar(context, ref, f);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(faturasFreteClienteProvider);
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Faturas de Frete')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/faturas-fretes/gerar'),
        icon: const Icon(Icons.add),
        label: const Text('Gerar Fatura'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(faturasFreteClienteProvider),
        child: async.when(
          data: (faturas) {
            if (faturas.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                            'Nenhuma fatura gerada ainda. Toque em "Gerar Fatura" para agrupar CT-es autorizados por tomador.',
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
              children: faturas.map((f) => _card(context, ref, f)).toList(),
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

  Widget _card(BuildContext context, WidgetRef ref, FaturaFrete f) {
    final corStatus = switch (f.status) {
      'paga' => const Color(0xFFDCFCE7),
      'cancelada' => const Color(0xFFF3F4F6),
      _ => const Color(0xFFDBEAFE),
    };
    final corStatusTexto = switch (f.status) {
      'paga' => const Color(0xFF15803D),
      'cancelada' => Colors.grey.shade600,
      _ => const Color(0xFF1D4ED8),
    };
    final statusLabel = switch (f.status) {
      'paga' => 'Paga',
      'cancelada' => 'Cancelada',
      _ => 'Aberta',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _abrirAcoes(context, ref, f),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                        'Fatura #${f.numeroFatura.toString().padLeft(6, '0')} · ${f.tomadorNome ?? f.tomadorCnpj}',
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
                  if (f.status == 'aberta') ...[
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
                  Text('${f.quantidadeCtes} CT-e(s)',
                      style: const TextStyle(fontSize: 12)),
                  Text('Vencimento: ${_data.format(DateTime.parse(f.vencimento))}',
                      style: const TextStyle(fontSize: 12)),
                  Text(_moeda.format(f.valorTotal),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
