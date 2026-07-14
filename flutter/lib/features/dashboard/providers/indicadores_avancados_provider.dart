import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-6 — os 8 "Indicadores avançados" de
// src/app/(dashboard)/dashboard/page.tsx, escopados por mês/ano (seletor
// próprio desta aba — ver comentário de decisão de escopo em
// dashboard_provider.dart sobre por que Centro de Custo NÃO compartilha
// este seletor). Cada indicador vem de uma RPC própria (todas SECURITY
// INVOKER, filtram por p_empresa_id + p_data_inicio/p_data_fim — RLS de
// abastecimentos_unificado/cadastro_veiculos etc. de quem está logado
// aplica-se normalmente, mesmo mecanismo já usado em toda a Inteligência
// de Rede e no restante do Dashboard).

const _nomesMes = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

String rotuloMesAno(int ano, int mes) => '${_nomesMes[mes - 1]} $ano';

// Últimos 12 meses (o atual primeiro) — opções do seletor.
List<({int ano, int mes})> opcoesMes() {
  final agora = DateTime.now();
  return List.generate(12, (i) {
    final d = DateTime(agora.year, agora.month - i, 1);
    return (ano: d.year, mes: d.month);
  });
}

class ItemVariacaoPreco {
  final String itemNome;
  final int qtdAbastecimentos;
  final double precoMin;
  final double precoMed;
  final double precoMax;
  final double desvioPadrao;
  final double coefVariacao;
  final String? ufReferencia;
  final String? anpNivel; // 'estado' | 'brasil' | null
  final double? anpPrecoMin;
  final double? anpPrecoMed;
  final double? anpPrecoMax;
  final double? anpDesvioPadrao;
  final String? anpDataReferencia;
  const ItemVariacaoPreco({
    required this.itemNome,
    required this.qtdAbastecimentos,
    required this.precoMin,
    required this.precoMed,
    required this.precoMax,
    required this.desvioPadrao,
    required this.coefVariacao,
    required this.ufReferencia,
    required this.anpNivel,
    required this.anpPrecoMin,
    required this.anpPrecoMed,
    required this.anpPrecoMax,
    required this.anpDesvioPadrao,
    required this.anpDataReferencia,
  });
}

class PontoPrevisaoConsumo {
  final String diaLabel;
  final double litros;
  final String tipo; // 'real' | 'projetado'
  const PontoPrevisaoConsumo({required this.diaLabel, required this.litros, required this.tipo});
}

class PontoPrecoMedio {
  final String diaLabel;
  final double precoMedio;
  const PontoPrecoMedio({required this.diaLabel, required this.precoMedio});
}

class PontoEvolutivoPostos {
  final String diaLabel;
  final Map<String, double> valores;
  const PontoEvolutivoPostos({required this.diaLabel, required this.valores});
}

class PontoTopPosto {
  final String posto;
  final double litros;
  const PontoTopPosto({required this.posto, required this.litros});
}

class ItemRankingGasto {
  final String chave;
  final String label;
  final String? sub;
  final double gasto;
  final double litros;
  final int qtd;
  const ItemRankingGasto({
    required this.chave,
    required this.label,
    required this.sub,
    required this.gasto,
    required this.litros,
    required this.qtd,
  });
}

class ItemEficienciaVeiculo {
  final String placa;
  final String? marca;
  final String? modelo;
  final int abastecimentos;
  final double kmTotal;
  final double kmMedio;
  final double? mediaKmL;
  final double litrosTotal;
  final double precoMedio;
  final double custoTotal;
  const ItemEficienciaVeiculo({
    required this.placa,
    required this.marca,
    required this.modelo,
    required this.abastecimentos,
    required this.kmTotal,
    required this.kmMedio,
    required this.mediaKmL,
    required this.litrosTotal,
    required this.precoMedio,
    required this.custoTotal,
  });
}

