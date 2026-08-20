import '../../../core/services/supabase_service.dart';

// Fase agendamento-patio (04/08/2026, item 8 do benchmark FNI vs KMM, Grupo
// 2) — porta de agendamentos-patio/actions.ts (web). A checagem de conflito
// de doca é feita aqui no cliente antes do insert/update (mesma lógica da
// web: mesma empresa + mesma doca + janela sobreposta + status não
// cancelado), já que não existe um endpoint HTTP próprio nesta parte do
// app — tudo passa direto pelo Supabase client com RLS.
class AgendamentosPatioService {
  final _supabase = SupabaseService.client;

  Future<String?> _conflitoDeDoca({
    required String empresaId,
    required String doca,
    required DateTime janelaInicio,
    required DateTime janelaFim,
    String? ignorarId,
  }) async {
    var query = _supabase
        .from('agendamentos_patio')
        .select('id, janela_inicio, fretes(titulo)')
        .eq('empresa_id', empresaId)
        .eq('doca', doca)
        .neq('status', 'cancelado')
        .lt('janela_inicio', janelaFim.toIso8601String())
        .gt('janela_fim', janelaInicio.toIso8601String());

    if (ignorarId != null) query = query.neq('id', ignorarId);

    final rows = await query.limit(1) as List;
    if (rows.isEmpty) return null;

    final conflito = rows.first as Map<String, dynamic>;
    final frete = conflito['fretes'] as Map<String, dynamic>?;
    final inicio = DateTime.parse(conflito['janela_inicio'] as String);
    final horario =
        '${inicio.hour.toString().padLeft(2, '0')}:${inicio.minute.toString().padLeft(2, '0')}';
    return 'A doca "$doca" já tem um agendamento às $horario (frete "${frete?['titulo'] ?? 'sem título'}"). Escolha outro horário ou outra doca.';
  }

  // Retorna uma mensagem de erro (String) em caso de falha, ou null se deu certo.
  Future<String?> criar({
    required String freteId,
    required String empresaId,
    required String tipo,
    required String localLabel,
    String? doca,
    required DateTime janelaInicio,
    required DateTime janelaFim,
    String? observacoes,
    String? criadoPor,
  }) async {
    if (!janelaFim.isAfter(janelaInicio))
      return 'O fim da janela precisa ser depois do início.';

    if (doca != null && doca.isNotEmpty) {
      final conflito = await _conflitoDeDoca(
          empresaId: empresaId,
          doca: doca,
          janelaInicio: janelaInicio,
          janelaFim: janelaFim);
      if (conflito != null) return conflito;
    }

    try {
      await _supabase.from('agendamentos_patio').insert({
        'empresa_id': empresaId,
        'frete_id': freteId,
        'tipo': tipo,
        'local_label': localLabel,
        'doca': (doca?.isEmpty ?? true) ? null : doca,
        'janela_inicio': janelaInicio.toIso8601String(),
        'janela_fim': janelaFim.toIso8601String(),
        'observacoes': (observacoes?.isEmpty ?? true) ? null : observacoes,
        'criado_por': criadoPor,
      });
      return null;
    } catch (e) {
      final texto = e.toString();
      if (texto.contains('agendamentos_patio_frete_tipo_unico')) {
        return 'Esse frete já tem um agendamento de ${tipo == 'coleta' ? 'carga' : 'descarga'}. Cancele o atual antes de criar outro.';
      }
      return 'Não foi possível agendar: $texto';
    }
  }

  Future<String?> reagendar({
    required String id,
    required String empresaId,
    String? doca,
    required DateTime janelaInicio,
    required DateTime janelaFim,
    String? observacoes,
  }) async {
    if (!janelaFim.isAfter(janelaInicio))
      return 'O fim da janela precisa ser depois do início.';

    if (doca != null && doca.isNotEmpty) {
      final conflito = await _conflitoDeDoca(
        empresaId: empresaId,
        doca: doca,
        janelaInicio: janelaInicio,
        janelaFim: janelaFim,
        ignorarId: id,
      );
      if (conflito != null) return conflito;
    }

    try {
      await _supabase.from('agendamentos_patio').update({
        'janela_inicio': janelaInicio.toIso8601String(),
        'janela_fim': janelaFim.toIso8601String(),
        'doca': (doca?.isEmpty ?? true) ? null : doca,
        'observacoes': (observacoes?.isEmpty ?? true) ? null : observacoes,
        'status': 'agendado',
        'atualizado_em': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return null;
    } catch (e) {
      return 'Não foi possível reagendar: $e';
    }
  }

  Future<void> confirmar(String id) async {
    await _supabase
        .from('agendamentos_patio')
        .update({
          'status': 'confirmado',
          'atualizado_em': DateTime.now().toIso8601String()
        })
        .eq('id', id)
        .eq('status', 'agendado');
  }

  Future<void> cancelar(String id) async {
    await _supabase.from('agendamentos_patio').update({
      'status': 'cancelado',
      'atualizado_em': DateTime.now().toIso8601String()
    }).eq('id', id);
  }
}
