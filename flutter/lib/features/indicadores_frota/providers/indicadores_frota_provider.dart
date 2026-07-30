import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase Indicadores-da-Frota (30/07/2026) — porta de indicadores-frota/page.tsx.
// RPC kpis_frota_resumo não é SECURITY DEFINER — roda com o privilégio de
// quem chama, protegida pela RLS de baixo, mesmo espírito de tco_provider.dart.

class KpisFrota {
  final int totalVeiculos, diasPeriodo, diasParadoTotal, diasDisponivelTotal, diasComMovimentoTotal;
  final double? disponibilidadePct, kmTotal, cpkOperacional, litrosTotal, mediaKmL, utilizacaoPct, pctCorretiva;
  final double custoOperacionalTotal, manutencaoPreventivaCusto, manutencaoCorretivaCusto, manutencaoNaoClassificadaCusto;
  // Fase C (30/07/2026) — checklist de inspeção (conformidade/TMRNC) e
  // sinistros (sinistralidade), os 3 KPIs que faltavam do benchmark.
  final int itensInspecionados, itensConformes, totalSinistros;
  final double? conformidadePct, tmrncHoras, indiceSinistralidade;
  const KpisFrota({
    required this.totalVeiculos,
    required this.diasPeriodo,
    required this.diasParadoTotal,
    required this.diasDisponivelTotal,
    required this.diasComMovimentoTotal,
    this.disponibilidadePct,
    this.kmTotal,
    this.cpkOperacional,
    this.litrosTotal,
    this.mediaKmL,
    this.utilizacaoPct,
    this.pctCorretiva,
    required this.custoOperacionalTotal,
    required this.manutencaoPreventivaCusto,
    required this.manutencaoCorretivaCusto,
    required this.manutencaoNaoClassificadaCusto,
    required this.itensInspecionados,
    required this.itensConformes,
    required this.totalSinistros,
    this.conformidadePct,
    this.tmrncHoras,
    this.indiceSinistralidade,
  });
  factory KpisFrota.fromMap(Map<String, dynamic> m) => KpisFrota(
        totalVeiculos: (m['total_veiculos'] as num?)?.toInt() ?? 0,
        diasPeriodo: (m['dias_periodo'] as num?)?.toInt() ?? 0,
        diasParadoTotal: (m['dias_parado_total'] as num?)?.toInt() ?? 0,
        diasDisponivelTotal: (m['dias_disponivel_total'] as num?)?.toInt() ?? 0,
        diasComMovimentoTotal: (m['dias_com_movimento_total'] as num?)?.toInt() ?? 0,
        disponibilidadePct: (m['disponibilidade_pct'] as num?)?.toDouble(),
        kmTotal: (m['km_total'] as num?)?.toDouble(),
        cpkOperacional: (m['cpk_operacional'] as num?)?.toDouble(),
        litrosTotal: (m['litros_total'] as num?)?.toDouble(),
        mediaKmL: (m['media_km_l'] as num?)?.toDouble(),
        utilizacaoPct: (m['utilizacao_pct'] as num?)?.toDouble(),
        pctCorretiva: (m['pct_corretiva'] as num?)?.toDouble(),
        custoOperacionalTotal: (m['custo_operacional_total'] as num?)?.toDouble() ?? 0,
        manutencaoPreventivaCusto: (m['manutencao_preventiva_custo'] as num?)?.toDouble() ?? 0,
        manutencaoCorretivaCusto: (m['manutencao_corretiva_custo'] as num?)?.toDouble() ?? 0,
        manutencaoNaoClassificadaCusto: (m['manutencao_nao_classificada_custo'] as num?)?.toDouble() ?? 0,
        itensInspecionados: (m['itens_inspecionados'] as num?)?.toInt() ?? 0,
        itensConformes: (m['itens_conformes'] as num?)?.toInt() ?? 0,
        totalSinistros: (m['total_sinistros'] as num?)?.toInt() ?? 0,
        conformidadePct: (m['conformidade_pct'] as num?)?.toDouble(),
        tmrncHoras: (m['tmrnc_horas'] as num?)?.toDouble(),
        indiceSinistralidade: (m['indice_sinistralidade'] as num?)?.toDouble(),
      );
}

