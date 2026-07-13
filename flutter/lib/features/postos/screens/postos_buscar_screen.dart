import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/postos_provider.dart';
import '../services/postos_service.dart';

// Fase FLT-3 — "Explorar universo ANP": busca no universo nacional de
// postos (35 mil+) pra ativar um novo na rede negociada do cliente. Sem
// paginação (a web pagina de 50 em 50 sobre o universo inteiro) — aqui só
// busca por texto (mín. 3 letras), capado em 30 resultados. Sem "Atualizar
// universo ANP" (admin only).
class PostosBuscarScreen extends ConsumerStatefulWidget {
  const PostosBuscarScreen({super.key});

  @override
  ConsumerState<PostosBuscarScreen> createState() => _PostosBuscarScreenState();
}

class _PostosBuscarScreenState extends ConsumerState<PostosBuscarScreen> {
  final _buscaCtrl = TextEditingController();
  String _busca = '';
  String? _uf;
  final Set<String> _ativando = {};

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  Future<void> _ativar(AnpPosto posto) async {
    final sessao = await ref.read(sessaoProvider.future);
    final empresaId = sessao.empresaId;
    if (empresaId == null) return;
    setState(() => _ativando.add(posto.cnpj));
    final erro = await PostosService().ativarPosto(cnpjAnp: posto.cnpj, empresaId: empresaId);
    if (!mounted) return;
    setState(() => _ativando.remove(posto.cnpj));
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    ref.invalidate(postosClienteProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${posto.razaoSocial ?? posto.cnpj} adicionado à sua rede.')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = BuscaAnpParams(_busca, _uf);
    final async = ref.watch(buscaAnpProvider(params));

    return Scaffold(
      appBar: AppBar(title: const Text('Explorar universo ANP')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _buscaCtrl,
              decoration: const InputDecoration(
                hintText: 'Razão social, município ou CNPJ...',
                prefixIcon: Icon(Icons.search, size: 20),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _busca = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: _uf,
              decoration: const InputDecoration(labelText: 'UF (opcional)', border: OutlineInputBorder(), isDense: true),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                ...ufsBrasil.map((uf) => DropdownMenuItem<String?>(value: uf, child: Text(uf))),
              ],
              onChanged: (v) => setState(() => _uf = v),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _busca.trim().length < 3
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Digite ao menos 3 letras para buscar.', style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  : async.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Erro ao buscar: $e')),
                      data: (resultados) {
                        if (resultados.isEmpty) {
                          return const Center(
                            child: Text('Nenhum posto encontrado.', style: TextStyle(color: Colors.grey)),
                          );
                        }
                        return ListView.builder(
                          itemCount: resultados.length,
                          itemBuilder: (_, i) {
                            final p = resultados[i];
                            final ativando = _ativando.contains(p.cnpj);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(p.razaoSocial ?? p.cnpj, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                subtitle: Text(
                                  [
                                    p.cnpj,
                                    [p.municipio, p.uf].where((v) => v != null && v.isNotEmpty).join('/'),
                                    if (p.bandeira != null && p.bandeira!.isNotEmpty) p.bandeira!,
                                  ].where((v) => v.isNotEmpty).join(' · '),
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                trailing: ativando
                                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                    : OutlinedButton(onPressed: () => _ativar(p), child: const Text('Ativar')),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
