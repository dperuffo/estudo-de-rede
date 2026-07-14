import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../posto/providers/negociacao_detalhe_provider.dart' show RodadaNegociacao;

// Fase FLT-3 — detalhe de uma negociação + histórico de rodadas (cliente),
// espelho de negociacao_detalhe_provider.dart (lado posto, FLT-2). Mesma
// query, só troca "minha vez de responder" pra `pendente_cliente`.
class NegociacaoDetalheCliente {
  final String id;
  final String? empresaPostoId;
  final String? empresaClienteId;
  final String postoCnpj;
  final String status;
  final int rodadaAtual;
  final String atualizadoEm;
  final String? atualizadoPor;
  final String? nomeAtualizadoPor;
  final String? clienteNome;
  final String? postoNome;
  final List<RodadaNegociacao> rodadas;

  const NegociacaoDetalheCliente({
    required this.id,
    this.empresaPostoId,
    this.empresaClienteId,
    required this.postoCnpj,
    required this.status,
    required this.rodadaAtual,
    required this.atualizadoEm,
    this.atualizadoPor,
    this.nomeAtualizadoPor,
    this.clienteNome,
    this.postoNome,
    required this.rodadas,
  });

  bool get emAndamento => status == 'pendente_posto' || status == 'pendente_cliente';
  // Fase FLT-3 — esta tela só existe dentro do shell do cliente, então
  // "minha vez de responder" é sempre do ponto de vista do cliente.
  bool get minhaVezDeResponder => status == 'pendente_cliente';
  RodadaNegociacao? get ultimaRodada => rodadas.isEmpty ? null : rodadas.last;
}

final negociacaoDetalheClienteProvider =
    FutureProvider.autoDispose.family<NegociacaoDetalheCliente, String>((ref, id) async {
  final supabase = SupabaseService.client;

  final negociacao = await supabase
      .from('negociacoes_postos')
      .select(
        'id, empresa_cliente_id, empresa_posto_id, posto_cnpj, status, rodada_atual, atualizado_em, atualizado_por, cliente_nome, posto_nome',
      )
      .eq('id', id)
      .single();

  String? nomeAtualizadoPor;
  final atualizadoPor = negociacao['atualizado_por'] as String?;
  if (atualizadoPor != null) {
    final usuario = await supabase.from('usuarios_app').select('nome').eq('email', atualizadoPor).maybeSingle();
    final nome = usuario?['nome'] as String?;
    nomeAtualizadoPor = (nome != null && nome.isNotEmpty) ? nome : atualizadoPor;
  }

  final rodadasRaw = await supabase
      .from('negociacoes_postos_rodadas')
      .select()
      .eq('negociacao_id', id)
      .order('numero_rodada', ascending: true);

  return NegociacaoDetalheCliente(
    id: negociacao['id'].toString(),
    empresaPostoId: negociacao['empresa_posto_id'] as String?,
    empresaClienteId: negociacao['empresa_cliente_id'] as String?,
    postoCnpj: negociacao['posto_cnpj'] as String? ?? '',
    status: negociacao['status'] as String? ?? '',
    rodadaAtual: (negociacao['rodada_atual'] as num?)?.toInt() ?? 1,
    atualizadoEm: negociacao['atualizado_em'] as String? ?? '',
    atualizadoPor: atualizadoPor,
    nomeAtualizadoPor: nomeAtualizadoPor,
    clienteNome: negociacao['cliente_nome'] as String?,
    postoNome: negociacao['posto_nome'] as String?,
    rodadas: rodadasRaw.map((m) => RodadaNegociacao.fromMap(m as Map<String, dynamic>)).toList(),
  );
});
