import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/veiculos_provider.dart';

// Fase FLT-3 — Veículos (cliente). Ver escopo (sem paginação/importação
// por planilha) no comentário de veiculos_provider.dart.
class VeiculosScreen extends ConsumerStatefulWidget {
  const VeiculosScreen({super.key});

  @override
  ConsumerState<VeiculosScreen> createState() => _VeiculosScreenState();
}

class _VeiculosScreenState extends ConsumerState<VeiculosScreen> {
  final _buscaCtrl = TextEditingController();
  String _busca = '';
  String _filtroStatus = 'todos';

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(veiculosClienteProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Veículos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/veiculos/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Novo'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (veiculos) {
          if (veiculos.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nenhum veículo cadastrado ainda.', style: TextStyle(color: Colors.grey)),
              ),
            );
          }
          final ativos = veiculos.where((v) => v.ativo).length;

          final buscaLimpa = _busca.trim().toLowerCase();
          final filtrados = veiculos.where((v) {
            if (_filtroStatus == 'ativos' && !v.ativo) return false;
            if (_filtroStatus == 'inativos' && v.ativo) return false;
            if (buscaLimpa.isEmpty) return true;
            final placa = v.placa.toLowerCase();
            final marca = (v.marca ?? '').toLowerCase();
            final modelo = (v.modelo ?? '').toLowerCase();
            return placa.contains(buscaLimpa) || marca.contains(buscaLimpa) || modelo.contains(buscaLimpa);
          }).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(veiculosClienteProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                Row(
                  children: [
                    Expanded(child: _indicador('Total', veiculos.length.toString())),
                    const SizedBox(width: 8),
                    Expanded(child: _indicador('Ativos', ativos.toString())),
                    const SizedBox(width: 8),
                    Expanded(child: _indicador('Inativos', (veiculos.length - ativos).toString())),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _buscaCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por placa, marca ou modelo...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: _busca.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _buscaCtrl.clear();
                              setState(() => _busca = '');
                            },
                          ),
                  ),
                  onChanged: (v) => setState(() => _busca = v),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: _filtroStatus == 'todos',
                      onSelected: (_) => setState(() => _filtroStatus = 'todos'),
                    ),
                    ChoiceChip(
                      label: const Text('Ativos'),
                      selected: _filtroStatus == 'ativos',
                      onSelected: (_) => setState(() => _filtroStatus = 'ativos'),
                    ),
                    ChoiceChip(
                      label: const Text('Inativos'),
                      selected: _filtroStatus == 'inativos',
                      onSelected: (_) => setState(() => _filtroStatus = 'inativos'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (filtrados.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Nenhum veículo encontrado com esse filtro.',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ),
                  )
                else
                  ...filtrados.map((v) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () => context.push('/veiculos/${v.id}'),
                          title: Text(v.placa, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                [v.marca, v.modelo].where((x) => x != null && x.isNotEmpty).join(' ').isEmpty
                                    ? '—'
                                    : [v.marca, v.modelo].where((x) => x != null && x.isNotEmpty).join(' '),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                [
                                  if (v.tipoVeiculo != null) v.tipoVeiculo!,
                                  v.classificacao,
                                  if (v.centroCustoNome != null) v.centroCustoNome!,
                                ].join(' · '),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (v.ativo ? const Color(0xFF16A34A) : const Color(0xFF64748B)).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(v.ativo ? 'Ativo' : 'Inativo',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: v.ativo ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                    fontWeight: FontWeight.w600)),
                          ),
                          isThreeLine: true,
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