typedef FiltroKpisFrota = ({String dataInicio, String dataFim});

final kpisFrotaProvider = FutureProvider.autoDispose.family<KpisFrota?, FiltroKpisFrota>((ref, filtro) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return null;
  final rows = await SupabaseService.client.rpc('kpis_frota_resumo', params: {
    'p_empresa_id': empresaId,
    'p_data_inicio': filtro.dataInicio,
    'p_data_fim': filtro.dataFim,
  }) as List;
  if (rows.isEmpty) return null;
  return KpisFrota.fromMap(rows.first as Map<String, dynamic>);
});

// Fase Indicadores-da-Frota D (30/07/2026) — pedido do Daniel: "colocar um
// filtro de seleção do veículo... escolher o veículo específico ou todos,
// ou também poder comparar veículos entre si... indicadores distintos por
// modelo, tipo de veículo". Mesmos 8 KPIs de KpisFrota, mas 1 objeto por
// veículo ativo — porta de indicadoresFrota.ts (web).
class VeiculoKpi {
  final String placa;
  final String? marca, modelo, tipoVeiculo, tipo, classificacao, centroCustoNome;
  final int diasPeriodo, diasParado, diasDisponivel, diasComMovimento, itensInspecionados, itensConformes, totalSinistros;
  final double kmPeriodo, custoOperacionalTotal, litros, manutencaoPreventivaCusto, manutencaoCorretivaCusto, manutencaoNaoClassificadaCusto;
  final double? disponibilidadePct, cpkOperacional, mediaKmL, utilizacaoPct, pctCorretiva, conformidadePct, tmrncHoras;
  const VeiculoKpi({
    required this.placa,
    this.marca,
    this.modelo,
    this.tipoVeiculo,
    this.tipo,
    this.classificacao,
    this.centroCustoNome,
    required this.diasPeriodo,
    required this.diasParado,
    required this.diasDisponivel,
    required this.diasComMovimento,
    required this.itensInspecionados,
    required this.itensConformes,
    required this.totalSinistros,
    required this.kmPeriodo,
    required this.custoOperacionalTotal,
    required this.litros,
    required this.manutencaoPreventivaCusto,
    required this.manutencaoCorretivaCusto,
    required this.manutencaoNaoClassificadaCusto,
    this.disponibilidadePct,
    this.cpkOperacional,
    this.mediaKmL,
    this.utilizacaoPct,
    this.pctCorretiva,
    this.conformidadePct,
    this.tmrncHoras,
  });
  factory VeiculoKpi.fromMap(Map<String, dynamic> m) => VeiculoKpi(
        placa: m['placa'] as String,
        marca: m['marca'] as String?,
        modelo: m['modelo'] as String?,
        tipoVeiculo: m['tipo_veiculo'] as String?,
        tipo: m['tipo'] as String?,
        classificacao: m['classificacao'] as String?,
        centroCustoNome: m['centro_custo_nome'] as String?,
        diasPeriodo: (m['dias_periodo'] as num?)?.toInt() ?? 0,
        diasParado: (m['dias_parado'] as num?)?.toInt() ?? 0,
        diasDisponivel: (m['dias_disponivel'] as num?)?.toInt() ?? 0,
        diasComMovimento: (m['dias_com_movimento'] as num?)?.toInt() ?? 0,
        itensInspecionados: (m['itens_inspecionados'] as num?)?.toInt() ?? 0,
        itensConformes: (m['itens_conformes'] as num?)?.toInt() ?? 0,
        totalSinistros: (m['total_sinistros'] as num?)?.toInt() ?? 0,
        kmPeriodo: (m['km_periodo'] as num?)?.toDouble() ?? 0,
        custoOperacionalTotal: (m['custo_operacional_total'] as num?)?.toDouble() ?? 0,
        litros: (m['litros'] as num?)?.toDouble() ?? 0,
        manutencaoPreventivaCusto: (m['manutencao_preventiva_custo'] as num?)?.toDouble() ?? 0,
        manutencaoCorretivaCusto: (m['manutencao_corretiva_custo'] as num?)?.toDouble() ?? 0,
        manutencaoNaoClassificadaCusto: (m['manutencao_nao_classificada_custo'] as num?)?.toDouble() ?? 0,
        disponibilidadePct: (m['disponibilidade_pct'] as num?)?.toDouble(),
        cpkOperacional: (m['cpk_operacional'] as num?)?.toDouble(),
        mediaKmL: (m['media_km_l'] as num?)?.toDouble(),
        utilizacaoPct: (m['utilizacao_pct'] as num?)?.toDouble(),
        pctCorretiva: (m['pct_corretiva'] as num?)?.toDouble(),
        conformidadePct: (m['conformidade_pct'] as num?)?.toDouble(),
        tmrncHoras: (m['tmrnc_horas'] as num?)?.toDouble(),
      );
}

