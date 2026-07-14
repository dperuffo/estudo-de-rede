import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../posto/services/negociacoes_service.dart' show DadosRodada, validarDadosRodada;

// Fase FLT-3 — porta de src/lib/negociacoesPostos.ts pro lado CLIENTE
// ("autor" sempre "cliente" aqui, espelho de negociacoes_service.dart que
// cobre "autor" sempre "posto" desde a FLT-2 — mesma observação da web:
// seria mais seguro ter isso como função Postgres compartilhada em vez de
// 2 implementações espelhadas à mão).
//
// Diferenças reais do lado cliente na porta 1:1 de negociacoesPostos.ts:
//   - criarNegociacao: SEMPRE checa documentação aprovada da empresa
//     CLIENTE (na web isso vale pros 2 lados — abrir uma negociação exige
//     documentação do cliente aprovada, não só do posto).
//   - decidirNegociacao (aceitar): os gates de assinatura/documentação só
//     existem pro lado POSTO na web (`params.autor === "posto"`) — do lado
//     cliente aceitar não tem esses 2 gates.
// Fora do escopo: "provisionarEmpresaPostoTrial" (Fase 27.125) — quando o
// CNPJ do posto não existe na FNI e o cliente informa um e-mail de
// contato, a web provisiona a conta do posto em trial e convida via
// Supabase Auth Admin API (inviteUserByEmail), que exige Service Role Key
// — o app não tem (só a publishable key). Aqui, se o CNPJ não for
// encontrado, a negociação é criada do mesmo jeito com empresaPostoId
// nulo (mesmo fallback que a web já tem quando NÃO informa e-mail).

class ResultadoCriarNegociacaoCliente {
  final String? id;
  final String? erro;
  const ResultadoCriarNegociacaoCliente.ok(this.id) : erro = null;
  const ResultadoCriarNegociacaoCliente.erro(this.erro) : id = null;
}

class NegociacoesClienteService {
  final _supabase = SupabaseService.client;

  Future<String?> _exigirDocumentacaoAprovada(String empresaId, String contexto) async {
    final linhas = await _supabase
        .rpc('status_documentacao_empresa_publico', params: {'p_empresa_id': empresaId}) as List;
    if (linhas.isEmpty) return 'Empresa não encontrada.';
    final empresa = linhas.first as Map<String, dynamic>;
    if (empresa['documentacao_status'] == 'aprovada') return null;
    final situacao = switch (empresa['documentacao_status']) {
      'pendente' => 'está em análise pelo admin',
      'rejeitada' => 'foi rejeitada e precisa ser reenviada',
      _ => 'ainda não foi enviada',
    };
    return '$contexto exige documentação societária aprovada — a de "${empresa['nome']}" $situacao. '
        'Acesse Documentos para enviar/corrigir.';
  }

  Future<void> _notificarNegociacao(String negociacaoId, String evento) async {
    try {
      await _supabase.functions.invoke('negociacao-email', body: {'negociacao_id': negociacaoId, 'evento': evento});
    } catch (_) {
      // best-effort, igual à web — nunca bloqueia a operação principal.
    }
  }

  Future<ResultadoCriarNegociacaoCliente> criarNegociacao({
    required String empresaClienteId,
    required String cnpjPosto,
    required DadosRodada dados,
  }) async {
    final erroValidacao = validarDadosRodada(dados);
    if (erroValidacao != null) return ResultadoCriarNegociacaoCliente.erro(erroValidacao);

    final cnpjNormalizado = cnpjPosto.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();
    if (cnpjNormalizado.isEmpty) {
      return const ResultadoCriarNegociacaoCliente.erro('Informe o CNPJ do posto.');
    }

    final erroDocumentacao = await _exigirDocumentacaoAprovada(empresaClienteId, 'Criar uma negociação');
    if (erroDocumentacao != null) return ResultadoCriarNegociacaoCliente.erro(erroDocumentacao);

    final empresaPostoId =
        await _supabase.rpc('empresa_id_do_cnpj', params: {'p_cnpj': cnpjNormalizado}) as String?;

    final email = AuthService().emailAtual;
    final clienteNome =
        await _supabase.rpc('nome_empresa_publico', params: {'p_empresa_id': empresaClienteId}) as String?;
    final postoNome = empresaPostoId != null
        ? await _supabase.rpc('nome_empresa_publico', params: {'p_empresa_id': empresaPostoId}) as String?
        : null;

    try {
      final negociacao = await _supabase.from('negociacoes_postos').insert({
        'empresa_cliente_id': empresaClienteId,
        'empresa_posto_id': empresaPostoId,
        'posto_cnpj': cnpjNormalizado,
        'origem': 'cliente',
        'status': 'pendente_posto',
        'rodada_atual': 1,
        'criado_por': email,
        'atualizado_por': email,
        'cliente_nome': clienteNome,
        'posto_nome': postoNome,
      }).select('id').single();

      final negociacaoId = negociacao['id'].toString();

      await _supabase.from('negociacoes_postos_rodadas').insert({
        'negociacao_id': negociacaoId,
        'numero_rodada': 1,
        'autor': 'cliente',
        'combustivel': dados.combustivel,
        'vigencia_inicio': dados.vigenciaInicio,
        'vigencia_fim': dados.vigenciaFim,
        'volume_minimo_mensal': dados.volumeMinimoMensal,
        'preco_unitario': dados.precoUnitario,
        'decisao': 'pendente',
      });

      await _notificarNegociacao(negociacaoId, 'nova_proposta');
      return ResultadoCriarNegociacaoCliente.ok(negociacaoId);
    } on PostgrestException catch (e) {
      return ResultadoCriarNegociacaoCliente.erro(e.message);
    }
  }

