import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/usuarios_provider.dart';

// Fase FLT-2 — Usuários (lista), porta de usuarios/page.tsx (ver escopo
// reduzido no comentário de usuarios_provider.dart/usuarios_service.dart).
class UsuariosScreen extends ConsumerWidget {
  const UsuariosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(usuariosPostoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Usuários')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/posto/usuarios/novo'),
        icon: const Icon(Icons.person_add),
        label: const Text('Convidar'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (usuarios) {
          if (usuarios.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nenhum usuário vinculado a este posto ainda.', style: TextStyle(color: Colors.grey)),
              ),
            );
          }
          final ativos = usuarios.where((u) => u.ativo).length;
          final comMfa = usuarios.where((u) => u.mfaHabilitado).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              Row(
                children: [
                  Expanded(child: _indicador('Total', usuarios.length.toString())),
                  const SizedBox(width: 8),
                  Expanded(child: _indicador('Ativos', ativos.toString())),
                  const SizedBox(width: 8),
                  Expanded(child: _indicador('Com MFA', comMfa.toString())),
                ],
              ),
              const SizedBox(height: 16),
              ...usuarios.map((u) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => context.push('/posto/usuarios/${Uri.encodeComponent(u.email)}'),
                      title: Text(u.nome?.isNotEmpty == true ? u.nome! : u.email,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u.email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: [
                              if (!u.ativo)
                                _chip('Inativo', const Color(0xFF64748B))
                              else
                                _chip('Ativo', const Color(0xFF16A34A)),
                              _chip(u.mfaHabilitado ? 'MFA ativado' : 'MFA pendente',
                                  u.mfaHabilitado ? const Color(0xFF16A34A) : const Color(0xFFB45309)),
                            ],
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      isThreeLine: true,
                    ),
                  )),
            ],
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

  Widget _chip(String texto, Color cor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
        child: Text(texto, style: TextStyle(fontSize: 10, color: cor, fontWeight: FontWeight.w600)),
      );
}
