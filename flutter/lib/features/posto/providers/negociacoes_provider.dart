import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — Negociações da visão Posto, espelhando
// src/app/(dashboard)/negociacoes/page.tsx e negociacoesPostos.ts da web.
// Esta tela SÓ atende o lado posto (souPosto sempre true aqui — o app
// Flutter roteia perfil "posto" pro shell /posto, que só existe nesse
// contexto), diferente da web onde a mesma tela serve os dois lados.

const statusNegociacao = ['pendente_posto', 'pendente_cliente', 'aceita', 'recusada', 'cancelada'];

const statusNegociacaoLabel = <String, String>{
  'pendente_posto': 'Aguardando posto',
  'pendente_cliente': 'Aguardando cliente',
  'aceita': 'Aceita',
  'recusada': 'Recusada',
  'cancelada': 'Cancelada',
};

const produtosPosto = [
  'Gasolina Comum',
  'Gasolina Aditivada',
  'Gasolina Alta Octanagem',
  'Etanol Comum',
  'Etanol Aditivado',
  'Diesel S-10 Comum',
  'Diesel S-10 Aditivado',
  'Diesel S-500 Comum',
  'Diesel S-500 Aditivado',
  'GNV',
  'GLP',
];

class NegociacaoResumo {
  final String id;
  final String postoCnpj;
  final String status;
  final int rodadaAtual;
  final String criadoEm;
  final String atualizadoEm;
  final String? atualizadoPor;
  final String? clienteNome;
  final String? postoNome;
  final String? vigenciaInicio;
  final String? vigenciaFim;

  const NegociacaoResumo({
    required this.id,
    required this.postoCnpj,
    required this.status,
    required this.rodadaAtual,
    required this.criadoEm,
    required this.atualizadoEm,
    this.atualizadoPor,
    this.clienteNome,
    this.postoNome,
    this.vigenciaInicio,
    this.vigenciaFim,
  });

  factory NegociacaoResumo.fromMap(Map<String, dynamic> m) => NegociacaoResumo(
        id: m['id'].toString(),
        postoCnpj: m['posto_cnpj'] as String? ?? '',
        status: m['status'] as String? ?? '',
        rodadaAtual: (m['rodada_atual'] as num?)?.toInt() ?? 1,
        criadoEm: m['criado_em'] as String? ?? '',
        atualizadoEm: m['atualizado_em'] as String? ?? '',
        atualizadoPor: m['atualizado_por'] as String?,
        clienteNome: m['cliente_nome'] as String?,
        postoNome: m['posto_nome'] as String?,
        vigenciaInicio: m['vigencia_inicio'] as String?,
        vigenciaFim: m['vigencia_fim'] as String?,
      );

  bool vigenteEm(String hojeIso) =>
      status == 'aceita' &&
      vigenciaInicio != null &&
      vigenciaFim != null &&
      vigenciaInicio!.compareTo(hojeIso) <= 0 &&
      vigenciaFim!.compareTo(hojeIso) >= 0;
}

// Busca as até 500 negociações mais recentes do posto (mesmo limite da
// web) — os filtros de status/vigência são aplicados em memória na tela,
// em vez de uma query nova por aba (o volume é pequeno o bastante pra isso
// ser mais simples do que reimplementar cada filtro como query separada).
final negociacoesPostoProvider = FutureProvider.autoDispose<List<NegociacaoResumo>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];

  final rows = await SupabaseService.client
      .from('negociacoes_postos')
      .select(
        'id, posto_cnpj, status, rodada_atual, criado_em, atualizado_em, atualizado_por, cliente_nome, posto_nome, vigencia_inicio, vigencia_fim',
      )
      .eq('empresa_posto_id', empresaId)
      .order('atualizado_em', ascending: false)
      .limit(500);

  return rows.map((m) => NegociacaoResumo.fromMap(m as Map<String, dynamic>)).toList();
});

String hojeIsoUtc() => DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc());
