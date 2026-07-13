import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cliente_cadastro_provider.dart';

String _formatarCnpj(String? cnpj) {
  if (cnpj == null || cnpj.isEmpty) return '—';
  final d = cnpj.replaceAll(RegExp(r'\D'), '');
  if (d.length != 14) return cnpj;
  return '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/${d.substring(8, 12)}-${d.substring(12, 14)}';
}

// Fase FLT-3 — Clientes (cliente): ver escopo completo (e por que essa
// tela é bem mais simples que a lista de clientes que o admin vê na web)
// no comentário de cliente_cadastro_provider.dart.
class ClientesScreen extends ConsumerWidget {
  const ClientesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(clienteCadastroProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (c) {
          if (c == null) return const Center(child: Text('Nenhuma empresa selecionada.'));
          return _buildConteudo(c);
        },
      ),
    );
  }

  Widget _buildConteudo(ClienteCadastro c) {
    final corStatus = switch (c.status) {
      'ativo' || 'trial' => const Color(0xFF15803D),
      'suspenso' => const Color(0xFFB45309),
      _ => const Color(0xFF64748B),
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Cadastro da sua empresa na plataforma.', style: TextStyle(color: Colors.grey, fontSize: 13)),
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
                      child: Text(c.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: corStatus.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Text(statusEmpresaLabel[c.status] ?? c.status,
                          style: TextStyle(fontSize: 11, color: corStatus, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _linha('CNPJ', _formatarCnpj(c.cnpj)),
                _linha('Cidade/UF', c.municipio == null ? '—' : '${c.municipio}/${c.uf ?? ''}'),
                _linha('Segmento', c.segmentoTransporte),
                _linha('Porte', c.porte),
                _linha('Plano', c.plano == null ? '—' : (planoLabel[c.plano] ?? c.plano!)),
                _linha('Limite de veículos', c.maxVeiculos?.toString()),
                _linha('Limite de usuários', c.maxUsuarios?.toString()),
                _linha('Telefone de contato', c.telefoneContato),
                _linha('E-mail de contato', c.emailContato),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Pra atualizar telefone/e-mail de contato ou outros dados cadastrais, abra um chamado em Gestão de Chamados.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _linha(String label, String? valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Expanded(child: Text((valor == null || valor.isEmpty) ? '—' : valor, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
