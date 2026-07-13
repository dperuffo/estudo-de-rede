import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — porta de lgpd/actions.ts (só as 2 actions que o perfil
// posto/cliente usa — `marcarExclusaoExecutada` é admin-only, fora do
// escopo do shell /posto).
class LgpdService {
  final _supabase = SupabaseService.client;

  Future<String?> registrarRevogacaoConsentimento() async {
    final email = AuthService().emailAtual;
    if (email == null) return 'Sessão expirada, faça login novamente.';
    try {
      await _supabase.from('lgpd_consents').insert({
        'email': email,
        'tipo': 'revogacao',
      });
      return null;
    } catch (e) {
      return 'Não foi possível registrar a revogação: $e';
    }
  }

  Future<String?> solicitarExclusaoDados({required String empresaId}) async {
    final email = AuthService().emailAtual;
    if (email == null) return 'Sessão expirada, faça login novamente.';
    try {
      final existente = await _supabase
          .from('lgpd_exclusoes')
          .select('id')
          .eq('email', email)
          .eq('empresa_id', empresaId)
          .eq('status', 'pendente')
          .maybeSingle();
      if (existente != null) {
        return 'Já existe uma solicitação pendente para este cliente/empresa.';
      }
      await _supabase.from('lgpd_exclusoes').insert({
        'empresa_id': empresaId,
        'email': email,
        'status': 'pendente',
      });
      return null;
    } catch (e) {
      return 'Não foi possível registrar a solicitação: $e';
    }
  }
}
