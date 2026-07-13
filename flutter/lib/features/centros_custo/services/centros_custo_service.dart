import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — porta de centros-custo/actions.ts (criarCentroCusto/
// atualizarCentroCusto/alocarMotoristasEmLoteAcao/
// desalocarMotoristasEmLoteAcao). Sem as ações de veículo (ver comentário
// em centros_custo_provider.dart).
class CentrosCustoService {
  final _supabase = SupabaseService.client;

  Future<({String? erro, String? id})> criarCentroCusto({
    required String empresaId,
    required String nome,
    String? codigo,
    String? responsavel,
    String? descricao,
  }) async {
    final nomeLimpo = nome.trim();
    if (nomeLimpo.isEmpty) return (erro: 'Nome do centro de custo é obrigatório.', id: null);
    try {
      final email = _supabase.auth.currentUser?.email;
      final row = await _supabase
          .from('centros_custo')
          .insert({
            'nome': nomeLimpo,
            'codigo': (codigo == null || codigo.trim().isEmpty) ? null : codigo.trim(),
            'responsavel': (responsavel == null || responsavel.trim().isEmpty) ? null : responsavel.trim(),
            'descricao': (descricao == null || descricao.trim().isEmpty) ? null : descricao.trim(),
            'empresa_id': empresaId,
            'ativo': true,
            'criado_por': email,
          })
          .select('id')
          .single();
      return (erro: null, id: row['id'] as String);
    } catch (e) {
      return (erro: 'Não foi possível salvar: $e', id: null);
    }
  }

  Future<String?> atualizarCentroCusto({
    required String id,
    required String nome,
    String? codigo,
    String? responsavel,
    String? descricao,
    required bool ativo,
  }) async {
    final nomeLimpo = nome.trim();
    if (nomeLimpo.isEmpty) return 'Nome do centro de custo é obrigatório.';
    try {
      await _supabase.from('centros_custo').update({
        'nome': nomeLimpo,
        'codigo': (codigo == null || codigo.trim().isEmpty) ? null : codigo.trim(),
        'responsavel': (responsavel == null || responsavel.trim().isEmpty) ? null : responsavel.trim(),
        'descricao': (descricao == null || descricao.trim().isEmpty) ? null : descricao.trim(),
        'ativo': ativo,
        'atualizado_em': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  // Motoristas não têm histórico de alocação (diferente de veículos) — só
  // a coluna `centro_custo_id`, então é um único UPDATE em lote via
  // `.in()`, igual à web.
  Future<String?> alocarMotoristas({required String centroCustoId, required List<String> motoristaIds}) async {
    if (motoristaIds.isEmpty) return 'Selecione pelo menos um motorista.';
    try {
      await _supabase.from('motoristas').update({'centro_custo_id': centroCustoId}).inFilter('id', motoristaIds);
      return null;
    } catch (e) {
      return 'Não foi possível alocar: $e';
    }
  }

  Future<String?> desalocarMotoristas({required List<String> motoristaIds}) async {
    if (motoristaIds.isEmpty) return 'Selecione pelo menos um motorista.';
    try {
      await _supabase.from('motoristas').update({'centro_custo_id': null}).inFilter('id', motoristaIds);
      return null;
    } catch (e) {
      return 'Não foi possível remover: $e';
    }
  }
}