  Future<String?> adicionarContraproposta(String negociacaoId, DadosRodada dados) async {
    final erroValidacao = validarDadosRodada(dados);
    if (erroValidacao != null) return erroValidacao;

    final email = AuthService().emailAtual;

    final negociacao = await _supabase
        .from('negociacoes_postos')
        .select('id, status, rodada_atual')
        .eq('id', negociacaoId)
        .maybeSingle();
    if (negociacao == null) return 'Negociação não encontrada.';

    final status = negociacao['status'] as String;
    if (status == 'aceita' || status == 'recusada' || status == 'cancelada') {
      return 'Esta negociação já foi encerrada e não aceita novas rodadas.';
    }
    if (status != 'pendente_cliente') {
      return 'Não é a sua vez de responder nesta negociação.';
    }

    final rodadaAtual = (negociacao['rodada_atual'] as num).toInt();
    final novaRodada = rodadaAtual + 1;
    final agora = DateTime.now().toUtc().toIso8601String();

    try {
      await _supabase
          .from('negociacoes_postos_rodadas')
          .update({'decisao': 'contraproposta', 'decidido_em': agora, 'decidido_por': email})
          .eq('negociacao_id', negociacaoId)
          .eq('numero_rodada', rodadaAtual);

      await _supabase.from('negociacoes_postos_rodadas').insert({
        'negociacao_id': negociacaoId,
        'numero_rodada': novaRodada,
        'autor': 'cliente',
        'combustivel': dados.combustivel,
        'vigencia_inicio': dados.vigenciaInicio,
        'vigencia_fim': dados.vigenciaFim,
        'volume_minimo_mensal': dados.volumeMinimoMensal,
        'preco_unitario': dados.precoUnitario,
        'decisao': 'pendente',
      });

      await _supabase.from('negociacoes_postos').update({
        'status': 'pendente_posto',
        'rodada_atual': novaRodada,
        'atualizado_em': agora,
        'atualizado_por': email,
      }).eq('id', negociacaoId);
    } on PostgrestException catch (e) {
      return e.message;
    }

    await _notificarNegociacao(negociacaoId, 'contraproposta');
    return null;
  }

  Future<String?> decidirNegociacao(String negociacaoId, {required bool aceitar}) async {
    final email = AuthService().emailAtual;

    final negociacao = await _supabase
        .from('negociacoes_postos')
        .select('id, status, rodada_atual, empresa_posto_id, empresa_cliente_id')
        .eq('id', negociacaoId)
        .maybeSingle();
    if (negociacao == null) return 'Negociação não encontrada.';
    if (negociacao['status'] != 'pendente_cliente') {
      return 'Não é a sua vez de responder nesta negociação.';
    }

    // Sem gates de assinatura/documentação aqui — na web, esses 2 gates
    // (Fases 27.125/27.149) só valem pra `autor === "posto"` decidindo.

    final empresaPostoId = negociacao['empresa_posto_id'] as String?;
    final empresaClienteId = negociacao['empresa_cliente_id'] as String?;
    final agora = DateTime.now().toUtc().toIso8601String();
    final rodadaAtual = (negociacao['rodada_atual'] as num).toInt();

    Map<String, dynamic> rodadaDecidida;
    try {
      rodadaDecidida = await _supabase
          .from('negociacoes_postos_rodadas')
          .update({'decisao': aceitar ? 'aceita' : 'recusada', 'decidido_em': agora, 'decidido_por': email})
          .eq('negociacao_id', negociacaoId)
          .eq('numero_rodada', rodadaAtual)
          .select('combustivel, vigencia_inicio, vigencia_fim, volume_minimo_mensal, preco_unitario')
          .single();
    } on PostgrestException catch (e) {
      return e.message;
    }

    final novoStatus = aceitar ? 'aceita' : 'recusada';

    if (novoStatus == 'aceita' && empresaPostoId != null && empresaClienteId != null) {
      try {
        await _supabase
            .from('negociacoes_postos')
            .update({'status': 'cancelada', 'atualizado_em': agora, 'atualizado_por': email})
            .eq('empresa_posto_id', empresaPostoId)
            .eq('empresa_cliente_id', empresaClienteId)
            .eq('status', 'aceita')
            .neq('id', negociacaoId);
      } on PostgrestException catch (e) {
        return e.message;
      }
    }

    final atualizacaoCabecalho = <String, dynamic>{
      'status': novoStatus,
      'atualizado_em': agora,
      'atualizado_por': email,
      if (novoStatus == 'aceita') ...{
        'combustivel': rodadaDecidida['combustivel'],
        'vigencia_inicio': rodadaDecidida['vigencia_inicio'],
        'vigencia_fim': rodadaDecidida['vigencia_fim'],
        'volume_minimo_mensal': rodadaDecidida['volume_minimo_mensal'],
        'preco_unitario': rodadaDecidida['preco_unitario'],
      },
    };

    try {
      await _supabase.from('negociacoes_postos').update(atualizacaoCabecalho).eq('id', negociacaoId);
    } on PostgrestException catch (e) {
      return e.message;
    }

    await _notificarNegociacao(negociacaoId, aceitar ? 'aceita' : 'recusada');
    return null;
  }

  Future<String?> cancelarNegociacao(String negociacaoId) async {
    final email = AuthService().emailAtual;
    try {
      await _supabase
          .from('negociacoes_postos')
          .update({
            'status': 'cancelada',
            'atualizado_em': DateTime.now().toUtc().toIso8601String(),
            'atualizado_por': email,
          })
          .eq('id', negociacaoId)
          .inFilter('status', ['pendente_posto', 'pendente_cliente']);
    } on PostgrestException catch (e) {
      return e.message;
    }
    return null;
  }
}
