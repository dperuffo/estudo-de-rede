import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/grupo_economico_provider.dart';

// Fase FLT-3 — Grupo Econômico (cliente): ver escopo (por que é só
// leitura) no comentário de grupo_economico_provider.dart.
class GrupoEconomicoScreen extends ConsumerWidget {
  const GrupoEconomicoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(grupoEconomicoClienteProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Grupo Econômico')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (grupo) {
          if (grupo == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Sua empresa não faz parte de nenhum grupo econômico.',
                  style: TextStyle(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _buildConteudo(grupo);
        },
      ),
    );
  }

  Widget _buildConteudo(GrupoEconomicoDetalhe g) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Agrupamento de empresas do mesmo grupo econômico.',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(g.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (g.ativo ? const Color(0xFF15803D) : Colors.grey).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(g.ativo ? 'Ativo' : 'Inativo',
                          style: TextStyle(
                              fontSize: 11,
                              color: g.ativo ? const Color(0xFF15803D) : Colors.grey.shade700,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                if (g.cnpjMatriz != null && g.cnpjMatriz!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('CNPJ matriz: ${g.cnpjMatriz}', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Empresas vinculadas (${g.vinculos.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
        if (g.vinculos.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Nenhuma empresa vinculada.', style: TextStyle(color: Colors.grey.shade600)),
            ),
          )
        else
          ...g.vinculos.map((v) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.business_outlined),
                  title: Text(v.nome, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              )),
        const SizedBox(height: 12),
        Text(
          'Pra vincular ou remover empresas do grupo, fale com a equipe FNI (Gestão de Chamados).',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
