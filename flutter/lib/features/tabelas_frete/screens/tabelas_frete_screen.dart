import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/tabelas_frete_provider.dart';
import '../services/tabelas_frete_service.dart';

// Fase FLT-Tabelas-Frete (02/09/2026) — porta de tabelas-frete/page.tsx +
// AlternarAtivoTabela + BotaoExcluirTabela. Lista em cards (a web usa
// grid responsivo; aqui é lista vertical, cabe melhor no celular).
class TabelasFreteScreen extends ConsumerWidget {
  const TabelasFreteScreen({super.key});

  Future<void> _alternarAtivo(
      BuildContext context, WidgetRef ref, TabelaFreteDetalhe t) async {
    final erro =
        await TabelasFreteService().alternarAtivo(t.id, !t.ativo);
    if (!context.mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    } else {
      ref.invalidate(tabelasFreteClienteProvider);
    }
  }

  Future<void> _excluir(
      BuildContext context, WidgetRef ref, TabelaFreteDetalhe t) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir tabela de frete'),
        content: Text(
            'Excluir a tabela "${t.nome}"? As faixas de peso vinculadas também serão removidas.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmado != true) return;
    final erro = await TabelasFreteService().excluir(t.id);
    if (!context.mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    } else {
      ref.invalidate(tabelasFreteClienteProvider);
    }
  }

  void _abrirAcoes(BuildContext context, WidgetRef ref, TabelaFreteDetalhe t) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/tabelas-frete/${t.id}/editar');
              },
            ),
            ListTile(
              leading: Icon(t.ativo ? Icons.toggle_off : Icons.toggle_on),
              title: Text(t.ativo ? 'Desativar' : 'Ativar'),
              onTap: () {
                Navigator.pop(ctx);
                _alternarAtivo(context, ref, t);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
              title: Text('Excluir', style: TextStyle(color: Colors.red.shade700)),
              onTap: () {
                Navigator.pop(ctx);
                _excluir(context, ref, t);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tabelasFreteClienteProvider);
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Tabelas de Frete')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/tabelas-frete/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Nova Tabela'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(tabelasFreteClienteProvider),
        child: async.when(
          data: (tabelas) {
            if (tabelas.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                            'Nenhuma tabela de frete cadastrada. Toque em "Nova Tabela" para começar.',
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
              children: tabelas.map((t) => _card(context, ref, t)).toList(),
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

  Widget _card(BuildContext context, WidgetRef ref, TabelaFreteDetalhe t) {
    final rota = (t.cidadeOrigem != null || t.cidadeDestino != null)
        ? '${t.cidadeOrigem ?? '?'}${t.ufOrigem != null ? '/${t.ufOrigem}' : ''} → ${t.cidadeDestino ?? '?'}${t.ufDestino != null ? '/${t.ufDestino}' : ''}'
        : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _abrirAcoes(context, ref, t),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(t.nome,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: t.ativo
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(t.ativo ? 'Ativa' : 'Inativa',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: t.ativo
                                ? const Color(0xFF15803D)
                                : Colors.grey.shade600)),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                ],
              ),
              if (rota != null) ...[
                const SizedBox(height: 4),
                Text(rota, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
              const SizedBox(height: 6),
              Text(
                  'Ad valorem ${t.percentualAdValorem.toStringAsFixed(1)}% · GRIS ${t.percentualGris.toStringAsFixed(1)}% · ICMS ${t.percentualIcms.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
