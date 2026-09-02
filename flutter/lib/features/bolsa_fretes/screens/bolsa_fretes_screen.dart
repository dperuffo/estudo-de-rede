import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/bolsa_fretes_provider.dart';
import '../services/bolsa_fretes_service.dart';

final _data = DateFormat('dd/MM/yyyy');

// Fase FLT-Bolsa-Fretes (02/09/2026) — porta de bolsa-fretes/page.tsx.
// v1 restrita a empresas do mesmo Grupo Econômico (sem oferta/negociação;
// só declarar capacidade ociosa própria + ver, em modo leitura, os fretes
// "disponivel" das empresas irmãs do grupo — sem preço/contato).
class BolsaFretesScreen extends ConsumerWidget {
  const BolsaFretesScreen({super.key});

  Future<void> _abrirFormNova(BuildContext context, WidgetRef ref) async {
    final empresaId = ref.read(sessaoProvider).valueOrNull?.empresaId;
    if (empresaId == null) return;
    final placaCtrl = TextEditingController();
    final tipoCtrl = TextEditingController();
    final origemCidadeCtrl = TextEditingController();
    final origemUfCtrl = TextEditingController();
    final destinoCtrl = TextEditingController();
    final capacidadeCtrl = TextEditingController();
    final obsCtrl = TextEditingController();
    DateTime disponivelAPartir = DateTime.now();
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Declarar capacidade ociosa',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  if (erro != null) ...[
                    Text(erro!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: placaCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Placa', hintText: 'ABC1D23'),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: tipoCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Tipo de veículo',
                        hintText: 'Ex.: Truck baú'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: origemCidadeCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Cidade de origem *'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: origemUfCtrl,
                    decoration: const InputDecoration(
                        labelText: 'UF *', hintText: 'SP'),
                    maxLength: 2,
                    textCapitalization: TextCapitalization.characters,
                  ),
                  TextField(
                    controller: destinoCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Destino pretendido',
                        hintText: 'Opcional'),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                        'Disponível a partir de: ${_data.format(disponivelAPartir)}'),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: () async {
                      final d = await showDatePicker(
                          context: ctx,
                          initialDate: disponivelAPartir,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100));
                      if (d != null) setState(() => disponivelAPartir = d);
                    },
                  ),
                  TextField(
                    controller: capacidadeCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Capacidade (kg)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: obsCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Observações'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: salvando
                        ? null
                        : () async {
                            setState(() {
                              salvando = true;
                              erro = null;
                            });
                            final iso = (DateTime d) =>
                                '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                            final resultado = await BolsaFretesService().criar(
                              empresaId: empresaId,
                              placa: placaCtrl.text,
                              tipoVeiculo: tipoCtrl.text,
                              origemCidade: origemCidadeCtrl.text,
                              origemUf: origemUfCtrl.text,
                              destinoPretendido: destinoCtrl.text,
                              disponivelAPartir: iso(disponivelAPartir),
                              capacidadeKg:
                                  double.tryParse(capacidadeCtrl.text),
                              observacoes: obsCtrl.text,
                            );
                            if (resultado != null) {
                              setState(() {
                                salvando = false;
                                erro = resultado;
                              });
                              return;
                            }
                            if (context.mounted) {
                              Navigator.pop(ctx);
                              ref.invalidate(minhaCapacidadeProvider);
                            }
                          },
                    child: salvando
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Salvar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _abrirAcoes(
      BuildContext context, WidgetRef ref, CapacidadeOciosa c) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (c.status == 'ativo') ...[
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Marcar utilizada'),
                onTap: () {
                  Navigator.pop(ctx);
                  _mudarStatus(context, ref, c.id, 'utilizada');
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel_outlined),
                title: const Text('Cancelar'),
                onTap: () {
                  Navigator.pop(ctx);
                  _mudarStatus(context, ref, c.id, 'cancelada');
                },
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Reativar'),
                onTap: () {
                  Navigator.pop(ctx);
                  _mudarStatus(context, ref, c.id, 'ativo');
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
              title: Text('Excluir',
                  style: TextStyle(color: Colors.red.shade700)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirmado = await showDialog<bool>(
                  context: context,
                  builder: (dctx) => AlertDialog(
                    title: const Text('Excluir'),
                    content: const Text(
                        'Excluir esta capacidade ociosa? Essa ação não pode ser desfeita.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dctx, false),
                          child: const Text('Voltar')),
                      FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: Colors.red.shade700),
                          onPressed: () => Navigator.pop(dctx, true),
                          child: const Text('Excluir')),
                    ],
                  ),
                );
                if (confirmado == true) {
                  await BolsaFretesService().excluir(c.id);
                  ref.invalidate(minhaCapacidadeProvider);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _mudarStatus(
      BuildContext context, WidgetRef ref, String id, String status) async {
    final erro = await BolsaFretesService().atualizarStatus(id, status);
    if (!context.mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    } else {
      ref.invalidate(minhaCapacidadeProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minhaCapacidade = ref.watch(minhaCapacidadeProvider);
    final fretesGrupo = ref.watch(fretesDoGrupoProvider);

    final ufsComCapacidadeAtiva = minhaCapacidade.valueOrNull
            ?.where((c) => c.status == 'ativo')
            .map((c) => c.origemUf)
            .toSet() ??
        <String>{};

    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Bolsa de Fretes do Grupo')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormNova(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Declarar capacidade'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(minhaCapacidadeProvider);
          ref.invalidate(fretesDoGrupoProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            Row(
              children: [
                const Icon(Icons.local_shipping_outlined, size: 18),
                const SizedBox(width: 6),
                const Text('Minha capacidade ociosa',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            minhaCapacidade.when(
              data: (lista) {
                if (lista.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                          'Nenhuma capacidade ociosa declarada ainda.',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ),
                  );
                }
                return Column(
                    children:
                        lista.map((c) => _cardCapacidade(context, ref, c)).toList());
              },
              loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text('Não deu pra carregar: $e'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.map_outlined, size: 18),
                const SizedBox(width: 6),
                const Text('Fretes disponíveis no grupo',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            fretesGrupo.when(
              data: (r) {
                if (r.erro != null) {
                  return Text(r.erro!,
                      style: const TextStyle(color: Colors.red));
                }
                if (r.fretes.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                          'Nenhum frete disponível nas outras empresas do grupo agora, ou esta empresa não pertence a um Grupo Econômico.',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ),
                  );
                }
                return Column(
                  children: r.fretes
                      .map((f) => _cardFrete(
                          f, ufsComCapacidadeAtiva.contains(f.origemUf)))
                      .toList(),
                );
              },
              loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text('Não deu pra carregar: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardCapacidade(
      BuildContext context, WidgetRef ref, CapacidadeOciosa c) {
    final corStatus = switch (c.status) {
      'cancelada' => const Color(0xFFF3F4F6),
      'utilizada' => const Color(0xFFFEF3C7),
      _ => const Color(0xFFDCFCE7),
    };
    final corStatusTexto = switch (c.status) {
      'cancelada' => Colors.grey.shade600,
      'utilizada' => const Color(0xFF92400E),
      _ => const Color(0xFF15803D),
    };
    final statusLabel = switch (c.status) {
      'cancelada' => 'Cancelada',
      'utilizada' => 'Utilizada',
      _ => 'Ativo',
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
                    child: Text(
                        '${c.origemCidade}/${c.origemUf}${c.destinoPretendido != null ? ' → ${c.destinoPretendido}' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: corStatus,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(statusLabel,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: corStatusTexto)),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (c.placa != null)
                    Text(c.placa!, style: const TextStyle(fontSize: 12)),
                  if (c.tipoVeiculo != null)
                    Text(c.tipoVeiculo!, style: const TextStyle(fontSize: 12)),
                  if (c.capacidadeKg != null)
                    Text('${c.capacidadeKg!.toStringAsFixed(0)} kg',
                        style: const TextStyle(fontSize: 12)),
                  Text(
                      'Disponível: ${c.disponivelAPartir.isNotEmpty ? _data.format(DateTime.parse(c.disponivelAPartir)) : '-'}',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardFrete(FreteDoGrupo f, bool compativel) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: compativel ? const Color(0xFFEFF6FF) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(f.empresaNome,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                if (compativel)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Text('Compatível',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1D4ED8))),
                  ),
              ],
            ),
            if (f.titulo != null) ...[
              const SizedBox(height: 2),
              Text(f.titulo!, style: const TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 6),
            Text(
                '${f.origemCidade ?? '-'}/${f.origemUf ?? '-'} → ${f.destinoCidade ?? '-'}/${f.destinoUf ?? '-'}',
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (f.tipoCarga != null)
                  Text(f.tipoCarga!, style: const TextStyle(fontSize: 12)),
                if (f.pesoCargaKg != null)
                  Text('${f.pesoCargaKg!.toStringAsFixed(0)} kg',
                      style: const TextStyle(fontSize: 12)),
                if (f.kmEstimado != null)
                  Text('${f.kmEstimado!.toStringAsFixed(0)} km',
                      style: const TextStyle(fontSize: 12)),
                if (f.dataSaidaPrevista != null)
                  Text(
                      'Saída: ${_data.format(DateTime.parse(f.dataSaidaPrevista!))}',
                      style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
