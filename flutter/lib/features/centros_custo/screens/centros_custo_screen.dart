import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/centros_custo_provider.dart';

// Fase FLT-3 — Centros de Custo (cliente). Ver escopo completo (sem
// alocação de veículos/importação por planilha) no comentário de
// centros_custo_provider.dart.
class CentrosCustoScreen extends ConsumerWidget {
  const CentrosCustoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(centrosCustoClienteProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Centros de Custo')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/centros-custo/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Novo'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (centros) {
          if (centros.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nenhum centro de custo cadastrado ainda.', style: TextStyle(color: Colors.grey)),
              ),
            );
          }
          final ativos = centros.where((c) => c.ativo).length;
          final totalVeiculos = centros.fold<int>(0, (soma, c) => soma + c.veiculosAlocados);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(centrosCustoClienteProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                Row(
                  children: [
                    Expanded(child: _indicador('Total', centros.length.toString())),
                    const SizedBox(width: 8),
                    Expanded(child: _indicador('Ativos', ativos.toString())),
                    const SizedBox(width: 8),
                    Expanded(child: _indicador('Veículos', totalVeiculos.toString())),
                  ],
                ),
                const SizedBox(height: 16),
                ...centros.map((c) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => context.push('/centros-custo/${c.id}'),
                        title: Text(c.nome, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(
                          [
                            if (c.codigo != null && c.codigo!.isNotEmpty) 'Código ${c.codigo}',
                            if (c.responsavel != null && c.responsavel!.isNotEmpty) c.responsavel!,
                            '${c.veiculosAlocados} veículo(s) alocado(s)',
                          ].join(' · '),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (c.ativo ? const Color(0xFF16A34A) : const Color(0xFF64748B)).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(c.ativo ? 'Ativo' : 'Inativo',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: c.ativo ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _indicador(String label, String valor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
