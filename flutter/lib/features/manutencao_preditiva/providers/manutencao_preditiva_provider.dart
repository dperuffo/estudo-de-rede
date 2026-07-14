import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — Manutenção Preditiva (cliente), porta de
// manutencao-preditiva/page.tsx + [placa]/page.tsx + actions.ts +
// src/lib/manutencaoPreditiva.ts. RLS/RPCs conferidas antes de portar:
// manutencao_preditiva_resumo/manutencao_preditiva_kpis/
// manutencao_preditiva_base NÃO são SECURITY DEFINER — rodam com o
// privilégio de quem chama, então a RLS de baixo (cadastro_veiculos,
// abastecimentos_unificado, manutencoes_realizadas, empresas) protege os
// dados normalmente; todas com self-service completo pra empresa do
// usuário. `manutencoes_realizadas` já tinha self-service ALL (usada
// também em Relatórios Personalizados). Porta 1:1 — sem redução de
// escopo relevante, a tela já é auto-contida (lista + detalhe + form de
// registro + histórico).

const ordemComponentes = ['oleo', 'pneus', 'filtros', 'alinhamento', 'arrefecimento', 'lubrificacao', 'revisao', 'ruidos'];

const labelStatus = {'ok': 'OK', 'alerta': 'Alerta', 'critico': 'Crítico'};

Color corStatusTexto(String status) {
  switch (status) {
    case 'critico':
      return const Color(0xFFB91C1C);
    case 'alerta':
      return const Color(0xFF92400E);
    default:
      return const Color(0xFF047857);
  }
}

Color corStatusFundo(String status) {
  switch (status) {
    case 'critico':
      return const Color(0xFFFEF2F2);
    case 'alerta':
      return const Color(0xFFFFFBEB);
    default:
      return const Color(0xFFECFDF5);
  }
}

Color corBarraScore(double score) {
  if (score >= 70) return const Color(0xFF16A34A);
  if (score >= 40) return const Color(0xFFD97706);
  return const Color(0xFFDC2626);
}

// Porta de ITENS_MANUTENCAO (src/lib/manutencaoPreditiva.ts) — mesmo
// vocabulário usado pelo app Flutter de produção, pra manter o histórico
// compatível entre os apps que escrevem em manutencoes_realizadas.
const itensManutencao = [
  'Troca de óleo e filtro',
  'Revisão de freios',
  'Alinhamento e balanceamento',
  'Troca de pneus',
  'Revisão elétrica',
  'Troca de filtro de ar',
  'Troca de filtro de combustível',
  'Revisão de suspensão',
  'Troca de correia dentada',
  'Revisão do sistema de arrefecimento',
  'Troca de velas',
  'Revisão geral',
  'Troca de pastilhas de freio',
  'Troca de fluido de freio',
  'Revisão de transmissão',
  'Troca de amortecedores',
];

class VeiculoResumoManutencao {
  final String placa;
  final String? marca, modelo, tipoVeiculo, centroCustoId, centroCustoNome;
  final double kmAtual;
  final int idadeAnos;
  final double? consumoAtual, degradacao;
  final int scoreGeral;
  final String status;
  final int nCriticos, nAlertas;
  final int totalCount;
  const VeiculoResumoManutencao({
    required this.placa,
    this.marca,
    this.modelo,
    this.tipoVeiculo,
    this.centroCustoId,
    this.centroCustoNome,
    required this.kmAtual,
    required this.idadeAnos,
    this.consumoAtual,
    this.degradacao,
    required this.scoreGeral,
    required this.status,
    required this.nCriticos,
    required this.nAlertas,
    required this.totalCount,
  });
  factory VeiculoResumoManutencao.fromMap(Map<String, dynamic> m) => VeiculoResumoManutencao(
        placa: m['placa'] as String,
        marca: m['marca'] as String?,
        modelo: m['modelo'] as String?,
        tipoVeiculo: m['tipo_veiculo'] as String?,
        centroCustoId: m['centro_custo_id'] as String?,
        centroCustoNome: m['centro_custo_nome'] as String?,
        kmAtual: (m['km_atual'] as num?)?.toDouble() ?? 0,
        idadeAnos: (m['idade_anos'] as num?)?.toInt() ?? 0,
        consumoAtual: (m['consumo_atual'] as num?)?.toDouble(),
        degradacao: (m['degradacao'] as num?)?.toDouble(),
        scoreGeral: (m['score_geral'] as num?)?.toInt() ?? 0,
        status: m['status'] as String? ?? 'ok',
        nCriticos: (m['n_criticos'] as num?)?.toInt() ?? 0,
        nAlertas: (m['n_alertas'] as num?)?.toInt() ?? 0,
        totalCount: (m['total_count'] as num?)?.toInt() ?? 0,
      );
}

