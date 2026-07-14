import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/rotograma_provider.dart';
import '../services/rotograma_service.dart';
import 'linha_do_tempo_rotograma.dart';

// Fase FLT-3 — Rotograma de Segurança (cliente): detalhe, porta de
// [id]/page.tsx + VisualizacaoRotograma.tsx + LinhaDoTempoRotograma.tsx.
// Fora do escopo: export em PDF (ver rotograma_provider.dart).
class RotogramaDetalheScreen extends ConsumerWidget {
  final String id;
  const RotogramaDetalheScreen({super.key, required this.id});

  Future<void> _excluir(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Rotograma?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;
    await RotogramaService().excluir(id);
    if (!context.mounted) return;
    context.go('/rotograma');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalheAsync = ref.watch(rotogramaDetalheProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Rotograma')),
      body: detalheAsync.when(
        data: (v) {
          if (v == null) return const Center(child: Text('Rotograma não encontrado.'));
          return _conteudo(context, ref, v);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
      ),
    );
  }

  Widget _conteudo(BuildContext context, WidgetRef ref, RotogramaDetalhe v) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'Rotograma #${v.numero} — ${v.origem ?? '—'} → ${v.destino ?? '—'}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/rotograma/$id/editar'),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Editar'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _excluir(context, ref),
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                label: const Text('Excluir', style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            _indicador('Motorista', v.motorista ?? '—'),
            _indicador('Veículo / Placa', [v.veiculo, v.placa].where((s) => s != null && s.isNotEmpty).join(' · ').isEmpty ? '—' : [v.veiculo, v.placa].where((s) => s != null && s.isNotEmpty).join(' · ')),
            _indicador('Data da viagem', v.dataViagem ?? '—'),
            _indicador('Carga', v.carga ?? '—'),
          ],
        ),
        const SizedBox(height: 16),

        if (v.observacoes != null && v.observacoes!.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Observações', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
                  const SizedBox(height: 6),
                  Text(v.observacoes!, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🗺️ Linha do tempo da viagem', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                if (v.riscos.isEmpty && v.paradas.isEmpty)
                  Text('Adicione pontos de risco ou parada para ver a linha do tempo.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
                else
                  LinhaDoTempoRotograma(origem: v.origem ?? '', destino: v.destino ?? '', riscos: v.riscos, paradas: v.paradas),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('⚠️ Pontos de risco (${v.riscos.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                if (v.riscos.isEmpty)
                  Text('Nenhum ponto de risco cadastrado.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
                else
                  ...v.riscos.map((r) => _itemRiscoParada(
                        icone: categoriaRiscoIcone(r.categoria),
                        local: r.local,
                        descricao: r.descricao,
                        cor: corRisco(r.categoria),
                        fundo: corRiscoFundo(r.categoria),
                      )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📍 Pontos de parada (${v.paradas.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                if (v.paradas.isEmpty)
                  Text('Nenhuma parada cadastrada.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
                else
                  ...v.paradas.map((p) => _itemRiscoParada(
                        icone: categoriaParadaIcone(p.categoria),
                        local: p.local,
                        descricao: p.descricao,
                        cor: corParadaHex,
                        fundo: const Color(0xFFECFEFF),
                      )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('☎️ Contatos de emergência', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: contatosEmergencia
                      .map((c) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              children: [
                                Text(c.nome, style: const TextStyle(fontSize: 9, color: Color(0xFFCBD5E1), letterSpacing: 0.5)),
                                Text(c.numero, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _indicador(String label, String valor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _itemRiscoParada({required String icone, required String local, required String descricao, required Color cor, required Color fundo}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(8), border: Border.all(color: cor.withOpacity(0.3))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icone, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(local, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                if (descricao.isNotEmpty) Text(descricao, style: TextStyle(fontSize: 11, color: cor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
