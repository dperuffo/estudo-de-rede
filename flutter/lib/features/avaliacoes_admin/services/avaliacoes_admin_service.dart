import '../../../core/services/supabase_service.dart';

// Fase FLT-4 — porta de responderAvaliacaoAcao (avaliacoes/actions.ts).
class AvaliacoesAdminService {
  final _supabase = SupabaseService.client;

  Future<void> responder({required String avaliacaoId, required String resposta, required String respondidoPor}) async {
    final respostaLimpa = resposta.trim();
    if (respostaLimpa.isEmpty) {
      throw Exception('Escreva uma resposta.');
    }
    await _supabase.from('avaliacoes').update({
      'resposta_admin': respostaLimpa,
      'respondido_por': respondidoPor,
      'respondido_em': DateTime.now().toIso8601String(),
    }).eq('id', avaliacaoId);
  }
}
