import '../../../core/services/supabase_service.dart';

// Fase PWA-Fretes — porta de motoristas-parceiros/actions.ts.
class MotoristaEncontrado {
  final String motoristaId;
  final String nomeCompleto;
  final String? telefone;

  const MotoristaEncontrado({required this.motoristaId, required this.nomeCompleto, this.telefone});
}

class MotoristasParceirosService {
  final _supabase = SupabaseService.client;

  Future<({MotoristaEncontrado? encontrado, String? erro})> buscarMotoristaPorDocumento(String documento) async {
    if (documento.trim().isEmpty) return (encontrado: null, erro: 'Digite o CPF ou telefone do motorista.');
    try {
      final rows = await _supabase.rpc('buscar_motorista_documento', params: {'p_documento': documento.trim()});
      final lista = rows as List;
      if (lista.isEmpty) {
        return (encontrado: null, erro: 'Nenhum motorista encontrado com esse CPF/telefone. Ele precisa já ter conta no app.');
      }
      final m = lista.first as Map<String, dynamic>;
      return (
        encontrado: MotoristaEncontrado(
          motoristaId: m['motorista_id'] as String,
          nomeCompleto: m['nome_completo'] as String? ?? '',
          telefone: m['telefone'] as String?,
        ),
        erro: null,
      );
    } catch (e) {
      return (encontrado: null, erro: e.toString());
    }
  }

  Future<String?> convidarParceiro({required String empresaId, required String motoristaId}) async {
    try {
      await _supabase.rpc('convidar_motorista_parceiro', params: {
        'p_empresa_id': empresaId,
        'p_motorista_id': motoristaId,
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
