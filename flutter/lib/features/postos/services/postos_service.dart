import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — porta de postos/actions.ts (ativarPosto/bloquearPosto/
// desbloquearPosto/excluirPosto/registrarPreco/excluirPreco). Sem
// criarPosto/atualizarPosto (PostoForm completo, fora do escopo do v1 —
// ver comentário em postos_provider.dart).
class PostosService {
  final _supabase = SupabaseService.client;

  // Copia os dados básicos do universo ANP pra rede negociada do cliente
  // (postos_gf) — mesma lógica da web, campos operacionais ficam em branco.
  Future<String?> ativarPosto({required String cnpjAnp, required String empresaId}) async {
    try {
      final anp = await _supabase
          .from('anp_postos')
          .select('cnpj, razao_social, municipio, uf, latitude, longitude')
          .eq('cnpj', cnpjAnp)
          .maybeSingle();
      if (anp == null) return 'Posto ANP não encontrado.';

      await _supabase.from('postos_gf').insert({
        'cnpj': anp['cnpj'],
        'empresa_id': empresaId,
        'razao_social': anp['razao_social'],
        'municipio': anp['municipio'],
        'uf': anp['uf'],
        'lat': anp['latitude'],
        'lon': anp['longitude'],
        'atualizado_em': DateTime.now().toIso8601String(),
      });
      return null;
    } catch (e) {
      return 'Não foi possível ativar o posto: $e';
    }
  }

  // Bloqueio do gestor: não remove o posto da rede, só marca como não
  // liberado pra abastecimento.
  Future<String?> alternarAtivo({required String cnpj, required bool ativo}) async {
    try {
      await _supabase.from('postos_gf').update({'ativo': ativo}).eq('cnpj', cnpj);
      return null;
    } catch (e) {
      return 'Não foi possível atualizar: $e';
    }
  }

  Future<String?> excluirPosto(String cnpj) async {
    try {
      await _supabase.from('postos_gf').delete().eq('cnpj', cnpj);
      return null;
    } catch (e) {
      return 'Não foi possível remover: $e';
    }
  }

  // Cada combinação (cnpj, combustivel, data_ref) é única — reenviar a
  // mesma data faz upsert em vez de duplicar, igual à web.
  Future<String?> registrarPreco({
    required String cnpj,
    required String? empresaId,
    required String combustivel,
    required double preco,
    required String dataRef,
  }) async {
    if (combustivel.trim().isEmpty) return 'Selecione o combustível.';
    if (preco <= 0) return 'Informe um preço maior que zero.';
    try {
      final posto = await _supabase
          .from('postos_gf')
          .select('razao_social, municipio, uf')
          .eq('cnpj', cnpj)
          .maybeSingle();

      await _supabase.from('historico_precos').upsert(
        {
          'cnpj': cnpj,
          'combustivel': combustivel,
          'preco': preco,
          'data_ref': dataRef,
          'fonte': 'manual',
          'razao_social': posto?['razao_social'],
          'municipio': posto?['municipio'],
          'uf': posto?['uf'],
          'empresa_id': empresaId,
        },
        onConflict: 'cnpj,combustivel,data_ref',
      );
      return null;
    } catch (e) {
      return 'Não foi possível salvar o preço: $e';
    }
  }

  Future<String?> excluirPreco(int id) async {
    try {
      await _supabase.from('historico_precos').delete().eq('id', id);
      return null;
    } catch (e) {
      return 'Não foi possível excluir: $e';
    }
  }
}
