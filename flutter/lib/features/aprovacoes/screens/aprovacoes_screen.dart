import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/aprovacoes_provider.dart';
import '../services/aprovacoes_service.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _data = DateFormat('dd/MM/yyyy');

// Fase FLT-Aprovações (03/09/2026) — porta de aprovacoes/page.tsx +
// NovaSolicitacaoForm.tsx + AcoesSolicitacao.tsx.
class AprovacoesScreen extends ConsumerWidget {
  const AprovacoesScreen({super.key});

  Future<void> _abrirFormNova(BuildContext context, WidgetRef ref) async {
    final empresaId = ref.read(sessaoProvider).valueOrNull?.empresaId;
    if (empresaId == null) return;
    String categoria = 'manutencao';
    final tituloCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final valorCtrl = TextEditingController();
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
                  const Text('Nova solicitação de aprovação',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  if (erro != null) ...[
                    Text(erro!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                  ],
                  DropdownButtonFormField<String>(
                    value: categoria,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: categoriasAprovacao.entries
                        .map((e) => DropdownMenuItem(
                            value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => categoria = v ?? 'manutencao'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: valorCtrl,
                    decoration: const InputDecoration(labelText: 'Valor (R\$)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: tituloCtrl,
                    decoration: const InputDecoration(labelText: 'Título *'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Descrição'),
                    maxLines: 3,
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
                            final valor = double.tryParse(
                                    valorCtrl.text.replaceAll(',', '.')) ??
                                0;
                            final resultado = await AprovacoesService().criar(
                              empresaId: empresaId,
                              categoria: categoria,
                              titulo: tituloCtrl.text,
                              descricao: descCtrl.text,
                              valor: valor,
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
                              ref.invalidate(aprovacoesClienteProvider);
                            }
                          },
                    child: salvando
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Solicitar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _decidir(BuildContext context, WidgetRef ref,
      SolicitacaoAprovacao s, String decisao) async {
    String? comentario;
    if (decisao == 'reprovado') {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reprovar solicitação'),
          content: TextField(
            controller: ctrl,
            decoration:
                const InputDecoration(labelText: 'Motivo (opcional)'),
            maxLines: 2,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Voltar')),
            FilledButton(
                style:
                    FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Reprovar')),
          ],
        ),
      );
      if (ok != true) return;
      comentario = ctrl.text;
    }
    final erro = await AprovacoesService()
        .decidir(id: s.id, decisao: decisao, comentario: comentario);
    if (!context.mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    } else {
      ref.invalidate(aprovacoesClienteProvider);
    }
  }

  Future<void> _marcarExecutada(
      BuildContext context, WidgetRef ref, SolicitacaoAprovacao s) async {
    final erro = await AprovacoesService().marcarExecutada(s.id);
    if (!context.mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    } else {
      ref.invalidate(aprovacoesClienteProvider);
    }
  }

  Future<void> _cancelar(
      BuildContext context, WidgetRef ref, SolicitacaoAprovacao s) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar solicitação'),
        content: const Text('Cancelar esta solicitação de aprovação?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Voltar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancelar solicitação')),
        ],
      ),
    );
    if (confirmado != true) return;
    final erro = await AprovacoesService().cancelar(s.id);
    if (!context.mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    } else {
      ref.invalidate(aprovacoesClienteProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(aprovacoesClienteProvider);
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Aprovações')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormNova(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nova solicitação'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(aprovacoesClienteProvider),
        child: async.when(
          data: (lista) {
            final pendentes = lista.where((s) => s.status == 'pendente');
            final valorPendente =
                pendentes.fold<double>(0, (s, i) => s + i.valor);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${pendentes.length}',
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold)),
                              Text('Pendentes',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_moeda.format(valorPendente),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              Text('Valor pendente',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (lista.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Nenhuma solicitação de aprovação ainda.',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ),
                  )
                else
                  ...lista.map((s) => _card(context, ref, s)),
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
      ),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, SolicitacaoAprovacao s) {
    final corStatus = switch (s.status) {
      'aprovada' => const Color(0xFFDCFCE7),
      'executada' => const Color(0xFFE0E7FF),
      'reprovada' => const Color(0xFFFEE2E2),
      'cancelada' => const Color(0xFFF3F4F6),
      _ => const Color(0xFFFEF3C7),
    };
    final corStatusTexto = switch (s.status) {
      'aprovada' => const Color(0xFF15803D),
      'executada' => const Color(0xFF4338CA),
      'reprovada' => const Color(0xFFB91C1C),
      'cancelada' => Colors.grey.shade600,
      _ => const Color(0xFF92400E),
    };
    final statusLabel = switch (s.status) {
      'aprovada' => 'Aprovada',
      'executada' => 'Executada',
      'reprovada' => 'Reprovada',
      'cancelada' => 'Cancelada',
      _ => 'Pendente',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(s.titulo,
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
              ],
            ),
            if (s.descricao != null && s.descricao!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(s.descricao!, style: const TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(categoriasAprovacao[s.categoria] ?? s.categoria,
                    style: const TextStyle(fontSize: 12)),
                Text(_moeda.format(s.valor),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                Text('Nível ${s.nivelAtual}/${s.niveisNecessarios}',
                    style: const TextStyle(fontSize: 12)),
                Text(s.solicitanteEmail, style: const TextStyle(fontSize: 11)),
                if (s.criadoEm.isNotEmpty)
                  Text(_data.format(DateTime.parse(s.criadoEm)),
                      style: const TextStyle(fontSize: 11)),
              ],
            ),
            if (s.status == 'pendente' || s.status == 'aprovada') ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (s.status == 'pendente') ...[
                    FilledButton.tonal(
                      onPressed: () => _decidir(context, ref, s, 'aprovado'),
                      child: const Text('Aprovar'),
                    ),
                    OutlinedButton(
                      onPressed: () => _decidir(context, ref, s, 'reprovado'),
                      child: const Text('Reprovar'),
                    ),
                  ],
                  if (s.status == 'aprovada')
                    OutlinedButton(
                      onPressed: () => _marcarExecutada(context, ref, s),
                      child: const Text('Marcar como executada'),
                    ),
                  TextButton(
                    onPressed: () => _cancelar(context, ref, s),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
