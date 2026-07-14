import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — porta de alternarPermissao (permissoes/actions.ts). Upsert
// com onConflict na constraint única (funcionalidade, perfil, empresa_id)
// — a RLS de permissoes_perfil garante que ninguém escreve fora do que
// tem direito (ver comentário em permissoes_provider.dart).
class PermissoesService {
  final _supabase = SupabaseService.client;

  Future<void> alternar({
    required String funcionalidade,
    required String perfil,
    required bool permitido,
    required String empresaId,
    required String atualizadoPor,
  }) async {
    await _supabase.from('permissoes_perfil').upsert(
      {
        'funcionalidade': funcionalidade,
        'perfil': perfil,
        'empresa_id': empresaId,
        'permitido': permitido,
        'atualizado_em': DateTime.now().toIso8601String(),
        'atualizado_por': atualizadoPor,
      },
      onConflict: 'funcionalidade,perfil,empresa_id',
    );
  }
}
