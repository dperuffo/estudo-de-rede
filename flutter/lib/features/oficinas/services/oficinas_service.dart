import '../../../core/services/supabase_service.dart';

// Fase Onda-2 (benchmark TicketLog, item #5) — Rede de Oficinas
// Credenciadas com Orçamento, fluxo simples (v1, mesmo escopo da web): o
// cliente solicita, o gestor registra o retorno recebido por telefone/
// e-mail (sem portal pra oficina responder na v1) e decide aceitar/
// recusar. Porta de oficinas/actions.ts.
//
// Fase marketplace-pecas (04/08/2026, item 7 do benchmark FNI vs KMM,
// Grupo 2) — evoluiu de "1 solicitação = 1 oficina" pra "1 pedido pode ir
// pra N oficinas". `solicitacoes_orcamento_oficina` virou
// `propostas_orcamento_oficina` (1 linha por oficina) + nova
// `pedidos_orcamento_oficina` (1 linha por pedido do cliente) — ver
// migração marketplace_pecas_multi_fornecedor no repo web.
class OficinasService {
  final _supabase = SupabaseService.client;

  // Substitui o antigo `solicitar` (1 oficina) — cria 1 pedido + N
  // propostas (1 por oficina escolhida), todas partindo de "solicitado".
  Future<void> solicitarMulti({
    required String empresaId,
    required List<String> oficinaIds,
    String? placa,
    required String descricaoServico,
    String? criadoPor,
  }) async {
    final pedido = await _supabase
        .from('pedidos_orcamento_oficina')
        .insert({
          'empresa_id': empresaId,
          'placa': placa,
          'descricao_servico': descricaoServico,
          'criado_por': criadoPor,
        })
        .select('id')
        .single();
    final pedidoId = pedido['id'] as String;

    await _supabase.from('propostas_orcamento_oficina').insert([
      for (final oficinaId in oficinaIds)
        {
          'pedido_id': pedidoId,
          'empresa_id': empresaId,
          'oficina_id': oficinaId,
          'placa': placa,
          'descricao_servico': descricaoServico,
          'criado_por': criadoPor,
        },
    ]);
  }

  // Registra o retorno da oficina (valor, prazo) que o gestor recebeu por
  // fora da plataforma — não é um "aceite" automático, só documenta a
  // cotação recebida (não existe portal pra oficina responder na v1).
  Future<void> registrarResposta(String id, {required double valorOrcado, String? prazoExecucao, String? observacoes}) async {
    await _supabase.from('propostas_orcamento_oficina').update({
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
  // Best-effort, mesma blindagem da web (decidirOrcamentoAcao). Ao aceitar,
  // também marca o pedido pai como "decidido" e recusa automaticamente as
  // demais propostas do mesmo pedido — só uma oficina executa o serviço.
  Future<void> decidir(String id, String decisao, String? criadoPor) async {
    await _supabase.from('propostas_orcamento_oficina').update({
      'status': decisao,
      'atualizado_em': DateTime.now().toIso8601String(),
    }).eq('id', id);

    if (decisao == 'aceito') {
      try {
        final proposta = await _supabase
            .from('propostas_orcamento_oficina')
            .select('pedido_id, oficina_id, empresa_id, placa, descricao_servico, valor_orcado, oficinas_credenciadas(nome, cnpj)')
            .eq('id', id)
            .maybeSingle();
        if (proposta == null) return;
        final pedidoId = proposta['pedido_id'] as String?;

        if (pedidoId != null) {
          await _supabase.from('pedidos_orcamento_oficina').update({
            'status': 'decidido',
            'oficina_vencedora_id': proposta['oficina_id'],
            'atualizado_em': DateTime.now().toIso8601String(),
          }).eq('id', pedidoId);

          await _supabase
              .from('propostas_orcamento_oficina')
              .update({'status': 'recusado', 'atualizado_em': DateTime.now().toIso8601String()})
              .eq('pedido_id', pedidoId)
              .neq('id', id)
              .inFilter('status', ['solicitado', 'respondido']);
        }

        final valorOrcado = (proposta['valor_orcado'] as num?)?.toDouble();
        if (valorOrcado == null || valorOrcado <= 0) return;
        final oficina = proposta['oficinas_credenciadas'] as Map<String, dynamic>?;
        final placa = proposta['placa'] as String?;
        await _supabase.from('contas_pagar').insert({
          'empresa_id': proposta['empresa_id'],
          'origem': 'orcamento_oficina',
          'referencia_id': id,
          'credor_nome': oficina?['nome'] as String? ?? 'Oficina credenciada',
          'credor_cnpj': oficina?['cnpj'] as String?,
          'descricao': '${proposta['descricao_servico']}${placa != null ? ' — $placa' : ''}',
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
