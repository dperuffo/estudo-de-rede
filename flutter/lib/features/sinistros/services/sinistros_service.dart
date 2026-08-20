import '../../../core/services/supabase_service.dart';

// Fase Indicadores-da-Frota C (30/07/2026) — porta de sinistros/actions.ts.
// Mesmo cuidado da web: cnpj_frota resolvido por lookup direto na placa.
class SinistrosService {
  final _supabase = SupabaseService.client;

  Future<void> criar({
    required String empresaId,
    required String placa,
    required String dataSinistro,
    required String tipo,
    String? gravidade,
    String? motoristaNome,
    bool houveVitima = false,
    double? custoEstimado,
    String? localOcorrencia,
    String? descricao,
    String? criadoPor,
  }) async {
    final veiculo = await _supabase
        .from('cadastro_veiculos')
        .select('cnpj_frota')
        .eq('placa', placa)
        .maybeSingle();
    await _supabase.from('sinistros_veiculos').insert({
      'empresa_id': empresaId,
      'cnpj_frota': veiculo?['cnpj_frota'] ?? '',
      'placa': placa,
      'motorista_nome': motoristaNome,
      'data_sinistro': dataSinistro,
      'tipo': tipo,
      'gravidade': gravidade,
      'houve_vitima': houveVitima,
      'custo_estimado': custoEstimado,
      'local_ocorrencia': localOcorrencia,
      'descricao': descricao,
      'criado_por': criadoPor,
    });
  }

  Future<void> excluir(int id) async {
    await _supabase.from('sinistros_veiculos').delete().eq('id', id);
  }
}
