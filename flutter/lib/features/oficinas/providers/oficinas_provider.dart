import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase Onda-2 (benchmark TicketLog, item #5) — Rede de Oficinas
// Credenciadas com Orçamento (cliente), porta de oficinas/page.tsx +
// src/lib/oficinas.ts. Catálogo é gerido pelo admin na web
// (/administracao/oficinas-credenciadas); aqui só leitura + solicitação.

const especialidadesOficina = [
  'Mecânica geral',
  'Elétrica',
  'Funilaria/Pintura',
  'Pneus/Alinhamento',
  'Ar-condicionado',
  'Freios',
  'Suspensão',
  'Diesel/Injeção eletrônica',
  'Troca de óleo',
  'Socorro 24h',
];

const statusOrcamentoLabel = {
  'solicitado': 'Aguardando retorno',
  'respondido': 'Orçamento recebido',
  'aceito': 'Aceito',
  'recusado': 'Recusado',
};

const statusOrcamentoCorFundo = {
  'solicitado': Color(0xFFFEF3C7),
  'respondido': Color(0xFFDBEAFE),
  'aceito': Color(0xFFDCFCE7),
  'recusado': Color(0xFFF1F5F9),
};

const statusOrcamentoCorTexto = {
  'solicitado': Color(0xFF92400E),
  'respondido': Color(0xFF1E40AF),
  'aceito': Color(0xFF166534),
  'recusado': Color(0xFF475569),
};

class Oficina {
  final String id;
  final String nome;
  final List<String> especialidades;
  final String? telefone;
  final String? email;
  final String? municipio;
  final String? uf;
  final double? avaliacaoMedia;

  const Oficina({
    required this.id,
    required this.nome,
    required this.especialidades,
    this.telefone,
    this.email,
    this.municipio,
    this.uf,
    this.avaliacaoMedia,
  });

  factory Oficina.fromMap(Map<String, dynamic> m) => Oficina(
        id: m['id'] as String,
        nome: m['nome'] as String,
        especialidades: ((m['especialidades'] as List?) ?? []).cast<String>(),
        telefone: m['telefone'] as String?,
        email: m['email'] as String?,
        municipio: m['municipio'] as String?,
        uf: m['uf'] as String?,
        avaliacaoMedia: (m['avaliacao_media'] as num?)?.toDouble(),
      );
}

typedef FiltrosOficinas = ({String? uf, String? especialidade});

final catalogoOficinasProvider = FutureProvider.autoDispose.family<List<Oficina>, FiltrosOficinas>((ref, filtros) async {
  var query = SupabaseService.client
      .from('oficinas_credenciadas')
      .select('id, nome, especialidades, telefone, email, municipio, uf, avaliacao_media')
      .eq('ativo', true);
  if (filtros.uf != null) query = query.eq('uf', filtros.uf!);
  if (filtros.especialidade != null) query = query.contains('especialidades', [filtros.especialidade]);
  final rows = await query.order('nome') as List;
  return rows.map((r) => Oficina.fromMap(r as Map<String, dynamic>)).toList();
});

class SolicitacaoOrcamento {
  final String id;
  final String? placa;
  final String descricaoServico;
  final String status;
  final double? valorOrcado;
  final String? prazoExecucao;
  final String? observacoesOficina;
  final String criadoEm;
  final String? oficinaNome;

  const SolicitacaoOrcamento({
    required this.id,
    this.placa,
    required this.descricaoServico,
    required this.status,
    this.valorOrcado,
    this.prazoExecucao,
    this.observacoesOficina,
    required this.criadoEm,
    this.oficinaNome,
  });

  factory SolicitacaoOrcamento.fromMap(Map<String, dynamic> m) {
    final oficina = m['oficinas_credenciadas'] as Map<String, dynamic>?;
    return SolicitacaoOrcamento(
      id: m['id'] as String,
      placa: m['placa'] as String?,
      descricaoServico: m['descricao_servico'] as String,
      status: m['status'] as String? ?? 'solicitado',
      valorOrcado: (m['valor_orcado'] as num?)?.toDouble(),
      prazoExecucao: m['prazo_execucao'] as String?,
      observacoesOficina: m['observacoes_oficina'] as String?,
      criadoEm: m['criado_em'] as String? ?? '',
      oficinaNome: oficina?['nome'] as String?,
    );
  }
}

final minhasSolicitacoesOficinaProvider = FutureProvider.autoDispose<List<SolicitacaoOrcamento>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client
      .from('solicitacoes_orcamento_oficina')
      .select(
          'id, placa, descricao_servico, status, valor_orcado, prazo_execucao, observacoes_oficina, criado_em, oficinas_credenciadas(nome)')
      .eq('empresa_id', empresaId)
      .order('criado_em', ascending: false)
      .limit(100) as List;
  return rows.map((r) => SolicitacaoOrcamento.fromMap(r as Map<String, dynamic>)).toList();
});
