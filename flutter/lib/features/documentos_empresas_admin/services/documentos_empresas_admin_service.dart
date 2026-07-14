import '../../../core/services/supabase_service.dart';

// Fase FLT-4 — porta de revisarDocumentacao (src/lib/empresasDocumentos.ts).
// A checagem "só admin" já é a RLS de UPDATE em `empresas` (mesma policy
// usada em todo o resto do FLT-4) — a garantia de verdade está no banco;
// a tela só evita oferecer a ação pra quem não é admin.
class DocumentosEmpresasAdminService {
  final _supabase = SupabaseService.client;

  Future<void> revisar({
    required String empresaId,
    required String decisao, // 'aprovada' | 'rejeitada'
    String? motivo,
    required String revisadoPor,
  }) async {
    if (decisao == 'rejeitada' && (motivo == null || motivo.trim().isEmpty)) {
      throw Exception('Informe o motivo da rejeição, pra a empresa saber o que corrigir.');
    }
    await _supabase.from('empresas').update({
      'documentacao_status': decisao,
      'documentacao_revisado_em': DateTime.now().toIso8601String(),
      'documentacao_revisado_por': revisadoPor,
      'documentacao_motivo_rejeicao': decisao == 'rejeitada' ? motivo!.trim() : null,
    }).eq('id', empresaId);
  }
}