class IndicadoresAvancadosDados {
  final bool temEmpresa;
  final int ano;
  final int mes;
  final bool isMesAtual;
  final int diaAtual;
  final int diasNoMes;
  final List<ItemVariacaoPreco> variacaoPrecos;
  final List<PontoPrevisaoConsumo> previsaoConsumo;
  final double totalLitrosMes;
  final double totalLitrosProjetado;
  final List<PontoPrecoMedio> precoMedio;
  final List<PontoEvolutivoPostos> evolutivoPostos;
  final List<String> postosNomes;
  final List<PontoTopPosto> topPostos;
  final List<ItemRankingGasto> rankingVeiculos;
  final List<ItemRankingGasto> rankingMotoristas;
  final List<ItemEficienciaVeiculo> eficienciaVeiculos;

  const IndicadoresAvancadosDados({
    required this.temEmpresa,
    required this.ano,
    required this.mes,
    required this.isMesAtual,
    required this.diaAtual,
    required this.diasNoMes,
    required this.variacaoPrecos,
    required this.previsaoConsumo,
    required this.totalLitrosMes,
    required this.totalLitrosProjetado,
    required this.precoMedio,
    required this.evolutivoPostos,
    required this.postosNomes,
    required this.topPostos,
    required this.rankingVeiculos,
    required this.rankingMotoristas,
    required this.eficienciaVeiculos,
  });

  factory IndicadoresAvancadosDados.vazio(int ano, int mes) => IndicadoresAvancadosDados(
        temEmpresa: false,
        ano: ano,
        mes: mes,
        isMesAtual: false,
        diaAtual: 0,
        diasNoMes: 30,
        variacaoPrecos: const [],
        previsaoConsumo: const [],
        totalLitrosMes: 0,
        totalLitrosProjetado: 0,
        precoMedio: const [],
        evolutivoPostos: const [],
        postosNomes: const [],
        topPostos: const [],
        rankingVeiculos: const [],
        rankingMotoristas: const [],
        eficienciaVeiculos: const [],
      );
}

// Porta calcularPrevisaoConsumo() de src/lib/previsaoConsumo.ts — projeta o
// consumo dos dias restantes do mês calibrando pela sazonalidade de dia da
// semana, com shrinkage (K=5) entre a taxa real-até-agora e a média
// histórica geral (ver comentário original na web sobre o "achado real":
// sem o shrinkage, 1-2 dias fora do padrão logo no início do mês distorcem
// a projeção inteira).
List<PontoPrevisaoConsumo> _calcularPrevisaoConsumo({
  required Map<int, double> diasReais,
  required Map<int, double> padraoDiaSemana,
  required int ano,
  required int mes,
  required int diasNoMes,
  required int diaAtual,
  required bool projetarRestante,
}) {
  int diaDaSemana(int dia) => DateTime(ano, mes, dia).weekday % 7; // 0=domingo..6=sábado, igual ao JS getDay()

  final somaPadrao = padraoDiaSemana.values.fold<double>(0, (s, v) => s + v);
  final mediaGeralBruta = somaPadrao / 7;
  final mediaGeral = mediaGeralBruta == 0 ? 1.0 : mediaGeralBruta;

  double fator(int dow) {
    final f = (padraoDiaSemana[dow] ?? mediaGeral) / mediaGeral;
    return (f == 0 || f.isNaN) ? 1.0 : f;
  }

  const kSuavizacaoDias = 5;
  var baseline = mediaGeral;
  if (projetarRestante && diaAtual < diasNoMes) {
    var somaReal = 0.0;
    var somaFatores = 0.0;
    for (var dia = 1; dia <= diaAtual; dia++) {
      somaReal += diasReais[dia] ?? 0;
      somaFatores += fator(diaDaSemana(dia));
    }
    if (somaFatores > 0 && diaAtual > 0) {
      final baselineReal = somaReal / somaFatores;
      final pesoReal = diaAtual / (diaAtual + kSuavizacaoDias);
      baseline = pesoReal * baselineReal + (1 - pesoReal) * mediaGeral;
    }
  }

  final pontos = <PontoPrevisaoConsumo>[];
  for (var dia = 1; dia <= diasNoMes; dia++) {
    final diaLabel = dia.toString().padLeft(2, '0');
    if (dia <= diaAtual) {
      pontos.add(PontoPrevisaoConsumo(
        diaLabel: diaLabel,
        litros: ((diasReais[dia] ?? 0) * 10).round() / 10,
        tipo: 'real',
      ));
    } else if (projetarRestante) {
      final projetado = baseline * fator(diaDaSemana(dia));
      pontos.add(PontoPrevisaoConsumo(diaLabel: diaLabel, litros: (projetado * 10).round() / 10, tipo: 'projetado'));
    }
  }
  return pontos;
}

