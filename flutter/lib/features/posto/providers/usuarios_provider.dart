import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — Usuários (visão posto), porta de usuarios/page.tsx +
// usuarios/actions.ts. Diferença deliberada em relação à web: a web lista
// TODOS os usuários que a RLS deixa o usuário logado enxergar (sem filtro
// de empresa no código — o comentário lá mesmo explica que o isolamento é
// só via RLS). Aqui, como o shell /posto sempre tem uma única empresa
// atual, filtramos explicitamente por `usuarios_empresas.empresa_id`, que
// dá um resultado mais útil pro dono do posto ("quem tem acesso ao MEU
// posto") em vez de "quem a RLS deixa eu ver" (que podem coincidir, mas a
// intenção da tela aqui é claramente escopada à própria empresa).
class UsuarioDoPosto {
  final String email;
  final String? nome;
  final String? perfil;
  final String? segmento;
  final bool ativo;
  final bool mfaHabilitado;
  final String? cpf;
  final String? telefone;
  final String? role;

  const UsuarioDoPosto({
    required this.email,
    this.nome,
    this.perfil,
    this.segmento,
    required this.ativo,
    required this.mfaHabilitado,
    this.cpf,
    this.telefone,
    this.role,
  });
}

final usuariosPostoProvider = FutureProvider.autoDispose<List<UsuarioDoPosto>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final supabase = SupabaseService.client;

  final vinculosRaw = await supabase
      .from('usuarios_empresas')
      .select('user_email, role')
      .eq('empresa_id', empresaId) as List;
  final roles = <String, String?>{};
  for (final v in vinculosRaw) {
    final m = v as Map<String, dynamic>;
    roles[m['user_email'] as String] = m['role'] as String?;
  }
  if (roles.isEmpty) return [];

  final usuariosRaw = await supabase
      .from('usuarios_app')
      .select('email, nome, perfil, segmento, ativo, mfa_habilitado, cpf, telefone')
      .inFilter('email', roles.keys.toList())
      .order('nome') as List;

  return usuariosRaw.map((m) {
    final mm = m as Map<String, dynamic>;
    final email = mm['email'] as String;
    return UsuarioDoPosto(
      email: email,
      nome: mm['nome'] as String?,
      perfil: mm['perfil'] as String?,
      segmento: mm['segmento'] as String?,
      ativo: mm['ativo'] as bool? ?? false,
      mfaHabilitado: mm['mfa_habilitado'] as bool? ?? false,
      cpf: mm['cpf'] as String?,
      telefone: mm['telefone'] as String?,
      role: roles[email],
    );
  }).toList();
});

final usuarioDetalheProvider = FutureProvider.autoDispose.family<UsuarioDoPosto?, String>((ref, email) async {
  final lista = await ref.watch(usuariosPostoProvider.future);
  for (final u in lista) {
    if (u.email == email) return u;
  }
  return null;
});
