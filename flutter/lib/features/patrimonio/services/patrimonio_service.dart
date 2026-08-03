import '../../../core/services/supabase_service.dart';

// Fase Grupo 2 (Rodopar/Datapar, item 6, 03/08/2026) — porta de
// patrimonio/actions.ts (criarAjusteAcao/excluirAjusteAcao).
class PatrimonioService {
  final _supabase = SupabaseService.client;

  Future<void> criarAjuste({
    required String empresaId,
    required String veiculoId,
    required String tipo,
    required double valor,
    required String dataAjuste,
    String? motivo,
    String? criadoPor,
  }) async {
    await _supabase.from('patrimonio_ajustes').insert({
      'empresa_id': empresaId,
      'veiculo_id': veiculoId,
      'tipo': tipo,
      'valor': valor,
      'data_ajuste': dataAjuste,
      'motivo': motivo,
      'criado_por': criadoPor,
    });
  }

  Future<void> excluirAjuste(String ajusteId) async {
    await _supabase.from('patrimonio_ajustes').delete().eq('id', ajusteId);
  }
}
