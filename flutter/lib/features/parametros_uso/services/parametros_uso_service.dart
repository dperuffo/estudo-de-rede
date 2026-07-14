import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — porta de parametros-uso/actions.ts. Todas as 8 regras
// (fora Vínculo, que tem CRUD próprio abaixo) seguem o MESMO padrão de
// insert/alternarStatus/excluir — por isso os 2 últimos métodos são
// genéricos por nome de tabela, em vez de repetir a mesma função 8 vezes.
class ParametrosUsoService {
  final _supabase = SupabaseService.client;

  String? get _email => _supabase.auth.currentUser?.email;

  // ── Vínculo Motorista ↔ Veículo ────────────────────────────────────
  Future<String?> criarVinculo({
    required String empresaId,
    required String placa,
    required String motoristaId,
    String? dataInicio,
    String? dataFim,
    String? observacao,
  }) async {
    if (placa.trim().isEmpty || motoristaId.isEmpty) {
      return 'Veículo (placa) e motorista são obrigatórios.';
    }
    try {
      await _supabase.from('parametros_vinculo_motorista_veiculo').insert({
        'empresa_id': empresaId,
        'placa': placa.trim().toUpperCase(),
        'motorista_id': motoristaId,
        'data_inicio': dataInicio ?? DateTime.now().toIso8601String().substring(0, 10),
        'data_fim': dataFim,
        'observacao': (observacao == null || observacao.trim().isEmpty) ? null : observacao.trim(),
        'status': 'Ativo',
        'criado_por': _email,
      });
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  Future<String?> atualizarVinculo({
    required String id,
    required String placa,
    required String motoristaId,
    String? dataInicio,
    String? dataFim,
    String? observacao,
    required bool ativo,
  }) async {
    if (placa.trim().isEmpty || motoristaId.isEmpty) {
      return 'Veículo (placa) e motorista são obrigatórios.';
    }
    try {
      await _supabase.from('parametros_vinculo_motorista_veiculo').update({
        'placa': placa.trim().toUpperCase(),
        'motorista_id': motoristaId,
        'data_inicio': dataInicio ?? DateTime.now().toIso8601String().substring(0, 10),
        'data_fim': dataFim,
        'observacao': (observacao == null || observacao.trim().isEmpty) ? null : observacao.trim(),
        'status': ativo ? 'Ativo' : 'Inativo',
        'atualizado_em': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  // ── Intervalo entre Abastecimentos ──────────────────────────────────
  Future<String?> criarIntervalo({
    required String empresaId,
    required String tipo,
    String? placa,
    String? motoristaId,
    required num intervaloMinimo,
    required String unidade,
    String? observacao,
  }) async {
    if (tipo != 'Veiculo' && tipo != 'Motorista') return 'Tipo inválido.';
    if (intervaloMinimo <= 0) return 'Tipo (Veículo/Motorista) e intervalo mínimo são obrigatórios.';
    try {
      await _supabase.from('parametros_intervalo_abastecimento').insert({
        'empresa_id': empresaId,
        'tipo': tipo,
        'placa': tipo == 'Veiculo' ? placa?.trim().toUpperCase() : null,
        'motorista_id': tipo == 'Motorista' ? motoristaId : null,
        'intervalo_minimo': intervaloMinimo,
        'unidade': unidade == 'Dias' ? 'Dias' : 'Horas',
        'observacao': (observacao == null || observacao.trim().isEmpty) ? null : observacao.trim(),
        'criado_por': _email,
      });
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  // ── Valor Diário Permitido — Motorista ──────────────────────────────
  Future<String?> criarValorDiario({
    required String empresaId,
    String? motoristaId,
    required num valorMaximo,
    String? observacao,
  }) async {
    if (valorMaximo <= 0) return 'Valor máximo diário é obrigatório.';
    try {
      await _supabase.from('parametros_valor_diario_motorista').insert({
        'empresa_id': empresaId,
        'motorista_id': motoristaId,
        'valor_maximo': valorMaximo,
        'observacao': (observacao == null || observacao.trim().isEmpty) ? null : observacao.trim(),
        'criado_por': _email,
      });
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  // ── Volume Diário Permitido — Veículo ───────────────────────────────
  Future<String?> criarVolumeDiario({
    required String empresaId,
    String? placa,
    required num volumeMaximo,
    String? observacao,
  }) async {
    if (volumeMaximo <= 0) return 'Volume máximo diário é obrigatório.';
    try {
      await _supabase.from('parametros_volume_diario_veiculo').insert({
        'empresa_id': empresaId,
        'placa': placa?.trim().toUpperCase(),
        'volume_maximo': volumeMaximo,
        'observacao': (observacao == null || observacao.trim().isEmpty) ? null : observacao.trim(),
        'criado_por': _email,
      });
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  // ── Produto Abastecido ──────────────────────────────────────────────
  Future<String?> criarProduto({
    required String empresaId,
    String? placa,
    required List<String> combustiveisPermitidos,
    String? observacao,
  }) async {
    try {
      await _supabase.from('parametros_produto_abastecido').insert({
        'empresa_id': empresaId,
        'placa': placa?.trim().toUpperCase(),
        'combustiveis_permitidos': combustiveisPermitidos,
        'observacao': (observacao == null || observacao.trim().isEmpty) ? null : observacao.trim(),
        'criado_por': _email,
      });
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  // ── Variação Máx. de Hodômetro ───────────────────────────────────────
  Future<String?> criarVariacaoHodometro({
    required String empresaId,
    required String classificacao,
    String? placa,
    required num variacaoMaximaKm,
    String? observacao,
  }) async {
    if (classificacao != 'Leve' && classificacao != 'Pesado') return 'Classificação inválida.';
    if (variacaoMaximaKm <= 0) return 'Variação máxima (km) é obrigatória.';
    try {
      await _supabase.from('parametros_variacao_hodometro').insert({
        'empresa_id': empresaId,
        'classificacao': classificacao,
        'placa': placa?.trim().toUpperCase(),
        'variacao_maxima_km': variacaoMaximaKm,
        'observacao': (observacao == null || observacao.trim().isEmpty) ? null : observacao.trim(),
        'criado_por': _email,
      });
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  // ── Dias e Horários Permitidos ───────────────────────────────────────
  Future<String?> criarDiasHorarios({
    required String empresaId,
    String? classificacao,
    String? placa,
    String? motoristaId,
    required List<String> diasPermitidos,
    required String horaInicio,
    required String horaFim,
    String? observacao,
  }) async {
    if (diasPermitidos.isEmpty || horaInicio.isEmpty || horaFim.isEmpty) {
      return 'Ao menos um dia da semana e o horário de início/fim são obrigatórios.';
    }
    try {
      await _supabase.from('parametros_dias_horarios').insert({
        'empresa_id': empresaId,
        'classificacao': (classificacao == 'Leve' || classificacao == 'Pesado') ? classificacao : null,
        'placa': placa?.trim().toUpperCase(),
        'motorista_id': motoristaId,
        'dias_permitidos': diasPermitidos,
        'hora_inicio': horaInicio,
        'hora_fim': horaFim,
        'observacao': (observacao == null || observacao.trim().isEmpty) ? null : observacao.trim(),
        'criado_por': _email,
      });
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  // ── Postos Permitidos para Abastecimento ─────────────────────────────
  Future<String?> criarPostosPermitidos({
    required String empresaId,
    String? classificacao,
    String? placa,
    String? motoristaId,
    required List<String> postosCnpj,
    required String tipoLimite,
    num? valorMaximo,
    String? observacao,
  }) async {
    if (postosCnpj.isEmpty) return 'Selecione ao menos um posto permitido.';
    final tipo = (tipoLimite == 'Valor' || tipoLimite == 'Volume') ? tipoLimite : 'Sem limite';
    try {
      await _supabase.from('parametros_postos_permitidos').insert({
        'empresa_id': empresaId,
        'classificacao': (classificacao == 'Leve' || classificacao == 'Pesado') ? classificacao : null,
        'placa': placa?.trim().toUpperCase(),
        'motorista_id': motoristaId,
        'postos_cnpj': postosCnpj,
        'tipo_limite': tipo,
        'valor_maximo': tipo == 'Sem limite' ? null : valorMaximo,
        'observacao': (observacao == null || observacao.trim().isEmpty) ? null : observacao.trim(),
        'criado_por': _email,
      });
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  // ── Cota por Veículo ──────────────────────────────────────────────────
  Future<String?> criarCota({
    required String empresaId,
    required String placa,
    required String tipo,
    required num limite,
    required String periodicidade,
    String? observacao,
  }) async {
    if (placa.trim().isEmpty || (tipo != 'Valor' && tipo != 'Volume') || limite <= 0) {
      return 'Veículo, tipo de cota (Valor/Volume) e limite são obrigatórios.';
    }
    final periodicidadeValida =
        ['Abastecimento', 'Semana', 'Quinzena', 'Mes'].contains(periodicidade) ? periodicidade : 'Mes';
    try {
      await _supabase.from('parametros_cota_veiculo').insert({
        'empresa_id': empresaId,
        'placa': placa.trim().toUpperCase(),
        'tipo': tipo,
        'limite': limite,
        'periodicidade': periodicidadeValida,
        'observacao': (observacao == null || observacao.trim().isEmpty) ? null : observacao.trim(),
        'criado_por': _email,
      });
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  // ── Ações genéricas (iguais nas 8 tabelas de regra + Vínculo) ─────────
  Future<void> alternarStatus({required String tabela, required String id, required bool ativo}) async {
    await _supabase
        .from(tabela)
        .update({'status': ativo ? 'Ativo' : 'Inativo', 'atualizado_em': DateTime.now().toIso8601String()}).eq(
            'id', id);
  }

  Future<void> excluir({required String tabela, required String id}) async {
    await _supabase.from(tabela).delete().eq('id', id);
  }
}
