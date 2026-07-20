import '../../../core/services/supabase_service.dart';

// Fase FLT-Ações-Sugeridas — porta de acoes-sugeridas/actions.ts. Pedido do
// Daniel: "Aba de Ações Sugeridas tem que estar no PWA cliente também".
//
// Mapa tipo -> RPC de execução específica (mesmo motivo da web: cada tipo
// grava numa tabela diferente, não dá pra ter uma RPC genérica de
// "aprovar").
const _rpcExecucaoPorTipo = {
  'cnh_vencida': 'executar_acao_bloquear_motorista',
  'posto_acima_media': 'executar_acao_remover_posto_rede',
  'hodometro_fora_padrao': 'executar_acao_ajustar_hodometro',
  'volume_tanque': 'executar_acao_limitar_volume_diario',
  'geo_distancia': 'executar_acao_limitar_intervalo',
  'preco_regiao': 'executar_acao_revisar_preco_regiao',
};

class AcoesSugeridasService {
  final _supabase = SupabaseService.client;

  // Roda a detecção de base (anomalias_abastecimento) primeiro — mesmo
  // motivo da web (ver acoes-sugeridas/actions.ts): sem isso,
  // volume_tanque/geo_distancia/hodometro_fora_padrao/preco_regiao ficam
  // presos nos últimos dados coletados, porque só existem em
  // acoes_sugeridas a partir de linhas em anomalias_abastecimento.
  Future<({String? erro, int? inseridas})> detectar({required String empresaId}) async {
    try {
      final resultados = await Future.wait([
        _supabase.rpc('detectar_anomalias_abastecimento', params: {'p_empresa_id': empresaId}),
        _supabase.rpc('detectar_acoes_cnh_vencida', params: {'p_empresa_id': empresaId}),
        _supabase.rpc('detectar_acoes_posto_caro', params: {'p_empresa_id': empresaId}),
        _supabase.rpc('detectar_acoes_hodometro', params: {'p_empresa_id': empresaId}),
        _supabase.rpc('detectar_acoes_volume_tanque', params: {'p_empresa_id': empresaId}),
        _supabase.rpc('detectar_acoes_geo_distancia', params: {'p_empresa_id': empresaId}),
        _supabase.rpc('detectar_acoes_preco_regiao', params: {'p_empresa_id': empresaId}),
      ]);
      // O 1º resultado (detecção de base) não conta pro total de "ações
      // novas" mostrado ao usuário — só os 6 detectores de ações contam.
      final inseridas = resultados.skip(1).fold<int>(0, (soma, r) => soma + ((r as num?)?.toInt() ?? 0));
      return (erro: null, inseridas: inseridas);
    } catch (e) {
      return (erro: 'Não foi possível rodar a detecção: $e', inseridas: null);
    }
  }

  Future<String?> aprovarEExecutar({required int id, required String tipo}) async {
    final nomeRpc = _rpcExecucaoPorTipo[tipo];
    if (nomeRpc == null) return 'Tipo de ação desconhecido: $tipo';
    try {
      await _supabase.rpc(nomeRpc, params: {'p_acao_id': id});
      return null;
    } catch (e) {
      return 'Não foi possível executar a ação: $e';
    }
  }

  Future<String?> rejeitar(int id) async {
    try {
      await _supabase.rpc('rejeitar_acao_sugerida', params: {'p_acao_id': id});
      return null;
    } catch (e) {
      return 'Não foi possível rejeitar: $e';
    }
  }
}
