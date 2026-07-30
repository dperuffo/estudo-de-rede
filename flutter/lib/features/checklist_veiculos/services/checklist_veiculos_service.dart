import '../../../core/services/supabase_service.dart';
import '../providers/checklist_veiculos_provider.dart';

// Fase Indicadores-da-Frota C (30/07/2026) — porta de checklist-veiculos/
// actions.ts. Mesmo cuidado da web: cnpj_frota resolvido por lookup direto
// na placa (nunca comparação de CNPJ entre tabelas), pra não reintroduzir a
// classe de bug RLS já corrigida em atualizarVeiculo.
class ChecklistVeiculosService {
  final _supabase = SupabaseService.client;

  Future<void> registrarInspecao({
    required String empresaId,
    required String placa,
    required String dataInspecao,
    double? hodometro,
    String? responsavel,
    required Map<String, bool> itensConforme,
    required Map<String, String?> itensObservacao,
    String? criadoPor,
  }) async {
    final veiculo = await _supabase.from('cadastro_veiculos').select('cnpj_frota').eq('placa', placa).maybeSingle();

    final inspecao = await _supabase
        .from('inspecoes_veiculos')
        .insert({
          'empresa_id': empresaId,
          'cnpj_frota': veiculo?['cnpj_frota'] ?? '',
          'placa': placa,
          'data_inspecao': dataInspecao,
          'hodometro': hodometro,
          'responsavel': responsavel,
          'criado_por': criadoPor,
        })
        .select('id')
        .single();
    final inspecaoId = inspecao['id'];

    final itens = itensInspecao
        .map((item) => {
              'inspecao_id': inspecaoId,
              'empresa_id': empresaId,
              'item': item,
              'critico': itensCriticos.contains(item),
              'conforme': itensConforme[item] ?? true,
              'observacao': itensObservacao[item],
            })
        .toList();
    await _supabase.from('inspecoes_veiculos_itens').insert(itens);
  }

  Future<void> resolverItem(int id, String? resolvidoPor) async {
    await _supabase.from('inspecoes_veiculos_itens').update({
      'resolvido_em': DateTime.now().toIso8601String(),
      'resolvido_por': resolvidoPor,
    }).eq('id', id);
  }

  Future<void> excluirInspecao(int id) async {
    await _supabase.from('inspecoes_veiculos').delete().eq('id', id);
  }
}
