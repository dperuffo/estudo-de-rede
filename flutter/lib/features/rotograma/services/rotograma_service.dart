import '../../../core/services/supabase_service.dart';
import '../providers/rotograma_provider.dart';

// Fase FLT-3 — porta de criarRotogramaAcao/atualizarRotogramaAcao/
// excluirRotogramaAcao (rotograma/actions.ts).
class RotogramaService {
  final _supabase = SupabaseService.client;

  Future<String> criar({
    required String empresaId,
    required String userEmail,
    required String origem,
    required String destino,
    String? veiculo,
    String? motorista,
    String? placa,
    String? dataViagem,
    String? carga,
    String? observacoes,
    required List<RotogramaRisco> riscos,
    required List<RotogramaParada> paradas,
  }) async {
    if (origem.trim().isEmpty || destino.trim().isEmpty) {
      throw Exception('Origem e destino são obrigatórios.');
    }
    final row = await _supabase
        .from('rotogramas')
        .insert({
          'empresa_id': empresaId,
          'user_email': userEmail,
          'origem': origem.trim(),
          'destino': destino.trim(),
          'veiculo': _ouNull(veiculo),
          'motorista': _ouNull(motorista),
          'placa': _ouNull(placa),
          'data_viagem': _ouNull(dataViagem),
          'carga': _ouNull(carga),
          'observacoes': _ouNull(observacoes),
          'riscos': riscos.map((r) => r.toMap()).toList(),
          'paradas': paradas.map((p) => p.toMap()).toList(),
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> atualizar({
    required String id,
    required String origem,
    required String destino,
    String? veiculo,
    String? motorista,
    String? placa,
    String? dataViagem,
    String? carga,
    String? observacoes,
    required List<RotogramaRisco> riscos,
    required List<RotogramaParada> paradas,
  }) async {
    if (origem.trim().isEmpty || destino.trim().isEmpty) {
      throw Exception('Origem e destino são obrigatórios.');
    }
    await _supabase.from('rotogramas').update({
      'origem': origem.trim(),
      'destino': destino.trim(),
      'veiculo': _ouNull(veiculo),
      'motorista': _ouNull(motorista),
      'placa': _ouNull(placa),
      'data_viagem': _ouNull(dataViagem),
      'carga': _ouNull(carga),
      'observacoes': _ouNull(observacoes),
      'riscos': riscos.map((r) => r.toMap()).toList(),
      'paradas': paradas.map((p) => p.toMap()).toList(),
      'atualizado_em': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> excluir(String id) async {
    await _supabase.from('rotogramas').delete().eq('id', id);
  }

  String? _ouNull(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
}
