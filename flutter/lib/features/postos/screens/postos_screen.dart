import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/postos_provider.dart';

// Fase FLT-3 — Postos Revendedores (cliente): aba "Rede do cliente" da
// web. Ver escopo completo (sem universo ANP na mesma tela — vira busca
// separada; sem edição de campos operacionais) no comentário de
// postos_provider.dart.
class PostosScreen extends ConsumerStatefulWidget {
  const PostosScreen({super.key});

  @override
  ConsumerState<PostosScreen> createState() => _PostosScreenState();
}

class _PostosScreenState extends ConsumerState<PostosScreen> {
  final _buscaCtrl = TextEditingController();
  String _busca = '';

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(postosClienteProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Postos Revendedores')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/postos/buscar'),
        icon: const Icon(Icons.add),
        label: const Text('Adicionar'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (postos) {
          if (postos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Nenhum posto na sua rede ainda.', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/postos/buscar'),
                      icon: const Icon(Icons.search),
                      label: const Text('Explorar universo ANP'),
                    ),
                  ],
                ),
              ),
            );
          }

          final bloqueados = postos.where((p) => !p.ativo).length;
          final buscaLimpa = _busca.trim().toLowerCase();
          final filtrados = buscaLimpa.isEmpty
              ? postos
              : postos.where((p) {
                  return (p.razaoSocial ?? '').toLowerCase().contains(buscaLimpa) ||
                      (p.municipio ?? '').toLowerCase().contains(buscaLimpa) ||
                      p.cnpj.contains(buscaLimpa);
                }).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(postosClienteProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                Row(
                  children: [
                    Expanded(child: _indicador('Na rede', postos.length.toString())),
                    const SizedBox(width: 8),
                    Expanded(child: _indicador('Liberados', (postos.length - bloqueados).toString())),
                    const SizedBox(width: 8),
                    Expanded(child: _indicador('Bloqueados', bloqueados.toString())),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _buscaCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por razão social, município ou CNPJ...',
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
                const SizedBox(height: 12),
                if (filtrados.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Nenhum posto encontrado com esse filtro.', style: TextStyle(color: Colors.grey.shade600)),
                    ),
                  )
                else
                  ...filtrados.map((p) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () => context.push('/postos/${p.cnpj}'),
                          title: Text(p.razaoSocial ?? p.cnpj, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(
                            [
                              p.cnpj,
                              [p.municipio, p.uf].where((v) => v != null && v.isNotEmpty).join('/'),
                              if (p.bandeira != null && p.bandeira!.isNotEmpty) p.bandeira!,
                            ].where((v) => v.isNotEmpty).join(' · '),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (p.ativo ? const Color(0xFF16A34A) : const Color(0xFFD97706)).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(p.ativo ? 'Ativo' : 'Bloqueado',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: p.ativo ? const Color(0xFF16A34A) : const Color(0xFFD97706),
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