final kpisPorVeiculoProvider = FutureProvider.autoDispose.family<List<VeiculoKpi>, FiltroKpisFrota>((ref, filtro) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client.rpc('kpis_frota_por_veiculo', params: {
    'p_empresa_id': empresaId,
    'p_data_inicio': filtro.dataInicio,
    'p_data_fim': filtro.dataFim,
  }) as List;
  return rows.map((r) => VeiculoKpi.fromMap(r as Map<String, dynamic>)).toList();
});

// Forma unificada usada pela tela — o agregado da frota inteira (KpisFrota),
// um veículo específico ou um grupo reagregado (agregarVeiculos) todos
// viram isso, mesma ideia de KpisExibicao em indicadoresFrota.ts (web).
class KpisExibicao {
  final int totalVeiculos, itensInspecionados, totalSinistros;
  final double diasPeriodo, manutencaoNaoClassificadaCusto;
  final double? disponibilidadePct, cpkOperacional, mediaKmL, utilizacaoPct, pctCorretiva, conformidadePct, tmrncHoras, indiceSinistralidade;
  const KpisExibicao({
    required this.totalVeiculos,
    required this.itensInspecionados,
    required this.totalSinistros,
    required this.diasPeriodo,
    required this.manutencaoNaoClassificadaCusto,
    this.disponibilidadePct,
    this.cpkOperacional,
    this.mediaKmL,
    this.utilizacaoPct,
    this.pctCorretiva,
    this.conformidadePct,
    this.tmrncHoras,
    this.indiceSinistralidade,
  });

  factory KpisExibicao.deFrota(KpisFrota k) => KpisExibicao(
        totalVeiculos: k.totalVeiculos,
        itensInspecionados: k.itensInspecionados,
        totalSinistros: k.totalSinistros,
        diasPeriodo: k.diasPeriodo.toDouble(),
        manutencaoNaoClassificadaCusto: k.manutencaoNaoClassificadaCusto,
        disponibilidadePct: k.disponibilidadePct,
        cpkOperacional: k.cpkOperacional,
        mediaKmL: k.mediaKmL,
        utilizacaoPct: k.utilizacaoPct,
        pctCorretiva: k.pctCorretiva,
        conformidadePct: k.conformidadePct,
        tmrncHoras: k.tmrncHoras,
        indiceSinistralidade: k.indiceSinistralidade,
      );

  // Sem sinistralidade percentual (não faz sentido pra n=1).
  factory KpisExibicao.deVeiculo(VeiculoKpi v) => KpisExibicao(
        totalVeiculos: 1,
        itensInspecionados: v.itensInspecionados,
        totalSinistros: v.totalSinistros,
        diasPeriodo: v.diasPeriodo.toDouble(),
        manutencaoNaoClassificadaCusto: v.manutencaoNaoClassificadaCusto,
        disponibilidadePct: v.disponibilidadePct,
        cpkOperacional: v.cpkOperacional,
        mediaKmL: v.mediaKmL,
        utilizacaoPct: v.utilizacaoPct,
        pctCorretiva: v.pctCorretiva,
        conformidadePct: v.conformidadePct,
        tmrncHoras: v.tmrncHoras,
        indiceSinistralidade: null,
      );
}

