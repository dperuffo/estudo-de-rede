import '../../../core/services/supabase_service.dart';

// Fase 27.15x — porta de src/app/(dashboard)/antifraude/actions.ts (web).
// Mesma ideia: os tipos de regra moram na mesma tabela, `condicoes` é
// montado conforme o tipo — só os campos preenchidos do tipo selecionado
// entram no jsonb.
//
// Fase Antifraude→Ações-Sugeridas — o tipo "localizacao_posto" foi migrado
// pra Ações Sugeridas (tipo "posto_nao_autorizado", ver
// features/acoes_sugeridas). Removido daqui (postosPermitidosCnpj/
// distanciaMaximaKm) pra não aceitar mais criação/edição desse tipo; linhas
// antigas continuam no banco, só não são mais acessíveis por esta tela.
class AntifraudeService {
  final _supabase = SupabaseService.client;

  String? get _email => _supabase.auth.currentUser?.email;

  Map<String, dynamic> _montarCondicoes({
    required String tipo,
    num? litrosMaxDia,
    num? valorMaxAbastecimento,
    num? intervaloMinimoHoras,
    String? horarioInicio,
    String? horarioFim,
  }) {
    if (tipo == 'limite_valor_quantidade') {
      final c = <String, dynamic>{};
      if (litrosMaxDia != null) c['litros_max_dia'] = litrosMaxDia;
      if (valorMaxAbastecimento != null) c['valor_max_abastecimento'] = valorMaxAbastecimento;
      return c;
    }
    // janela_tempo_frequencia
    final c = <String, dynamic>{};
    if (intervaloMinimoHoras != null) c['intervalo_minimo_horas'] = intervaloMinimoHoras;
    if ((horarioInicio != null && horarioInicio.isNotEmpty) || (horarioFim != null && horarioFim.isNotEmpty)) {
      c['horario_permitido'] = {'inicio': horarioInicio, 'fim': horarioFim};
    }
    return c;
  }

  Future<String?> criar({
    required String empresaId,
    required String nome,
    required String tipo,
    required String escopo,
    String? escopoReferencia,
    required String vigenciaInicio,
    String? vigenciaFim,
    num? litrosMaxDia,
    num? valorMaxAbastecimento,
    num? intervaloMinimoHoras,
    String? horarioInicio,
    String? horarioFim,
  }) async {
    if (nome.trim().isEmpty) return 'Nome é obrigatório.';
    if (escopo != 'empresa' && (escopoReferencia == null || escopoReferencia.trim().isEmpty)) {
      return 'Selecione o motorista ou o veículo ao qual a regra se aplica.';
    }
    final condicoes = _montarCondicoes(
      tipo: tipo,
      litrosMaxDia: litrosMaxDia,
      valorMaxAbastecimento: valorMaxAbastecimento,
      intervaloMinimoHoras: intervaloMinimoHoras,
      horarioInicio: horarioInicio,
      horarioFim: horarioFim,
    );
    if (condicoes.isEmpty) return 'Preencha ao menos uma condição da regra.';

    try {
      await _supabase.from('regras_antifraude').insert({
        'empresa_id': empresaId,
        'nome': nome.trim(),
        'tipo': tipo,
        'escopo': escopo,
        'escopo_referencia': escopo == 'empresa' ? null : escopoReferencia,
        'condicoes': condicoes,
        'vigencia_inicio': vigenciaInicio,
        'vigencia_fim': vigenciaFim,
        'status': 'Ativo',
        'criado_por': _email,
      });
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  Future<String?> atualizar({
    required String id,
    required String nome,
    required String tipo,
    required String escopo,
    String? escopoReferencia,
    required String vigenciaInicio,
    String? vigenciaFim,
    required bool ativo,
    num? litrosMaxDia,
    num? valorMaxAbastecimento,
    num? intervaloMinimoHoras,
    String? horarioInicio,
    String? horarioFim,
  }) async {
    if (nome.trim().isEmpty) return 'Nome é obrigatório.';
    if (escopo != 'empresa' && (escopoReferencia == null || escopoReferencia.trim().isEmpty)) {
      return 'Selecione o motorista ou o veículo ao qual a regra se aplica.';
    }
    final condicoes = _montarCondicoes(
      tipo: tipo,
      litrosMaxDia: litrosMaxDia,
      valorMaxAbastecimento: valorMaxAbastecimento,
      intervaloMinimoHoras: intervaloMinimoHoras,
      horarioInicio: horarioInicio,
      horarioFim: horarioFim,
    );
    if (condicoes.isEmpty) return 'Preencha ao menos uma condição da regra.';

    try {
      await _supabase.from('regras_antifraude').update({
        'nome': nome.trim(),
        'tipo': tipo,
        'escopo': escopo,
        'escopo_referencia': escopo == 'empresa' ? null : escopoReferencia,
        'condicoes': condicoes,
        'vigencia_inicio': vigenciaInicio,
        'vigencia_fim': vigenciaFim,
        'status': ativo ? 'Ativo' : 'Inativo',
        'atualizado_em': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  Future<void> alternarStatus({required String id, required bool ativo}) async {
    await _supabase
        .from('regras_antifraude')
        .update({'status': ativo ? 'Ativo' : 'Inativo', 'atualizado_em': DateTime.now().toIso8601String()}).eq(
            'id', id);
  }

  Future<void> excluir(String id) async {
    await _supabase.from('regras_antifraude').delete().eq('id', id);
  }

  Future<void> marcarFalhasComoLidas() async {
    await _supabase
        .from('antifraude_verificacoes_falhas')
        .update({'lida_em': DateTime.now().toIso8601String()}).isFilter('lida_em', null);
  }
}
