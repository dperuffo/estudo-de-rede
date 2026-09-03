import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/central_avisos_provider.dart';
import '../services/central_avisos_service.dart';

// Fase FLT-Central-Avisos (03/09/2026) — porta de
// central-avisos/gerenciar/page.tsx + ListaAvisosEmpresa.tsx ("Meus
// Avisos"). Lista os avisos que a própria empresa (ou grupo econômico)
// criou, incluindo os inativos.
class MeusAvisosScreen extends ConsumerWidget {
  const MeusAvisosScreen({super.key});

  Future<void> _alternarAtivo(
      BuildContext context, WidgetRef ref, AvisoEmpresa a) async {
    final erro =
        await CentralAvisosService().alternarAtivo(a.id, !a.ativo);
    if (!context.mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    } else {
      ref.invalidate(meusAvisosProvider);
    }
  }

  Future<void> _excluir(
      BuildContext context, WidgetRef ref, AvisoEmpresa a) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir aviso'),
        content: Text('Excluir "${a.titulo}"? Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Voltar')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmado != true) return;
    final erro = await CentralAvisosService().excluir(a.id);
    if (!context.mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    } else {
      ref.invalidate(meusAvisosProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(meusAvisosProvider);
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Meus Avisos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/central-avisos/gerenciar/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Novo aviso'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(meusAvisosProvider),
        child: async.when(
          data: (lista) {
            if (lista.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                          'Nenhum aviso criado ainda. Toque em "Novo aviso" para comunicar algo à sua empresa (e às empresas do mesmo grupo econômico, se houver).',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ),
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: lista.map((a) => _card(context, ref, a)).toList(),
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

  Widget _card(BuildContext context, WidgetRef ref, AvisoEmpresa a) {
    final corUrgencia = switch (a.urgencia) {
      'critico' => Colors.red.shade700,
      'atencao' => Colors.orange.shade700,
      _ => Colors.blueGrey,
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
                  child: Text(a.titulo,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: a.ativo
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(a.ativo ? 'Ativo' : 'Inativo',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: a.ativo
                              ? const Color(0xFF15803D)
                              : Colors.grey.shade600)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(a.resumo, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                Text(tiposAviso[a.tipo] ?? a.tipo,
                    style: const TextStyle(fontSize: 11)),
                Text(urgenciasAviso[a.urgencia] ?? a.urgencia,
                    style: TextStyle(fontSize: 11, color: corUrgencia)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => context
                      .push('/central-avisos/gerenciar/${a.id}/editar'),
                  child: const Text('Editar'),
                ),
                OutlinedButton(
                  onPressed: () => _alternarAtivo(context, ref, a),
                  child: Text(a.ativo ? 'Desativar' : 'Ativar'),
                ),
                TextButton(
                  onPressed: () => _excluir(context, ref, a),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Excluir'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
