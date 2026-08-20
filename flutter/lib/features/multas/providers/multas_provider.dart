import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase Onda-2 (benchmark TicketLog, item #4) — Gestão de Multas (cliente),
// porta de multas/page.tsx + multas/[id]/page.tsx + multas/actions.ts +
// src/lib/multas.ts. Ciclo: captura manual da multa -> indicação do
// condutor (sugestão vinda do vínculo Motorista<->Veículo já existente em
// Parâmetros de Uso) -> acompanhamento até pagar/recorrer, com alerta de
// prazo pro desconto de pagamento antecipado.

const statusMultaLabel = {
  'pendente_indicacao': 'Pendente de indicação',
  'indicada': 'Condutor indicado',
  'paga': 'Paga',
  'recorrida': 'Recorrida',
  'vencida': 'Vencida',
  'cancelada': 'Cancelada',
};

const statusMultaCorFundo = {
  'pendente_indicacao': Color(0xFFFEF3C7),
  'indicada': Color(0xFFDBEAFE),
  'paga': Color(0xFFDCFCE7),
  'recorrida': Color(0xFFF3E8FF),
  'vencida': Color(0xFFFEE2E2),
  'cancelada': Color(0xFFF1F5F9),
};

const statusMultaCorTexto = {
  'pendente_indicacao': Color(0xFF92400E),
  'indicada': Color(0xFF1E40AF),
  'paga': Color(0xFF166534),
  'recorrida': Color(0xFF6B21A8),
  'vencida': Color(0xFF991B1B),
  'cancelada': Color(0xFF475569),
};

const gravidadeMultaLabel = {
  'leve': 'Leve',
  'media': 'Média',
  'grave': 'Grave',
  'gravissima': 'Gravíssima',
};

class Multa {
  final String id;
  final String empresaId;
  final String placa;
  final String? motoristaId;
  final String? motoristaNome;
  final String? numeroAit;
  final String? orgaoAutuador;
  final String? localInfracao;
  final String dataInfracao;
  final String? dataLimiteIndicacao;
  final String? descricao;
  final String? gravidade;
  final int? pontos;
  final double? valorOriginal;
  final double? valorDesconto;
  final String status;
  final String? anexoPath;
  final String? observacoes;
  final String? indicadoEm;
  final String? indicadoPor;
  final String? criadoEm;

  const Multa({
    required this.id,
    required this.empresaId,
    required this.placa,
    this.motoristaId,
    this.motoristaNome,
    this.numeroAit,
    this.orgaoAutuador,
    this.localInfracao,
    required this.dataInfracao,
    this.dataLimiteIndicacao,
    this.descricao,
    this.gravidade,
    this.pontos,
    this.valorOriginal,
    this.valorDesconto,
    required this.status,
    this.anexoPath,
    this.observacoes,
    this.indicadoEm,
    this.indicadoPor,
    this.criadoEm,
  });

  double? get valorParaExibir => valorDesconto ?? valorOriginal;

  factory Multa.fromMap(Map<String, dynamic> m) {
    final motorista = m['motoristas'] as Map<String, dynamic>?;
    return Multa(
      id: m['id'] as String,
      empresaId: m['empresa_id'] as String? ?? '',
      placa: m['placa'] as String,
      motoristaId: m['motorista_id'] as String?,
      motoristaNome: motorista?['nome_completo'] as String?,
      numeroAit: m['numero_ait'] as String?,
      orgaoAutuador: m['orgao_autuador'] as String?,
      localInfracao: m['local_infracao'] as String?,
      dataInfracao: m['data_infracao'] as String,
      dataLimiteIndicacao: m['data_limite_indicacao'] as String?,
      descricao: m['descricao'] as String?,
      gravidade: m['gravidade'] as String?,
      pontos: (m['pontos'] as num?)?.toInt(),
      valorOriginal: (m['valor_original'] as num?)?.toDouble(),
      valorDesconto: (m['valor_desconto'] as num?)?.toDouble(),
      status: m['status'] as String? ?? 'pendente_indicacao',
      anexoPath: m['anexo_path'] as String?,
      observacoes: m['observacoes'] as String?,
      indicadoEm: m['indicado_em'] as String?,
      indicadoPor: m['indicado_por'] as String?,
      criadoEm: m['criado_em'] as String?,
    );
  }
}

typedef FiltrosMultas = ({String? status});

final multasListProvider = FutureProvider.autoDispose
    .family<List<Multa>, FiltrosMultas>((ref, filtros) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  var query = SupabaseService.client
      .from('multas')
      .select(
          'id, empresa_id, placa, numero_ait, data_infracao, data_limite_indicacao, descricao, gravidade, valor_original, valor_desconto, status, motorista_id, motoristas(nome_completo)')
      .eq('empresa_id', empresaId);
  if (filtros.status != null) query = query.eq('status', filtros.status!);
  final rows =
      await query.order('data_infracao', ascending: false).limit(200) as List;
  return rows.map((r) => Multa.fromMap(r as Map<String, dynamic>)).toList();
});

final multaDetalheProvider =
    FutureProvider.autoDispose.family<Multa?, String>((ref, id) async {
  final row = await SupabaseService.client
      .from('multas')
      .select(
          'id, empresa_id, placa, motorista_id, numero_ait, orgao_autuador, local_infracao, data_infracao, data_limite_indicacao, descricao, gravidade, pontos, valor_original, valor_desconto, status, anexo_path, observacoes, indicado_em, indicado_por, criado_em, motoristas(id, nome_completo)')
      .eq('id', id)
      .maybeSingle();
  if (row == null) return null;
  return Multa.fromMap(row);
});

// Sugestão de condutor: reaproveita o vínculo Motorista<->Veículo já
// existente em Parâmetros de Uso (parametros_vinculo_motorista_veiculo),
// resolvendo qual vínculo estava ATIVO na data da infração — mesma
// consulta de multas/[id]/page.tsx.
final sugestaoCondutorProvider = FutureProvider.autoDispose
    .family<String?, ({String placa, String dataInfracao})>((ref, args) async {
  final row = await SupabaseService.client
      .from('parametros_vinculo_motorista_veiculo')
      .select('motorista_id')
      .eq('placa', args.placa)
      .eq('status', 'Ativo')
      .lte('data_inicio', args.dataInfracao)
      .or('data_fim.is.null,data_fim.gte.${args.dataInfracao}')
      .maybeSingle();
  return row?['motorista_id'] as String?;
});

class HistoricoMultaVeiculo {
  final String id;
  final String dataInfracao;
  final String? descricao;
  final String status;
  const HistoricoMultaVeiculo(
      {required this.id,
      required this.dataInfracao,
      this.descricao,
      required this.status});
}

final historicoMultasVeiculoProvider = FutureProvider.autoDispose
    .family<List<HistoricoMultaVeiculo>, ({String placa, String excluirId})>(
        (ref, args) async {
  final rows = await SupabaseService.client
      .from('multas')
      .select('id, data_infracao, descricao, status')
      .eq('placa', args.placa)
      .neq('id', args.excluirId)
      .order('data_infracao', ascending: false)
      .limit(10) as List;
  return rows
      .map((r) => HistoricoMultaVeiculo(
            id: r['id'] as String,
            dataInfracao: r['data_infracao'] as String,
            descricao: r['descricao'] as String?,
            status: r['status'] as String? ?? '',
          ))
      .toList();
});
