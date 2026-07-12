import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — porta fiel de src/lib/negociacoesPostos.ts (funções
// adicionarContraproposta/decidirNegociacao/cancelarNegociacao) pro Flutter.
// Essa lógica NÃO é uma RPC no banco — é regra de negócio em várias
// chamadas sequenciais contra tabelas com RLS, hoje só existe em TS. Pra
// não divergir da web, cada passo abaixo replica exatamente a mesma
// sequência/validações do arquivo original, incluindo os dois gates de
// "aceitar" (assinatura fora de trial + documentação aprovada — Fases
// 27.125/27.149) e a substituição de negociação aceita anterior do mesmo
// par posto+cliente (Fase 27.107). "autor" é sempre "posto" aqui, porque
// esta tela só existe dentro do shell /posto.
//
// Observação pra uma próxima fase: seria mais seguro converter isso numa
// função Postgres (SECURITY DEFINER) compartilhada — assim web e app
// chamam a MESMA lógica em vez de duas implementações espelhadas à mão.

class DadosRodada {
  final String combustivel;
  final String vigenciaInicio;
  final String vigenciaFim;
  final double volumeMinimoMensal;
  final double precoUnitario;
  const DadosRodada({
    required this.combustivel,
    required this.vigenciaInicio,
    required this.vigenciaFim,
    required this.volumeMinimoMensal,
    required this.precoUnitario,
  });
}

String? validarDadosRodada(DadosRodada d) {
  if (d.combustivel.trim().isEmpty) return '"combustível" é obrigatório.';
  if (DateTime.tryParse(d.vigenciaInicio) == null) {
    return '"vigência início" precisa ser uma data válida.';
  }
  if (DateTime.tryParse(d.vigenciaFim) == null) {
    return '"vigência fim" precisa ser uma data válida.';
  }
  if (d.vigenciaFim.compareTo(d.vigenciaInicio) < 0) {
    return '"vigência fim" não pode ser antes de "vigência início".';
  }
  if (d.volumeMinimoMensal <= 0) {
    return '"volume mínimo mensal" precisa ser maior que zero.';
  }
  if (d.precoUnitario <= 0) {
    return '"preço por litro" precisa ser maior que zero.';
  }
  return null;
}

Future<void> _notificarNegociacao(String negociacaoId, String evento) async {
  try {
    await SupabaseService.client.functions.invoke(
      'negociacao-email',
      body: {'negociacao_id': negociacaoId, 'evento': evento},
    );
  } catch (_) {
    // best-effort, igual à web — nunca bloqueia a operação principal.
  }
}

// Porta de exigirDocumentacaoAprovada (src/lib/empresasDocumentos.ts).
//
// Achado real (Daniel testou criar negociação com uma conta de posto de
// verdade, não a superusuária): dava "Empresa não encontrada" mesmo com o
// CNPJ certo. Causa: a checagem original fazia um SELECT direto em
// `empresas` pra ler a documentação da empresa CLIENTE — mas a policy
// `empresas_select_membro` só libera SELECT pra quem é membro/admin/
// superusuário daquela empresa, e um posto nunca é membro da empresa do
// cliente. Corrigido chamando a nova RPC SECURITY DEFINER
// `status_documentacao_empresa_publico` (mesmo padrão de
// nome_empresa_publico/empresa_id_do_cnpj: bypassa RLS só pra devolver 2
// campos não-sensíveis). O mesmo bug existe na função TS original
// (exigirDocumentacaoAprovada na web) — nunca apareceu lá porque só foi
// testado com a conta superusuária, que bypassa RLS.
Future<String?> _exigirDocumentacaoAprovada(String empresaId, String contexto) async {
  final linhas = await SupabaseService.client
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

class ResultadoCriarNegociacao {
  final String? id;
  final String? erro;
  const ResultadoCriarNegociacao.ok(this.id) : erro = null;
  const ResultadoCriarNegociacao.erro(this.erro) : id = null;
}

class NegociacoesService {
  final _supabase = SupabaseService.client;

  Future<String?> decidirNegociacao(String negociacaoId, {required bool aceitar}) async {
    final email = AuthService().emailAtual;

    final negociacao = await _supabase
        .from('negociacoes_postos')
        .select('id, status, rodada_atual, empresa_posto_id, empresa_cliente_id')
        .eq('id', negociacaoId)
        .maybeSingle();
    if (negociacao == null) return 'Negociação não encontrada.';
    if (negociacao['status'] != 'pendente_posto') {
      return 'Não é a sua vez de responder nesta negociação.';
    }

    final empresaPostoId = negociacao['empresa_posto_id'] as String?;
    final empresaClienteId = negociacao['empresa_cliente_id'] as String?;

    // Fase 27.125 — gate de assinatura: posto em trial não pode aceitar.
    if (aceitar && empresaPostoId != null) {
      final empresa =
          await _supabase.from('empresas').select('status').eq('id', empresaPostoId).maybeSingle();
      if (empresa?['status'] == 'trial') {
        return 'Este posto ainda está no período de teste. Para aceitar negociações e operar na '
            'plataforma, assine um plano em Assinatura.';
      }
    }

    // Fase 27.149 — gate de documentação societária aprovada.
    if (aceitar && empresaPostoId != null) {
      final erroDocumentacao = await _exigirDocumentacaoAprovada(empresaPostoId, 'Aceitar esta negociação');
      if (erroDocumentacao != null) return erroDocumentacao;
    }

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

    // Fase 27.107 — encerra qualquer outra negociação já aceita do mesmo
    // par posto+cliente antes de marcar esta como aceita.
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
    if (status != 'pendente_posto') {
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
        'autor': 'posto',
        'combustivel': dados.combustivel,
        'vigencia_inicio': dados.vigenciaInicio,
        'vigencia_fim': dados.vigenciaFim,
        'volume_minimo_mensal': dados.volumeMinimoMensal,
        'preco_unitario': dados.precoUnitario,
        'decisao': 'pendente',
      });

      await _supabase.from('negociacoes_postos').update({
        'status': 'pendente_cliente',
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

  // Porta de criarNegociacao (negociacoesPostos.ts) + a parte do lado posto
  // de criarNegociacaoAcao (negociacoes/actions.ts). Só cobre o caso
  // "posto cria negociação com um cliente que JÁ existe na FNI" — o
  // provisionamento automático de posto novo (quando é o CLIENTE que cria
  // a negociação e informa e-mail de contato do posto) não se aplica aqui,
  // porque esta tela só existe do lado posto.
  Future<ResultadoCriarNegociacao> criarNegociacao({
    required String empresaPostoId,
    required String cnpjCliente,
    required DadosRodada dados,
  }) async {
    final erroValidacao = validarDadosRodada(dados);
    if (erroValidacao != null) return ResultadoCriarNegociacao.erro(erroValidacao);

    final cnpjNormalizado = cnpjCliente.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();
    if (cnpjNormalizado.isEmpty) {
      return const ResultadoCriarNegociacao.erro('Informe o CNPJ do cliente.');
    }

    final empresaClienteId =
        await _supabase.rpc('empresa_id_do_cnpj', params: {'p_cnpj': cnpjNormalizado}) as String?;
    if (empresaClienteId == null) {
      return const ResultadoCriarNegociacao.erro(
        'Nenhum cliente encontrado com esse CNPJ. Confira se o cliente já é cadastrado na FNI.',
      );
    }

    final erroDocumentacao = await _exigirDocumentacaoAprovada(empresaClienteId, 'Criar uma negociação');
    if (erroDocumentacao != null) return ResultadoCriarNegociacao.erro(erroDocumentacao);

    final email = AuthService().emailAtual;

    final clienteNome =
        await _supabase.rpc('nome_empresa_publico', params: {'p_empresa_id': empresaClienteId}) as String?;
    final postoNome =
        await _supabase.rpc('nome_empresa_publico', params: {'p_empresa_id': empresaPostoId}) as String?;

    try {
      final negociacao = await _supabase.from('negociacoes_postos').insert({
        'empresa_cliente_id': empresaClienteId,
        'empresa_posto_id': empresaPostoId,
        'posto_cnpj': '',
        'origem': 'posto',
        'status': 'pendente_cliente',
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
        'autor': 'posto',
        'combustivel': dados.combustivel,
        'vigencia_inicio': dados.vigenciaInicio,
        'vigencia_fim': dados.vigenciaFim,
        'volume_minimo_mensal': dados.volumeMinimoMensal,
        'preco_unitario': dados.precoUnitario,
        'decisao': 'pendente',
      });

      await _notificarNegociacao(negociacaoId, 'nova_proposta');
      return ResultadoCriarNegociacao.ok(negociacaoId);
    } on PostgrestException catch (e) {
      return ResultadoCriarNegociacao.erro(e.message);
    }
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