String _diaLabelCurto(String isoData) {
  final d = DateTime.parse(isoData);
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

final indicadoresAvancadosProvider =
    FutureProvider.autoDispose.family<IndicadoresAvancadosDados, ({int ano, int mes})>((ref, periodo) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return IndicadoresAvancadosDados.vazio(periodo.ano, periodo.mes);

  final supabase = SupabaseService.client;
  final agora = DateTime.now();
  final anoAtual = agora.year;
  final mesAtualNum = agora.month;
  final ano = periodo.ano;
  final mes = periodo.mes;

  final diasNoMes = DateTime(ano, mes + 1, 0).day;
  final isMesAtual = ano == anoAtual && mes == mesAtualNum;
  final isMesFuturo = ano > anoAtual || (ano == anoAtual && mes > mesAtualNum);
  final diaAtual = isMesAtual ? agora.day : (isMesFuturo ? 0 : diasNoMes);
  final dataInicio = _iso(DateTime(ano, mes, 1));
  final diaBase = diaAtual == 0 ? diasNoMes : diaAtual;
  final dataFim = _iso(DateTime(ano, mes, diaBase < 1 ? 1 : diaBase));

  // Fase FLT-6 (hotfix) — igual à web (que dispara as 7 RPCs num único
  // Promise.all), aqui também em paralelo via Future.wait em vez de 7
  // awaits sequenciais. Achado real (reportado pelo Daniel: "canceling
  // statement due to statement timeout" na aba Indicadores Avançados):
  // sequencial soma a latência das 7 chamadas (cada RPC é uma ida e volta
  // HTTP própria via PostgREST) — se qualquer uma demorar um pouco mais
  // (ex.: pool de conexão frio, RLS mais pesada), o total facilmente
  // estoura os 8s de `statement_timeout` da role `authenticated`. Em
  // paralelo, o tempo total passa a ser o da mais lenta, não a soma.
  final resultados = await Future.wait([
    supabase.rpc('indicador_variacao_precos', params: {
      'p_empresa_id': empresaId,
      'p_data_inicio': dataInicio,
      'p_data_fim': dataFim,
    }),
    supabase.rpc('indicador_consumo_diario', params: {
      'p_empresa_id': empresaId,
      'p_data_inicio': dataInicio,
      'p_data_fim': dataFim,
    }),
    supabase.rpc('indicador_padrao_dia_semana', params: {
      'p_empresa_id': empresaId,
      'p_dias_lookback': 90,
    }),
    supabase.rpc('indicador_volume_postos', params: {
      'p_empresa_id': empresaId,
      'p_data_inicio': dataInicio,
      'p_data_fim': dataFim,
    }),
    supabase.rpc('indicador_ranking_veiculos', params: {
      'p_empresa_id': empresaId,
      'p_data_inicio': dataInicio,
      'p_data_fim': dataFim,
      'p_limit': 10,
      'p_offset': 0,
    }),
    supabase.rpc('indicador_ranking_motoristas', params: {
      'p_empresa_id': empresaId,
      'p_data_inicio': dataInicio,
      'p_data_fim': dataFim,
      'p_limit': 10,
      'p_offset': 0,
    }),
    supabase.rpc('indicador_eficiencia_veiculos', params: {
      'p_empresa_id': empresaId,
      'p_data_inicio': dataInicio,
      'p_data_fim': dataFim,
    }),
  ]);

  final variacaoPrecosRaw = resultados[0] as List;
  final consumoDiarioRaw = resultados[1] as List;
  final padraoDiaSemanaRaw = resultados[2] as List;
  final volumePostosRaw = resultados[3] as List;
  final rankingVeiculosRaw = resultados[4] as List;
  final rankingMotoristasRaw = resultados[5] as List;
  final eficienciaVeiculosRaw = resultados[6] as List;

  // Item 1 — Variação de preços.
  final variacaoPrecos = variacaoPrecosRaw.map((r) {
    final m = r as Map<String, dynamic>;
    return ItemVariacaoPreco(
      itemNome: m['item_nome'] as String? ?? '—',
      qtdAbastecimentos: (m['qtd_abastecimentos'] as num?)?.toInt() ?? 0,
      precoMin: (m['preco_min'] as num?)?.toDouble() ?? 0,
      precoMed: (m['preco_med'] as num?)?.toDouble() ?? 0,
      precoMax: (m['preco_max'] as num?)?.toDouble() ?? 0,
      desvioPadrao: (m['desvio_padrao'] as num?)?.toDouble() ?? 0,
      coefVariacao: (m['coef_variacao'] as num?)?.toDouble() ?? 0,
      ufReferencia: m['uf_referencia'] as String?,
      anpNivel: m['anp_nivel'] as String?,
      anpPrecoMin: (m['anp_preco_min'] as num?)?.toDouble(),
      anpPrecoMed: (m['anp_preco_med'] as num?)?.toDouble(),
      anpPrecoMax: (m['anp_preco_max'] as num?)?.toDouble(),
      anpDesvioPadrao: (m['anp_desvio_padrao'] as num?)?.toDouble(),
      anpDataReferencia: m['anp_data_referencia'] as String?,
    );
  }).toList();

  // Item 2 — Previsão de consumo.
  final diasReaisMap = <int, double>{};
  for (final d in consumoDiarioRaw) {
    final m = d as Map<String, dynamic>;
    final dia = DateTime.parse(m['dia'] as String).day;
    diasReaisMap[dia] = (m['litros'] as num?)?.toDouble() ?? 0;
  }
  final padraoDiaSemana = <int, double>{};
  for (final p in padraoDiaSemanaRaw) {
    final m = p as Map<String, dynamic>;
    padraoDiaSemana[(m['dia_semana'] as num).toInt()] = (m['media_litros'] as num?)?.toDouble() ?? 0;
  }
  final previsaoConsumo = _calcularPrevisaoConsumo(
    diasReais: diasReaisMap,
    padraoDiaSemana: padraoDiaSemana,
    ano: ano,
    mes: mes,
    diasNoMes: diasNoMes,
    diaAtual: isMesFuturo ? 0 : diaAtual,
    projetarRestante: isMesAtual,
  );
  final totalLitrosMes = diasReaisMap.values.fold<double>(0, (s, v) => s + v);
  final totalLitrosProjetado =
      previsaoConsumo.where((p) => p.tipo == 'projetado').fold<double>(0, (s, p) => s + p.litros);

  // Item 3 — Evolução do preço médio.
  final precoMedio = consumoDiarioRaw
      .map((d) => d as Map<String, dynamic>)
      .where((m) => ((m['litros'] as num?)?.toDouble() ?? 0) > 0)
      .map((m) => PontoPrecoMedio(
            diaLabel: _diaLabelCurto(m['dia'] as String),
            precoMedio: ((m['valor'] as num).toDouble()) / ((m['litros'] as num).toDouble()),
          ))
      .toList();

  // Itens 4/5 — Evolutivo e Top 5 postos por volume.
  final postosNomesSet = <String>{};
  final postosNomesOrdenados = <String>[];
  for (final v in volumePostosRaw) {
    final m = v as Map<String, dynamic>;
    final nome = (m['posto_nome'] as String?) ?? (m['posto_cnpj'] as String? ?? '—');
    if (postosNomesSet.add(nome)) postosNomesOrdenados.add(nome);
  }
  final porDiaPostos = <String, Map<String, double>>{};
  final diasOrdenados = <String>[];
  final totalPorPosto = <String, double>{};
  for (final v in volumePostosRaw) {
    final m = v as Map<String, dynamic>;
    final nome = (m['posto_nome'] as String?) ?? (m['posto_cnpj'] as String? ?? '—');
    final diaLabel = _diaLabelCurto(m['dia'] as String);
    final litros = (m['litros'] as num?)?.toDouble() ?? 0;
    if (!porDiaPostos.containsKey(diaLabel)) {
      porDiaPostos[diaLabel] = {};
      diasOrdenados.add(diaLabel);
    }
    porDiaPostos[diaLabel]![nome] = litros;
    totalPorPosto[nome] = (totalPorPosto[nome] ?? 0) + litros;
  }
  final evolutivoPostos =
      diasOrdenados.map((d) => PontoEvolutivoPostos(diaLabel: d, valores: porDiaPostos[d]!)).toList();
  final topPostos = totalPorPosto.entries.map((e) => PontoTopPosto(posto: e.key, litros: (e.value * 10).round() / 10)).toList()
    ..sort((a, b) => b.litros.compareTo(a.litros));

  // Itens 6/7 — Ranking de veículos e motoristas por gasto.
  final rankingVeiculos = rankingVeiculosRaw.map((r) {
    final m = r as Map<String, dynamic>;
    final marca = m['marca'] as String?;
    final modelo = m['modelo'] as String?;
    final sub = [marca, modelo].where((s) => s != null && s.isNotEmpty).join(' ');
    return ItemRankingGasto(
      chave: m['placa'] as String,
      label: m['placa'] as String,
      sub: sub.isEmpty ? null : sub,
      gasto: (m['gasto_total'] as num?)?.toDouble() ?? 0,
      litros: (m['litros_total'] as num?)?.toDouble() ?? 0,
      qtd: (m['qtd_abastecimentos'] as num?)?.toInt() ?? 0,
    );
  }).toList();
  final rankingMotoristas = rankingMotoristasRaw.map((r) {
    final m = r as Map<String, dynamic>;
    return ItemRankingGasto(
      chave: m['motorista_nome'] as String? ?? '—',
      label: m['motorista_nome'] as String? ?? '—',
      sub: null,
      gasto: (m['gasto_total'] as num?)?.toDouble() ?? 0,
      litros: (m['litros_total'] as num?)?.toDouble() ?? 0,
      qtd: (m['qtd_abastecimentos'] as num?)?.toInt() ?? 0,
    );
  }).toList();

  // Item 8 — Eficiência real por veículo.
  final eficienciaVeiculos = eficienciaVeiculosRaw.map((r) {
    final m = r as Map<String, dynamic>;
    return ItemEficienciaVeiculo(
      placa: m['placa'] as String,
      marca: m['marca'] as String?,
      modelo: m['modelo'] as String?,
      abastecimentos: (m['abastecimentos'] as num?)?.toInt() ?? 0,
      kmTotal: (m['km_total'] as num?)?.toDouble() ?? 0,
      kmMedio: (m['km_medio'] as num?)?.toDouble() ?? 0,
      mediaKmL: (m['media_km_l'] as num?)?.toDouble(),
      litrosTotal: (m['litros_total'] as num?)?.toDouble() ?? 0,
      precoMedio: (m['preco_medio'] as num?)?.toDouble() ?? 0,
      custoTotal: (m['custo_total'] as num?)?.toDouble() ?? 0,
    );
  }).toList();

  return IndicadoresAvancadosDados(
    temEmpresa: true,
    ano: ano,
    mes: mes,
    isMesAtual: isMesAtual,
    diaAtual: diaAtual,
    diasNoMes: diasNoMes,
    variacaoPrecos: variacaoPrecos,
    previsaoConsumo: previsaoConsumo,
    totalLitrosMes: totalLitrosMes,
    totalLitrosProjetado: totalLitrosProjetado,
    precoMedio: precoMedio,
    evolutivoPostos: evolutivoPostos,
    postosNomes: postosNomesOrdenados,
    topPostos: topPostos,
    rankingVeiculos: rankingVeiculos,
    rankingMotoristas: rankingMotoristas,
    eficienciaVeiculos: eficienciaVeiculos,
  );
});
