import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — porta fiel de src/lib/gruposEconomicos.ts (criação/edição de
// Rede de Postos, vincular/desvincular posto) pro Flutter. Mesmo "achado
// real" de negociacoes_service.dart: a checagem de documentação aprovada
// (_exigirDocumentacaoAprovada) só existe em código TS, não na RPC nem na
// RLS — confirmado lendo a função criar_rede_posto_self_service no banco
// (não valida documentação sozinha). Por isso replicamos aqui também, senão
// o Flutter deixaria passar uma criação/vínculo que a web bloquearia.
//
// A checagem "só pode editar/vincular postos de uma Rede da qual já faz
// parte" (ehAdminSuperusuarioOuMembroDaRede na web) fica só na RLS aqui —
// não replicamos em código porque, pro escopo desta tela (só mostra/edita
// a Rede da PRÓPRIA empresa atual, nunca por id arbitrário digitado), não
// há como o usuário tentar mexer na Rede de outro grupo por esta UI.
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

class RedePostosService {
  final _supabase = SupabaseService.client;

  // Retorna o id da Rede criada, ou null + preenche [erroOut] em caso de erro.
  Future<({String? id, String? erro})> criarRede({
    required String nome,
    String? cnpjMatriz,
    required String empresaId,
  }) async {
    final nomeTrim = nome.trim();
    if (nomeTrim.isEmpty) return (id: null, erro: 'Nome é obrigatório.');

    final erroDoc = await _exigirDocumentacaoAprovada(empresaId, 'Criar uma Rede de Postos');
    if (erroDoc != null) return (id: null, erro: erroDoc);

    final cnpjLimpo = (cnpjMatriz == null || cnpjMatriz.trim().isEmpty) ? null : cnpjMatriz.trim();

    final Map<String, dynamic> resultado;
    try {
      resultado = await _supabase.rpc('criar_rede_posto_self_service', params: {
        'p_nome': nomeTrim,
        'p_cnpj_matriz': cnpjLimpo,
        'p_empresa_id': empresaId,
      }) as Map<String, dynamic>;
    } on PostgrestException catch (e) {
      return (id: null, erro: e.message);
    }

    if (resultado['ok'] != true) {
      return (id: null, erro: resultado['erro'] as String? ?? 'Não foi possível salvar.');
    }
    return (id: resultado['id'] as String, erro: null);
  }

  Future<String?> atualizarRede({
    required String redeId,
    required String nome,
    String? cnpjMatriz,
    required bool ativo,
  }) async {
    final nomeTrim = nome.trim();
    if (nomeTrim.isEmpty) return 'Nome é obrigatório.';
    try {
      await _supabase.from('grupos_economicos').update({
        'nome': nomeTrim,
        'cnpj_matriz': (cnpjMatriz == null || cnpjMatriz.trim().isEmpty) ? null : cnpjMatriz.trim(),
        'ativo': ativo,
        'atualizado_em': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', redeId);
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    }
  }

  Future<String?> vincularPosto({required String redeId, required String empresaId}) async {
    final erroDoc = await _exigirDocumentacaoAprovada(empresaId, 'Vincular esta empresa a um grupo');
    if (erroDoc != null) return erroDoc;
    try {
      await _supabase.from('grupos_economicos_empresas').insert({
        'grupo_economico_id': redeId,
        'empresa_id': empresaId,
      });
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    }
  }

  Future<String?> desvincularPosto({required String vinculoId}) async {
    try {
      await _supabase.from('grupos_economicos_empresas').delete().eq('id', vinculoId);
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    }
  }
}
