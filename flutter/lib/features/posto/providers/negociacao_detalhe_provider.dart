import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — detalhe de uma negociação + histórico de rodadas, espelhando
// src/app/(dashboard)/negociacoes/[id]/page.tsx da web (parte de leitura —
// as ações de aceitar/recusar/contrapropor ficam em negociacoes_service.dart).

class RodadaNegociacao {
  final String id;
  final int numeroRodada;
  final String autor;
  final String combustivel;
  final String vigenciaInicio;
  final String vigenciaFim;
  final double volumeMinimoMensal;
  final double precoUnitario;
  final String decisao;

  const RodadaNegociacao({
    required this.id,
    required this.numeroRodada,
    required this.autor,
    required this.combustivel,
    required this.vigenciaInicio,
    required this.vigenciaFim,
    required this.volumeMinimoMensal,
    required this.precoUnitario,
    required this.decisao,
  });

  factory RodadaNegociacao.fromMap(Map<String, dynamic> m) => RodadaNegociacao(
        id: m['id'].toString(),
        numeroRodada: (m['numero_rodada'] as num).toInt(),
        autor: m['autor'] as String? ?? '',
        combustivel: m['combustivel'] as String? ?? '',
        vigenciaInicio: m['vigencia_inicio'] as String? ?? '',
        vigenciaFim: m['vigencia_fim'] as String? ?? '',
        volumeMinimoMensal: (m['volume_minimo_mensal'] as num?)?.toDouble() ?? 0,
        precoUnitario: (m['preco_unitario'] as num?)?.toDouble() ?? 0,
        decisao: m['decisao'] as String? ?? 'pendente',
      );
}

class NegociacaoDetalhe {
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

  const NegociacaoDetalhe({
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
  // Fase FLT-2 — esta tela só existe dentro do shell /posto, então "minha
  // vez de responder" é sempre do ponto de vista do posto.
  bool get minhaVezDeResponder => status == 'pendente_posto';
  RodadaNegociacao? get ultimaRodada => rodadas.isEmpty ? null : rodadas.last;
}

final negociacaoDetalheProvider =
    FutureProvider.autoDispose.family<NegociacaoDetalhe, String>((ref, id) async {
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
    final usuario = await supabase
        .from('usuarios_app')
        .select('nome')
        .eq('email', atualizadoPor)
        .maybeSingle();
    final nome = usuario?['nome'] as String?;
    nomeAtualizadoPor = (nome != null && nome.isNotEmpty) ? nome : atualizadoPor;
  }

  final rodadasRaw = await supabase
      .from('negociacoes_postos_rodadas')
      .select()
      .eq('negociacao_id', id)
      .order('numero_rodada', ascending: true);

  return NegociacaoDetalhe(
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
