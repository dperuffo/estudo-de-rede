import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — porta de anomalias/actions.ts.
class AnomaliasService {
  final _supabase = SupabaseService.client;

  Future<({String? erro, int? inseridas})> detectar({required String empresaId}) async {
    try {
      final resultado =
          await _supabase.rpc('detectar_anomalias_abastecimento', params: {'p_empresa_id': empresaId});
      return (erro: null, inseridas: (resultado as num?)?.toInt() ?? 0);
    } catch (e) {
      return (erro: 'Não foi possível rodar a detecção: $e', inseridas: null);
    }
  }

  Future<String?> marcarRevisada(int id) async {
    try {
      final email = _supabase.auth.currentUser?.email;
      await _supabase
          .from('anomalias_abastecimento')
          .update({'revisado_em': DateTime.now().toIso8601String(), 'revisado_por': email}).eq('id', id);
      return null;
    } catch (e) {
      return 'Não foi possível marcar como revisado: $e';
    }
  }

  Future<String?> desfazerRevisao(int id) async {
    try {
      await _supabase
          .from('anomalias_abastecimento')
          .update({'revisado_em': null, 'revisado_por': null}).eq('id', id);
      return null;
    } catch (e) {
      return 'Não foi possível desfazer: $e';
    }
  }
}