class KpisManutencao {
  final int totalVeiculos, totalCriticos, totalAlertas, totalOk;
  final double scoreMedio;
  const KpisManutencao({
    required this.totalVeiculos,
    required this.totalCriticos,
    required this.totalAlertas,
    required this.totalOk,
    required this.scoreMedio,
  });
  static const vazio = KpisManutencao(totalVeiculos: 0, totalCriticos: 0, totalAlertas: 0, totalOk: 0, scoreMedio: 0);
}

// Filtros da listagem — record (equality estrutural automática, ótimo pra
// chave de family do Riverpod).
typedef FiltrosResumoManutencao = ({String? busca, String? centroCustoId, String? status, String ordenar, int pagina});
typedef FiltrosKpisManutencao = ({String? busca, String? centroCustoId});

const _tamanhoPagina = 50;

final manutencaoResumoProvider =
    FutureProvider.autoDispose.family<List<VeiculoResumoManutencao>, FiltrosResumoManutencao>((ref, filtros) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client.rpc('manutencao_preditiva_resumo', params: {
    'p_empresa_id': empresaId,
    'p_centro_custo_id': filtros.centroCustoId,
    'p_busca': (filtros.busca == null || filtros.busca!.trim().isEmpty) ? null : filtros.busca!.trim(),
    'p_status': filtros.status,
    'p_ordenar': filtros.ordenar,
    'p_limit': _tamanhoPagina,
    'p_offset': (filtros.pagina - 1) * _tamanhoPagina,
  }) as List;
  return rows.map((r) => VeiculoResumoManutencao.fromMap(r as Map<String, dynamic>)).toList();
});

final manutencaoKpisProvider = FutureProvider.autoDispose.family<KpisManutencao, FiltrosKpisManutencao>((ref, filtros) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return KpisManutencao.vazio;
  final rows = await SupabaseService.client.rpc('manutencao_preditiva_kpis', params: {
    'p_empresa_id': empresaId,
    'p_centro_custo_id': filtros.centroCustoId,
    'p_busca': (filtros.busca == null || filtros.busca!.trim().isEmpty) ? null : filtros.busca!.trim(),
  }) as List;
  if (rows.isEmpty) return KpisManutencao.vazio;
  final r = rows.first as Map<String, dynamic>;
  return KpisManutencao(
    totalVeiculos: (r['total_veiculos'] as num?)?.toInt() ?? 0,
    totalCriticos: (r['total_criticos'] as num?)?.toInt() ?? 0,
    totalAlertas: (r['total_alertas'] as num?)?.toInt() ?? 0,
    totalOk: (r['total_ok'] as num?)?.toInt() ?? 0,
    scoreMedio: (r['score_medio'] as num?)?.toDouble() ?? 0,
  );
});

class ComponenteResultado {
  final String componente, componenteLabel, componenteIcone;
  final int score;
  final String urgencia; // ok | alerta | critico
  final double kmSince, kmNext, pct;
  final String fonte; // real | estimado
  const ComponenteResultado({
    required this.componente,
    required this.componenteLabel,
    required this.componenteIcone,
    required this.score,
    required this.urgencia,
    required this.kmSince,
    required this.kmNext,
    required this.pct,
    required this.fonte,
  });
  factory ComponenteResultado.fromMap(Map<String, dynamic> m) => ComponenteResultado(
        componente: m['componente'] as String,
        componenteLabel: m['componente_label'] as String,
        componenteIcone: m['componente_icone'] as String,
        score: (m['score'] as num?)?.toInt() ?? 0,
        urgencia: m['urgencia'] as String? ?? 'ok',
        kmSince: (m['km_since'] as num?)?.toDouble() ?? 0,
        kmNext: (m['km_next'] as num?)?.toDouble() ?? 0,
        pct: (m['pct'] as num?)?.toDouble() ?? 0,
        fonte: m['fonte'] as String? ?? 'estimado',
      );
}

class VeiculoDetalheManutencao {
  final String placa;
  final String? marca, modelo, tipoVeiculo, centroCustoNome;
  final int idadeAnos;
  final double kmAtual;
  final double? consumoAtual, degradacao;
  final int scoreGeral;
  final String status;
  final List<ComponenteResultado> componentes;
  final List<String> recomendacoes;
  const VeiculoDetalheManutencao({
    required this.placa,
    this.marca,
    this.modelo,
    this.tipoVeiculo,
    this.centroCustoNome,
    required this.idadeAnos,
    required this.kmAtual,
    this.consumoAtual,
    this.degradacao,
    required this.scoreGeral,
    required this.status,
    required this.componentes,
    required this.recomendacoes,
  });
}

