import '../../../core/services/supabase_service.dart';

// Fase FLT-4 — porta de descartarDuplicataAcao/confirmarDuplicataAcao
// (postos-duplicados/actions.ts). A garantia de "só admin" é a RLS ALL de
// postos_gf_possiveis_duplicados_admin — esta service só grava a decisão.
class PostosDuplicadosService {
  final _supabase = SupabaseService.client;

  Future<String?> _resolver({required String id, required String status, required String revisadoPor}) async {
    try {
      await _supabase.from('postos_gf_possiveis_duplicados').update({
        'status': status,
        'revisado_por': revisadoPor,
        'revisado_em': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  Future<String?> descartar({required String id, required String revisadoPor}) =>
      _resolver(id: id, status: 'descartado', revisadoPor: revisadoPor);

  Future<String?> confirmar({required String id, required String revisadoPor}) =>
      _resolver(id: id, status: 'confirmado_duplicata', revisadoPor: revisadoPor);
}
