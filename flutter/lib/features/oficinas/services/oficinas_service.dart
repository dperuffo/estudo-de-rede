import '../../../core/services/supabase_service.dart';

// Fase Onda-2 (benchmark TicketLog, item #5) — Rede de Oficinas
// Credenciadas com Orçamento, fluxo simples (v1, mesmo escopo da web): o
// cliente solicita, o gestor registra o retorno recebido por telefone/
// e-mail (sem portal pra oficina responder na v1) e decide aceitar/
// recusar. Porta de oficinas/actions.ts.
class OficinasService {
  final _supabase = SupabaseService.client;

  Future<void> solicitar({
    required String empresaId,
    required String oficinaId,
    String? placa,
    required String descricaoServico,
    String? criadoPor,
  }) async {
    await _supabase.from('solicitacoes_orcamento_oficina').insert({
      'empresa_id': empresaId,
      'oficina_id': oficinaId,
      'placa': placa,
      'descricao_servico': descricaoServico,
      'criado_por': criadoPor,
    });
  }

  // Registra o retorno da oficina (valor, prazo) que o gestor recebeu por
  // fora da plataforma — não é um "aceite" automático, só documenta a
  // cotação recebida (não existe portal pra oficina responder na v1).
  Future<void> registrarResposta(String id, {required double valorOrcado, String? prazoExecucao, String? observacoes}) async {
    await _supabase.from('solicitacoes_orcamento_oficina').update({
      'valor_orcado': valorOrcado,
      'prazo_execucao': prazoExecucao,
      'observacoes_oficina': observacoes,
      'status': 'respondido',
      'respondido_em': DateTime.now().toIso8601String(),
      'atualizado_em': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  // Fase Onda-2 (pedido do Daniel: "Custos com multas e oficinas de
  // manutenção devem entrar no contas a pagar do cliente para gestão
  // financeira") — só ao ACEITAR existe de fato uma obrigação financeira.
  // Best-effort, mesma blindagem da web (decidirOrcamentoAcao).
  Future<void> decidir(String id, String decisao, String? criadoPor) async {
    await _supabase.from('solicitacoes_orcamento_oficina').update({
      'status': decisao,
      'atualizado_em': DateTime.now().toIso8601String(),
    }).eq('id', id);

    if (decisao == 'aceito') {
      try {
        final solicitacao = await _supabase
            .from('solicitacoes_orcamento_oficina')
            .select('empresa_id, placa, descricao_servico, valor_orcado, oficinas_credenciadas(nome, cnpj)')
            .eq('id', id)
            .maybeSingle();
        if (solicitacao == null) return;
        final valorOrcado = (solicitacao['valor_orcado'] as num?)?.toDouble();
        if (valorOrcado == null || valorOrcado <= 0) return;
        final oficina = solicitacao['oficinas_credenciadas'] as Map<String, dynamic>?;
        final placa = solicitacao['placa'] as String?;
        await _supabase.from('contas_pagar').insert({
          'empresa_id': solicitacao['empresa_id'],
          'origem': 'orcamento_oficina',
          'referencia_id': id,
          'credor_nome': oficina?['nome'] as String? ?? 'Oficina credenciada',
          'credor_cnpj': oficina?['cnpj'] as String?,
          'descricao': '${solicitacao['descricao_servico']}${placa != null ? ' — $placa' : ''}',
          'valor_original': valorOrcado,
          'vencimento': DateTime.now().toIso8601String().substring(0, 10),
          'criado_por': criadoPor,
        });
      } catch (_) {
        // best-effort
      }
    }
  }
}
