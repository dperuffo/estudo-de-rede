import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/faturas_fretes_provider.dart';
import '../services/faturas_fretes_service.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _data = DateFormat('dd/MM/yyyy');

// Fase FLT-Faturas-Frete (02/09/2026) — porta de faturas-fretes/gerar/
// page.tsx + GerarFaturaFreteForm.tsx. Lista tomadores com CT-es
// autorizados e ainda não faturados; ao tocar num tomador, abre o form de
// período+vencimento em bottom sheet (a web usa expansão inline no card).
class GerarFaturaFreteScreen extends ConsumerWidget {
  const GerarFaturaFreteScreen({super.key});

  Future<void> _abrirForm(
      BuildContext context, WidgetRef ref, TomadorComPendentes t) async {
    final empresaId = ref.read(sessaoProvider).valueOrNull?.empresaId;
    if (empresaId == null) return;
    DateTime? inicio = DateTime.tryParse(t.dataMin);
    DateTime? fim = DateTime.tryParse(t.dataMax);
    DateTime? vencimento;
    String? erro;
    var salvando = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gerar fatura — ${t.nome ?? t.cnpj}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                if (erro != null) ...[
                  Text(erro!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(inicio == null
                      ? 'Período início'
                      : 'Início: ${_data.format(inicio!)}'),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final d = await showDatePicker(
                        context: ctx,
                        initialDate: inicio ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100));
                    if (d != null) setState(() => inicio = d);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(fim == null
                      ? 'Período fim'
                      : 'Fim: ${_data.format(fim!)}'),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final d = await showDatePicker(
                        context: ctx,
                        initialDate: fim ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100));
                    if (d != null) setState(() => fim = d);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(vencimento == null
                      ? 'Vencimento *'
                      : 'Vencimento: ${_data.format(vencimento!)}'),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final d = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100));
                    if (d != null) setState(() => vencimento = d);
                  },
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: salvando
                      ? null
                      : () async {
                          if (vencimento == null) {
                            setState(() => erro = 'Informe o vencimento.');
                            return;
                          }
                          setState(() {
                            salvando = true;
                            erro = null;
                          });
                          final iso = (DateTime d) =>
                              '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                          final resultado =
                              await FaturasFretesService().gerarFatura(
                            empresaId: empresaId,
                            tomadorCnpj: t.cnpj,
                            tomadorNome: t.nome,
                            periodoInicio: iso(inicio ?? DateTime.now()),
                            periodoFim: iso(fim ?? DateTime.now()),
                            vencimento: iso(vencimento!),
                          );
                          if (resultado.erro != null) {
                            setState(() {
                              salvando = false;
                              erro = resultado.erro;
                            });
                            return;
                          }
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ref.invalidate(faturasFreteClienteProvider);
                            ref.invalidate(tomadoresComPendentesProvider);
                            context.go('/faturas-fretes');
                          }
                        },
                  child: salvando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Gerar fatura'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tomadoresComPendentesProvider);
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Gerar Fatura de Frete')),
      body: async.when(
        data: (tomadores) {
          if (tomadores.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                          'Nenhum CT-e autorizado pendente de faturamento no momento.',
                          style: TextStyle(color: Colors.grey.shade600),
                          textAlign: TextAlign.center),
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                  'CT-es autorizados ainda não incluídos em nenhuma fatura, agrupados por tomador.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(height: 12),
              ...tomadores.map((t) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(t.nome ?? t.cnpj),
                      subtitle: Text(
                          '${t.quantidadeCtes} CT-e(s) · ${_moeda.format(t.valorTotal)}'),
                      trailing: FilledButton(
                        onPressed: () => _abrirForm(context, ref, t),
                        child: const Text('Gerar'),
                      ),
                    ),
                  )),
            ],
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
    );
  }
}