double _arred(double v, int casas) {
  final fator = _pow10(casas);
  return (v * fator).round() / fator;
}

double _pow10(int n) {
  var r = 1.0;
  for (var i = 0; i < n; i++) {
    r *= 10;
  }
  return r;
}

// Reagrega um subconjunto de veículos (ex.: filtrado por modelo/tipo) nos
// mesmos 8 KPIs, com as mesmas fórmulas ponderadas de kpis_frota_resumo
// (soma de numerador/denominador, não média simples de percentuais) — mesma
// lógica de agregarVeiculos em indicadoresFrota.ts (web). TMRNC é exceção:
// média simples dos valores já calculados por veículo (aproximação, ver
// comentário na versão web).
KpisExibicao agregarVeiculos(List<VeiculoKpi> veiculos, int diasPeriodo) {
  final totalVeiculos = veiculos.length;
  double somar(double Function(VeiculoKpi) fn) => veiculos.fold(0, (s, v) => s + fn(v));
  int somarInt(int Function(VeiculoKpi) fn) => veiculos.fold(0, (s, v) => s + fn(v));

  final diasParadoTotal = somarInt((v) => v.diasParado);
  final kmTotal = somar((v) => v.kmPeriodo);
  final custoTotal = somar((v) => v.custoOperacionalTotal);
  final litrosTotal = somar((v) => v.litros);
  final diasDisponivelTotal = somarInt((v) => v.diasDisponivel);
  final diasComMovimentoTotal = somarInt((v) => v.diasComMovimento);
  final custoPreventiva = somar((v) => v.manutencaoPreventivaCusto);
  final custoCorretiva = somar((v) => v.manutencaoCorretivaCusto);
  final custoNaoClassificada = somar((v) => v.manutencaoNaoClassificadaCusto);
  final itensInspecionados = somarInt((v) => v.itensInspecionados);
  final itensConformes = somarInt((v) => v.itensConformes);
  final totalSinistros = somarInt((v) => v.totalSinistros);
  final tmrncValores = veiculos.map((v) => v.tmrncHoras).whereType<double>().toList();

  return KpisExibicao(
    totalVeiculos: totalVeiculos,
    itensInspecionados: itensInspecionados,
    totalSinistros: totalSinistros,
    diasPeriodo: diasPeriodo.toDouble(),
    manutencaoNaoClassificadaCusto: custoNaoClassificada,
    disponibilidadePct: (totalVeiculos > 0 && diasPeriodo > 0)
        ? _arred((1 - diasParadoTotal / (totalVeiculos * diasPeriodo)).clamp(0, 1) * 100, 1)
        : null,
    cpkOperacional: kmTotal > 0 ? _arred(custoTotal / kmTotal, 3) : null,
    mediaKmL: litrosTotal > 0 ? _arred(kmTotal / litrosTotal, 2) : null,
    utilizacaoPct: diasDisponivelTotal > 0 ? _arred((diasComMovimentoTotal / diasDisponivelTotal).clamp(0, 1) * 100, 1) : null,
    pctCorretiva: (custoPreventiva + custoCorretiva) > 0 ? _arred(custoCorretiva / (custoPreventiva + custoCorretiva) * 100, 1) : null,
    conformidadePct: itensInspecionados > 0 ? _arred(itensConformes / itensInspecionados * 100, 1) : null,
    tmrncHoras: tmrncValores.isNotEmpty ? _arred(tmrncValores.reduce((a, b) => a + b) / tmrncValores.length, 1) : null,
    indiceSinistralidade: totalVeiculos > 0 ? _arred(totalSinistros / totalVeiculos * 100, 1) : null,
  );
}
