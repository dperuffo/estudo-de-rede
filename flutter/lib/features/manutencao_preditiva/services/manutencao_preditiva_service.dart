import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — porta de registrarManutencaoAcao/excluirManutencaoAcao
// (manutencao-preditiva/actions.ts). Mesma tabela/formato de
// `itens_realizados` já usados pelo app Flutter de produção, mantendo os
// apps compatíveis com o mesmo histórico.
class ManutencaoPreditivaService {
  final _supabase = SupabaseService.client;

  Future<void> registrar({
    required String empresaId,
    required String placa,
    required String dataManutencao,
    double? hodometro,
    String? tecnico,
    String? oficina,
    double? custoTotal,
    required List<String> itensRealizados,
    String? obsGerais,
    String? criadoPor,
  }) async {
    if (itensRealizados.isEmpty) {
      throw Exception('Selecione ao menos um item realizado.');
    }
    final veiculo = await _supabase.from('cadastro_veiculos').select('cnpj_frota').eq('placa', placa).maybeSingle();

    await _supabase.from('manutencoes_realizadas').insert({
      'empresa_id': empresaId,
      'cnpj_frota': veiculo?['cnpj_frota'] ?? '',
      'placa': placa,
      'data_manutencao': dataManutencao,
      'hodometro': hodometro,
      'tecnico': (tecnico == null || tecnico.isEmpty) ? null : tecnico,
      'oficina': (oficina == null || oficina.isEmpty) ? null : oficina,
      'custo_total': custoTotal,
      'itens_realizados': itensRealizados,
      'obs_gerais': (obsGerais == null || obsGerais.isEmpty) ? null : obsGerais,
      'criado_por': criadoPor,
    });
  }

  Future<void> excluir(int id) async {
    await _supabase.from('manutencoes_realizadas').delete().eq('id', id);
  }
}
