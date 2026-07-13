import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — porta de enviarAvaliacaoAcao (avaliar/actions.ts). RLS
// (avaliacoes_insert_proprio) já garante user_email = quem está logado e
// empresa_id nulo ou de uma empresa que o usuário controla — aqui só
// validamos o básico de UX, igual à web.
class AvaliacoesService {
  Future<String?> enviarAvaliacao({required int estrelas, String? comentario, String? empresaId}) async {
    if (estrelas < 1 || estrelas > 5) return 'Selecione de 1 a 5 estrelas.';
    final email = AuthService().emailAtual;
    if (email == null) return 'Sessão expirada, faça login novamente.';

    try {
      await SupabaseService.client.from('avaliacoes').insert({
        'user_email': email,
        'empresa_id': empresaId,
        'estrelas': estrelas,
        'comentario': (comentario == null || comentario.trim().isEmpty) ? null : comentario.trim(),
      });
      return null;
    } on PostgrestException catch (e) {
      return 'Não foi possível enviar sua avaliação: ${e.message}';
    }
  }
}