// Porta fiel de gerarRecomendacoes (src/lib/manutencaoPreditiva.ts).
List<String> gerarRecomendacoes(List<ComponenteResultado> componentes, double degradacao, int idadeAnos) {
  final recs = <String>[];
  final criticos = componentes.where((c) => c.urgencia == 'critico').toList();
  final alertas = componentes.where((c) => c.urgencia == 'alerta').toList();

  if (criticos.isNotEmpty) {
    final nomes = criticos.map((c) => c.componenteLabel).join(', ');
    recs.add('🔴 Ação imediata: $nomes — vencido(s) pelo hodômetro.');
  }
  if (degradacao > 0.15) {
    recs.add('🛢️ Consumo degradado ${(degradacao * 100).round()}%. Verificar filtros e injeção.');
  } else if (degradacao > 0.07) {
    recs.add('⚠️ Leve queda de rendimento (${(degradacao * 100).round()}%). Monitorar tendência.');
  }
  if (idadeAnos >= 10) {
    recs.add('📅 Veículo com $idadeAnos anos. Reduzir intervalos de manutenção em 20-30%.');
  }
  if (alertas.isNotEmpty && criticos.isEmpty) {
    final proximos = alertas.take(2).map((c) => '${c.componenteIcone} ${c.componenteLabel} (~${c.kmNext.round()} km)').join(', ');
    recs.add('🟡 Próximos: $proximos');
  }
  if (criticos.isEmpty && alertas.isEmpty) {
    recs.add('✅ Veículo em bom estado. Manter cronograma preventivo.');
  }
  return recs;
}

final manutencaoDetalheProvider = FutureProvider.autoDispose.family<VeiculoDetalheManutencao?, String>((ref, placa) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return null;
  final rows = await SupabaseService.client.rpc('manutencao_preditiva_base', params: {
    'p_empresa_id': empresaId,
    'p_placa': placa,
  }) as List;
  if (rows.isEmpty) return null;

  final mapas = rows.cast<Map<String, dynamic>>();
  final primeiro = mapas.first;
  final componentes = mapas.map((m) => ComponenteResultado.fromMap(m)).toList()
    ..sort((a, b) => ordemComponentes.indexOf(a.componente).compareTo(ordemComponentes.indexOf(b.componente)));

  final somaPeso = mapas.fold<double>(0, (s, m) => s + ((m['peso'] as num?)?.toDouble() ?? 0));
  final somaScorePeso = mapas.fold<double>(0, (s, m) => s + ((m['score'] as num? ?? 0).toDouble() * ((m['peso'] as num?)?.toDouble() ?? 0)));
  final scoreGeral = somaPeso > 0 ? (somaScorePeso / somaPeso).round() : 0;
  final status = scoreGeral >= 70 ? 'ok' : (scoreGeral >= 40 ? 'alerta' : 'critico');
  final degradacao = (primeiro['degradacao'] as num?)?.toDouble() ?? 0;
  final idadeAnos = (primeiro['idade_anos'] as num?)?.toInt() ?? 0;

  return VeiculoDetalheManutencao(
    placa: placa,
    marca: primeiro['marca'] as String?,
    modelo: primeiro['modelo'] as String?,
    tipoVeiculo: primeiro['tipo_veiculo'] as String?,
    centroCustoNome: primeiro['centro_custo_nome'] as String?,
    idadeAnos: idadeAnos,
    kmAtual: (primeiro['km_atual'] as num?)?.toDouble() ?? 0,
    consumoAtual: (primeiro['consumo_atual'] as num?)?.toDouble(),
    degradacao: degradacao,
    scoreGeral: scoreGeral,
    status: status,
    componentes: componentes,
    recomendacoes: gerarRecomendacoes(componentes, degradacao, idadeAnos),
  );
});

class RegistroManutencao {
  final int id;
  final String? dataManutencao, oficina, criadoPor;
  final double? hodometro, custoTotal;
  final List<String> itensRealizados;
  const RegistroManutencao({
    required this.id,
    this.dataManutencao,
    this.oficina,
    this.criadoPor,
    this.hodometro,
    this.custoTotal,
    required this.itensRealizados,
  });
  factory RegistroManutencao.fromMap(Map<String, dynamic> m) => RegistroManutencao(
        id: (m['id'] as num).toInt(),
        dataManutencao: m['data_manutencao'] as String?,
        oficina: m['oficina'] as String?,
        criadoPor: m['criado_por'] as String?,
        hodometro: (m['hodometro'] as num?)?.toDouble(),
        custoTotal: (m['custo_total'] as num?)?.toDouble(),
        itensRealizados: ((m['itens_realizados'] as List?) ?? []).cast<String>(),
      );
}

final historicoManutencaoProvider = FutureProvider.autoDispose.family<List<RegistroManutencao>, String>((ref, placa) async {
  final rows = await SupabaseService.client
      .from('manutencoes_realizadas')
      .select('id, data_manutencao, hodometro, itens_realizados, oficina, custo_total, criado_por')
      .eq('placa', placa)
      .order('data_manutencao', ascending: false)
      .limit(100) as List;
  return rows.map((r) => RegistroManutencao.fromMap(r as Map<String, dynamic>)).toList();
});
