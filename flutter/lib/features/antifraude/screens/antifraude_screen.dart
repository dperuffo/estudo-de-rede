import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../motoristas/providers/motoristas_provider.dart' show motoristasClienteProvider;
import '../../veiculos/providers/veiculos_provider.dart' show veiculosClienteProvider;
import '../providers/antifraude_provider.dart';
import '../services/antifraude_service.dart';
import 'regra_antifraude_form.dart';

// Fase 27.15x — "Regras Antifraude" (PWA), porta de
// src/app/(dashboard)/antifraude/page.tsx (web): chips de tipo + lista +
// FAB "Nova Regra". Mesmo espírito visual de ParametrosUsoScreen.
class AntifraudeScreen extends ConsumerStatefulWidget {
  const AntifraudeScreen({super.key});

  @override
  ConsumerState<AntifraudeScreen> createState() => _AntifraudeScreenState();
}

class _AntifraudeScreenState extends ConsumerState<AntifraudeScreen> {
  String _tipo = tiposRegraAntifraude.first.$1;
  String? _statusFiltro;

  Future<void> _confirmarExcluir(String id, String nome) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir regra?'),
        content: Text('"$nome" — esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;
    await AntifraudeService().excluir(id);
    ref.invalidate(regrasAntifraudeProvider(_tipo));
  }

  Future<void> _abrirFormRegra({RegraAntifraudeRow? regraExistente}) async {
    final sessao = await ref.read(sessaoProvider.future);
    final empresaId = sessao.empresaId;
    if (empresaId == null || !mounted) return;
    final veiculos = await ref.read(veiculosClienteProvider.future);
    final motoristas = await ref.read(motoristasClienteProvider.future);
    if (!mounted) return;
    await mostrarFormRegraAntifraude(
      context,
      ref,
      empresaId,
      _tipo,
      veiculos,
      motoristas,
      regraExistente: regraExistente,
    );
  }

  @override
  Widget build(BuildContext context) {
    final falhasAsync = ref.watch(falhasVerificacaoAntifraudeCountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Antifraude')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormRegra(),
        icon: const Icon(Icons.add),
        label: const Text('Nova Regra'),
      ),
      body: Column(
        children: [
          falhasAsync.maybeWhen(
            data: (n) => n > 0 ? _avisoFalhas(n) : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final t in tiposRegraAntifraude)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(t.$2),
                        selected: _tipo == t.$1,
                        onSelected: (_) => setState(() => _tipo = t.$1),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _lista()),
        ],
      ),
    );
  }

  Widget _avisoFalhas(int quantidade) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFFDE68A)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$quantidade abastecimento${quantidade > 1 ? 's' : ''} autorizado${quantidade > 1 ? 's' : ''} sem verificação completa — vale revisar.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
          TextButton(
            onPressed: () async {
              await AntifraudeService().marcarFalhasComoLidas();
              ref.invalidate(falhasVerificacaoAntifraudeCountProvider);
            },
            child: const Text('Marcar como lidas', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _lista() {
    final async = ref.watch(regrasAntifraudeProvider(_tipo));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
      data: (lista) {
        final filtrados = _statusFiltro == null ? lista : lista.where((r) => r.status == _statusFiltro).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
          children: [
            const Text(
              'Regras que sistemas externos consultam antes de autorizar um abastecimento.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text('Todos (${lista.length})'),
                  selected: _statusFiltro == null,
                  onSelected: (_) => setState(() => _statusFiltro = null),
                ),
                ChoiceChip(
                  label: const Text('Ativas'),
                  selected: _statusFiltro == 'Ativo',
                  onSelected: (_) => setState(() => _statusFiltro = 'Ativo'),
                ),
                ChoiceChip(
                  label: const Text('Inativas'),
                  selected: _statusFiltro == 'Inativo',
                  onSelected: (_) => setState(() => _statusFiltro = 'Inativo'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (filtrados.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Nenhuma regra cadastrada.', style: TextStyle(color: Colors.grey.shade600)),
                ),
              ),
            ...filtrados.map((r) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.nome, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(
                          '${labelEscopoAntifraude[r.escopo] ?? r.escopo}${r.escopoReferencia != null ? ' — ${r.escopoReferencia}' : ''}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          'Vigência: ${r.vigenciaInicio} até ${r.vigenciaFim ?? 'sem prazo'}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (r.ativo ? const Color(0xFF16A34A) : const Color(0xFF64748B)).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(r.status,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: r.ativo ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                      fontWeight: FontWeight.w600)),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => _abrirFormRegra(regraExistente: r),
                              child: const Text('Editar'),
                            ),
                            TextButton(
                              onPressed: () async {
                                await AntifraudeService().alternarStatus(id: r.id, ativo: !r.ativo);
                                ref.invalidate(regrasAntifraudeProvider(_tipo));
                              },
                              child: Text(r.ativo ? 'Inativar' : 'Ativar'),
                            ),
                            TextButton(
                              onPressed: () => _confirmarExcluir(r.id, r.nome),
                              child: const Text('Excluir'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }
}
