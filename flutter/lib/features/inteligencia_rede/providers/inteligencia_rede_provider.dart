import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';
import 'constantes_anp.dart';

// Fase FLT-5 — pedido do Daniel: "verificar se é possível trazer todas as
// abas de inteligência de rede pro PWA nas visões do admin e cliente".
// Reescrita completa deste provider (a v1 da Fase FLT-3, bem mais enxuta,
// fica só no histórico do git) pra portar as 10 abas de
// src/app/(dashboard)/inteligencia-rede/page.tsx (941 linhas) + seus 20
// componentes de gráfico/mapa.
//
// Decisão confirmada com o Daniel (AskUserQuestion): TODAS as 10 abas de
// uma vez (não faseado), e o admin usa o MESMO seletor de empresa que já
// existe (sessao.empresaId) em vez da visão "toda a plataforma" que a web
// usa pra admin (p_empresa_id=null). Ou seja: aqui, cliente E admin sempre
// mandam sessao.empresaId nas RPCs que aceitam o parâmetro — nunca null.
//
// Achado real (documentado também no README): existem 3 RPCs
// SECURITY DEFINER que NÃO têm parâmetro p_empresa_id nenhum
// (historico_precos_evolucao_mensal, preco_medio_por_combustivel_uf,
// postos_gf_precos_mapa) e mais um punhado de RPCs SECURITY INVOKER sem
// parâmetro (postos_gf_por_uf, anp_postos_por_uf, postos_gf_municipios_unicos,
// postos_gf_top_municipios, postos_gf_municipios_por_uf,
// postos_gf_distribuidoras_por_uf, abastecimentos_preco_periodo,
// abastecimentos_postos_visitados) — pra ADMIN, essas sempre retornam dado
// de TODAS as empresas, sem jeito de filtrar por empresa selecionada (não
// existe parâmetro pra isso no banco). Pra cliente comum isso não é
// problema (a RLS/checagem interna já restringe pela própria empresa via
// JWT). Pra admin, é uma limitação de banco que não dá pra resolver só no
// Flutter — mantido como está porque é exatamente o mesmo comportamento
// que a versão web sempre teve pra admin (lá o admin SEMPRE viu a rede
// inteira, nunca por empresa).
//
// Cada aba web virou um arquivo próprio em screens/abas/*.dart, todos
// consumindo o mesmo InteligenciaRedeCompleta carregado aqui uma vez só
// (equivalente ao Promise.all da web, mas sequencial — mesmo padrão já
// usado no resto do app, ver v1 desta mesma tela).

// ---------------------------------------------------------------------
// Modelos
// ---------------------------------------------------------------------

class KpisGerais {
  final int totalGf;
  final int estadosComPosto;
  final int municipiosUnicos;
  final int coberturaBr;
  final double dieselGf;
  final double? deltaDieselPct;
  final double savingPotencialAno;
  const KpisGerais({
    required this.totalGf,
    required this.estadosComPosto,
    required this.municipiosUnicos,
    required this.coberturaBr,
    required this.dieselGf,
    required this.deltaDieselPct,
    required this.savingPotencialAno,
  });
}

class PrecoCombustivelRef {
  final String combustivel;
  final double precoMedio;
  final int qtdPostos;
  final double? referencia;
  final bool ehOficial;
  final double? deltaPct;
  const PrecoCombustivelRef({
    required this.combustivel,
    required this.precoMedio,
    required this.qtdPostos,
    required this.referencia,
    required this.ehOficial,
    required this.deltaPct,
  });
}

class SemanaAnp {
  final DateTime dataInicial;
  final DateTime dataFinal;
  const SemanaAnp({required this.dataInicial, required this.dataFinal});
}

class EvolucaoMensalPonto {
  final String mes;
  final String combustivel;
  final double precoMedio;
  const EvolucaoMensalPonto({required this.mes, required this.combustivel, required this.precoMedio});
  factory EvolucaoMensalPonto.fromMap(Map<String, dynamic> m) => EvolucaoMensalPonto(
        mes: m['mes'] as String? ?? '',
        combustivel: m['combustivel'] as String? ?? '—',
        precoMedio: (m['preco_medio'] as num?)?.toDouble() ?? 0,
      );
}

// Usada tanto pra `alertas` (postos_gf_alertas_preco) quanto pra
// `desvioAnp` (postos_gf_desvio_anp) — as duas RPCs retornam exatamente as
// mesmas colunas.
class AlertaPreco {
  final String cnpj;
  final String razaoSocial;
  final String? municipio;
  final String? uf;
  final String combustivel;
  final String? categoriaAnp;
  final double precoGf;
  final double? precoAnp;
  final String? nivelAnp;
  final double diffPct;
  final double diffRs;
  const AlertaPreco({
    required this.cnpj,
    required this.razaoSocial,
    required this.municipio,
    required this.uf,
    required this.combustivel,
    required this.categoriaAnp,
    required this.precoGf,
    required this.precoAnp,
    required this.nivelAnp,
    required this.diffPct,
    required this.diffRs,
  });
  factory AlertaPreco.fromMap(Map<String, dynamic> m) => AlertaPreco(
        cnpj: m['cnpj'] as String? ?? '',
        razaoSocial: m['razao_social'] as String? ?? '—',
        municipio: m['municipio'] as String?,
        uf: m['uf'] as String?,
        combustivel: m['combustivel'] as String? ?? '—',
        categoriaAnp: m['categoria_anp'] as String?,
        precoGf: (m['preco_gf'] as num?)?.toDouble() ?? 0,
        precoAnp: (m['preco_anp'] as num?)?.toDouble(),
        nivelAnp: m['nivel_anp'] as String?,
        diffPct: (m['diff_pct'] as num?)?.toDouble() ?? 0,
        diffRs: (m['diff_rs'] as num?)?.toDouble() ?? 0,
      );
}

class ResumoAlertaEstado {
  final String uf;
  final int postosAlerta;
  final double piorDesvio;
  const ResumoAlertaEstado({required this.uf, required this.postosAlerta, required this.piorDesvio});
}

class CoberturaMacro {
  final String regiao;
  final int postosGf;
  final int municipiosComGf;
  final int totalMunicipios;
  final double coberturaPct;
  final int estadosComGf;
  final int totalUfs;
  const CoberturaMacro({
    required this.regiao,
    required this.postosGf,
    required this.municipiosComGf,
    required this.totalMunicipios,
    required this.coberturaPct,
    required this.estadosComGf,
    required this.totalUfs,
  });
}

class OportunidadeExpansao {
  final String uf;
  final int postosGf;
  final double penetracaoPct;
  final double? dieselAnp;
  final double score;
  const OportunidadeExpansao({
    required this.uf,
    required this.postosGf,
    required this.penetracaoPct,
    required this.dieselAnp,
    required this.score,
  });
}

class CoberturaUf {
  final String uf;
  final int postosGf;
  final int totalAnp;
  final double penetracao;
  const CoberturaUf({required this.uf, required this.postosGf, required this.totalAnp, required this.penetracao});
}

class PontoMapaSimples {
  final String cnpj;
  final String? razaoSocial;
  final String? municipio;
  final String? uf;
  final double lat;
  final double lon;
  const PontoMapaSimples({
    required this.cnpj,
    required this.razaoSocial,
    required this.municipio,
    required this.uf,
    required this.lat,
    required this.lon,
  });
  factory PontoMapaSimples.fromMap(Map<String, dynamic> m) => PontoMapaSimples(
        cnpj: m['cnpj'] as String? ?? '',
        razaoSocial: m['razao_social'] as String?,
        municipio: m['municipio'] as String?,
        uf: m['uf'] as String?,
        lat: (m['lat'] as num?)?.toDouble() ?? 0,
        lon: (m['lon'] as num?)?.toDouble() ?? 0,
      );
}

class MunicipioRede {
  final String municipio;
  final String uf;
  final int total;
  const MunicipioRede({required this.municipio, required this.uf, required this.total});
  factory MunicipioRede.fromMap(Map<String, dynamic> m) => MunicipioRede(
        municipio: m['municipio'] as String? ?? '—',
        uf: m['uf'] as String? ?? '',
        total: (m['total'] as num?)?.toInt() ?? 0,
      );
}

class DistribuidoraUf {
  final String uf;
  final String distribuidora;
  final int total;
  const DistribuidoraUf({required this.uf, required this.distribuidora, required this.total});
  factory DistribuidoraUf.fromMap(Map<String, dynamic> m) => DistribuidoraUf(
        uf: m['uf'] as String? ?? '',
        distribuidora: m['distribuidora'] as String? ?? '—',
        total: (m['total'] as num?)?.toInt() ?? 0,
      );
}

class PrecoUf {
  final String uf;
  final String combustivel;
  final double precoMedio;
  final int qtdPostos;
  const PrecoUf({required this.uf, required this.combustivel, required this.precoMedio, required this.qtdPostos});
  factory PrecoUf.fromMap(Map<String, dynamic> m) => PrecoUf(
        uf: m['uf'] as String? ?? '',
        combustivel: m['combustivel'] as String? ?? '—',
        precoMedio: (m['preco_medio'] as num?)?.toDouble() ?? 0,
        qtdPostos: (m['qtd_postos'] as num?)?.toInt() ?? 0,
      );
}

class RegistroPrecoHistorico {
  final String cnpj;
  final String? razaoSocial;
  final String? municipio;
  final String? uf;
  final String combustivel;
  final String semana;
  final String mes;
  final double preco;
  const RegistroPrecoHistorico({
    required this.cnpj,
    required this.razaoSocial,
    required this.municipio,
    required this.uf,
    required this.combustivel,
    required this.semana,
    required this.mes,
    required this.preco,
  });
  factory RegistroPrecoHistorico.fromMap(Map<String, dynamic> m) => RegistroPrecoHistorico(
        cnpj: m['cnpj'] as String? ?? '',
        razaoSocial: m['razao_social'] as String?,
        municipio: m['municipio'] as String?,
        uf: m['uf'] as String?,
        combustivel: m['combustivel'] as String? ?? '—',
        semana: m['semana'] as String? ?? '',
        mes: m['mes'] as String? ?? '',
        preco: (m['preco'] as num?)?.toDouble() ?? 0,
      );
}

class PrecoRealPeriodo {
  final String uf;
  final String semana;
  final String mes;
  final double precoMedio;
  final int qtd;
  const PrecoRealPeriodo({
    required this.uf,
    required this.semana,
    required this.mes,
    required this.precoMedio,
    required this.qtd,
  });
  factory PrecoRealPeriodo.fromMap(Map<String, dynamic> m) => PrecoRealPeriodo(
        uf: m['uf'] as String? ?? '',
        semana: m['semana'] as String? ?? '',
        mes: m['mes'] as String? ?? '',
        precoMedio: (m['preco_medio'] as num?)?.toDouble() ?? 0,
        qtd: (m['qtd'] as num?)?.toInt() ?? 0,
      );
}

class PontoPrecoMapaOperacional {
  final String cnpj;
  final String? razaoSocial;
  final String? municipio;
  final String? uf;
  final String combustivel;
  final double preco;
  final double? lat;
  final double? lon;
  const PontoPrecoMapaOperacional({
    required this.cnpj,
    required this.razaoSocial,
    required this.municipio,
    required this.uf,
    required this.combustivel,
    required this.preco,
    required this.lat,
    required this.lon,
  });
  factory PontoPrecoMapaOperacional.fromMap(Map<String, dynamic> m) => PontoPrecoMapaOperacional(
        cnpj: m['cnpj'] as String? ?? '',
        razaoSocial: m['razao_social'] as String?,
        municipio: m['municipio'] as String?,
        uf: m['uf'] as String?,
        combustivel: m['combustivel'] as String? ?? '—',
        preco: (m['preco'] as num?)?.toDouble() ?? 0,
        lat: (m['lat'] as num?)?.toDouble(),
        lon: (m['lon'] as num?)?.toDouble(),
      );
}

class ServicoPosto {
  final String cnpj;
  final bool? arla;
  final bool? funciona24h;
  final bool? possuiBanheiro;
  final bool? possuiEstacionamento;
  final bool? possuiInternet;
  final bool? possuiOleoGranel;
  final bool? possuiRestaurante;
  final bool? possuiTrocaOleo;
  final bool? pistaCaminhao;
  final bool? conveniencia;
  final bool? convenienciaAmPm;
  const ServicoPosto({
    required this.cnpj,
    required this.arla,
    required this.funciona24h,
    required this.possuiBanheiro,
    required this.possuiEstacionamento,
    required this.possuiInternet,
    required this.possuiOleoGranel,
    required this.possuiRestaurante,
    required this.possuiTrocaOleo,
    required this.pistaCaminhao,
    required this.conveniencia,
    required this.convenienciaAmPm,
  });
  factory ServicoPosto.fromMap(Map<String, dynamic> m) => ServicoPosto(
        cnpj: m['cnpj'] as String? ?? '',
        arla: m['arla'] as bool?,
        funciona24h: m['funciona_24h'] as bool?,
        possuiBanheiro: m['possui_banheiro'] as bool?,
        possuiEstacionamento: m['possui_estacionamento'] as bool?,
        possuiInternet: m['possui_internet'] as bool?,
        possuiOleoGranel: m['possui_oleo_granel'] as bool?,
        possuiRestaurante: m['possui_restaurante'] as bool?,
        possuiTrocaOleo: m['possui_troca_oleo'] as bool?,
        pistaCaminhao: m['pista_caminhao'] as bool?,
        conveniencia: m['conveniencia'] as bool?,
        convenienciaAmPm: m['conveniencia_am_pm'] as bool?,
      );
  int get nServicos => [
        arla, funciona24h, possuiBanheiro, possuiEstacionamento, possuiInternet, possuiOleoGranel,
        possuiRestaurante, possuiTrocaOleo, pistaCaminhao, conveniencia, convenienciaAmPm,
      ].where((v) => v == true).length;
}

class PostoVisitado {
  final String cnpj;
  final String? razaoSocial;
  final String? municipio;
  final String? uf;
  final double? lat;
  final double? lon;
  final int visitas;
  final double precoMedio;
  final double litrosTotal;
  const PostoVisitado({
    required this.cnpj,
    required this.razaoSocial,
    required this.municipio,
    required this.uf,
    required this.lat,
    required this.lon,
    required this.visitas,
    required this.precoMedio,
    required this.litrosTotal,
  });
  factory PostoVisitado.fromMap(Map<String, dynamic> m) => PostoVisitado(
        cnpj: m['cnpj'] as String? ?? '',
        razaoSocial: m['razao_social'] as String?,
        municipio: m['municipio'] as String?,
        uf: m['uf'] as String?,
        lat: (m['lat'] as num?)?.toDouble(),
        lon: (m['lon'] as num?)?.toDouble(),
        visitas: (m['visitas'] as num?)?.toInt() ?? 0,
        precoMedio: (m['preco_medio'] as num?)?.toDouble() ?? 0,
        litrosTotal: (m['litros_total'] as num?)?.toDouble() ?? 0,
      );
}

class SerieTendenciaPonto {
  final String mes;
  final String uf;
  final String combustivel;
  final double precoMedio;
  final int qtd;
  const SerieTendenciaPonto({
    required this.mes,
    required this.uf,
    required this.combustivel,
    required this.precoMedio,
    required this.qtd,
  });
  factory SerieTendenciaPonto.fromMap(Map<String, dynamic> m) => SerieTendenciaPonto(
        mes: m['mes'] as String? ?? '',
        uf: m['uf'] as String? ?? '',
        combustivel: m['combustivel'] as String? ?? '—',
        precoMedio: (m['preco_medio'] as num?)?.toDouble() ?? 0,
        qtd: (m['qtd'] as num?)?.toInt() ?? 0,
      );
}

class VolatilidadeMensalPonto {
  final String mes;
  final String combustivel;
  final double volatilidade;
  final int qtd;
  const VolatilidadeMensalPonto({
    required this.mes,
    required this.combustivel,
    required this.volatilidade,
    required this.qtd,
  });
  factory VolatilidadeMensalPonto.fromMap(Map<String, dynamic> m) => VolatilidadeMensalPonto(
        mes: m['mes'] as String? ?? '',
        combustivel: m['combustivel'] as String? ?? '—',
        volatilidade: (m['volatilidade'] as num?)?.toDouble() ?? 0,
        qtd: (m['qtd'] as num?)?.toInt() ?? 0,
      );
}

// Fase Inteligência-Rede-Meios-Pagamento — pedido do Daniel: "painel de
// preços médios com os preços praticados nos abastecimentos nos diversos
// meios de pagamento... variações por Estado e por Região... indicadores
// de volumes por combustível". "Meio de pagamento" = provedor de
// abastecimentos_unificado (profrotas/TicketLog/Valecard/Veloe/RedeFrota —
// já são cartões/redes reais, não existe outra coluna de forma de
// pagamento no schema). Vem granular (RPC preco_medio_por_meio_pagamento)
// e toda agregação (por provedor, combustível, UF, região) acontece na
// aba, mesmo padrão da web (PrecosPorMeioPagamento.tsx).
class ItemPrecoMeioPagamento {
  final String provedor;
  final String? uf;
  final String? regiao;
  final String combustivel;
  final double precoMedio;
  final double litrosTotal;
  final double valorTotal;
  final int qtd;
  const ItemPrecoMeioPagamento({
    required this.provedor,
    required this.uf,
    required this.regiao,
    required this.combustivel,
    required this.precoMedio,
    required this.litrosTotal,
    required this.valorTotal,
    required this.qtd,
  });
  factory ItemPrecoMeioPagamento.fromMap(Map<String, dynamic> m) => ItemPrecoMeioPagamento(
        provedor: m['provedor'] as String? ?? '—',
        uf: m['uf'] as String?,
        regiao: m['regiao'] as String?,
        combustivel: m['combustivel'] as String? ?? '—',
        precoMedio: (m['preco_medio'] as num?)?.toDouble() ?? 0,
        litrosTotal: (m['litros_total'] as num?)?.toDouble() ?? 0,
        valorTotal: (m['valor_total'] as num?)?.toDouble() ?? 0,
        qtd: (m['qtd_abastecimentos'] as num?)?.toInt() ?? 0,
      );
}

class InteligenciaRedeCompleta {
  final KpisGerais kpis;
  final List<PrecoCombustivelRef> precoPorCombustivel;
  final SemanaAnp? semanaAnpMaisRecente;
  final List<EvolucaoMensalPonto> evolucaoMensal;
  final Map<String, double> referenciasPorCombustivel;
  final List<AlertaPreco> alertas;
  final int totalAvaliados;
  final double piorDesvio;
  final double desvioMedio;
  final double pctAlerta;
  final List<ResumoAlertaEstado> alertasPorEstado;
  final List<CoberturaMacro> coberturaMacrorregiao;
  final List<OportunidadeExpansao> oportunidades;
  final List<CoberturaUf> cobertura;
  final List<MunicipioRede> topMunicipios;
  final List<PontoMapaSimples> pontosMapa;
  final Map<String, int> postosPorUf;
  final Map<String, int> municipiosPorUf;
  final Map<String, int> coordPorUf;
  final List<DistribuidoraUf> distribuidorasPorUf;
  final List<PrecoUf> precosPorUf;
  final List<String> ufsDisponiveis;
  final List<RegistroPrecoHistorico> historicoDetalhado;
  final List<PrecoRealPeriodo> precoRealPeriodo;
  final List<PontoPrecoMapaOperacional> precosMapaOperacional;
  final List<AlertaPreco> desvioAnp;
  final List<ServicoPosto> servicosPosto;
  final List<PostoVisitado> postosVisitados;
  final Map<String, double> dieselAnpPorUf;
  final Map<String, int> demandaPorUf;
  final List<SerieTendenciaPonto> serieTendencia;
  final List<VolatilidadeMensalPonto> volatilidadeMensal;
  final List<ItemPrecoMeioPagamento> precosPorMeioPagamento;

  const InteligenciaRedeCompleta({
    required this.kpis,
    required this.precoPorCombustivel,
    required this.semanaAnpMaisRecente,
    required this.evolucaoMensal,
    required this.referenciasPorCombustivel,
    required this.alertas,
    required this.totalAvaliados,
    required this.piorDesvio,
    required this.desvioMedio,
    required this.pctAlerta,
    required this.alertasPorEstado,
    required this.coberturaMacrorregiao,
    required this.oportunidades,
    required this.cobertura,
    required this.topMunicipios,
    required this.pontosMapa,
    required this.postosPorUf,
    required this.municipiosPorUf,
    required this.coordPorUf,
    required this.distribuidorasPorUf,
    required this.precosPorUf,
    required this.ufsDisponiveis,
    required this.historicoDetalhado,
    required this.precoRealPeriodo,
    required this.precosMapaOperacional,
    required this.desvioAnp,
    required this.servicosPosto,
    required this.postosVisitados,
    required this.dieselAnpPorUf,
    required this.demandaPorUf,
    required this.serieTendencia,
    required this.volatilidadeMensal,
    required this.precosPorMeioPagamento,
  });
}

// ---------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------

final inteligenciaRedeCompletaProvider = FutureProvider.autoDispose<InteligenciaRedeCompleta?>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return null;
  final supabase = SupabaseService.client;

  double? resolverReferencia(String combustivel, Map<String, double> referenciaOficialPorProduto) {
    final categoriaAnp = produtoParaCategoriaAnp[combustivel];
    final referenciaOficial = categoriaAnp != null ? referenciaOficialPorProduto[categoriaAnp] : null;
    return referenciaOficial ?? anpPrecoReferenciaFallback[combustivel];
  }

  // Chamadas sequenciais — mesmo padrão já usado na v1 desta tela e no
  // resto do app (não Future.wait).
  final postosPorUfRaw = await supabase.rpc('postos_gf_por_uf') as List;
  final anpPorUfRaw = await supabase.rpc('anp_postos_por_uf') as List;
  final municipiosUnicos = (await supabase.rpc('postos_gf_municipios_unicos') as int?) ?? 0;
  final precoPorCombustivelRaw = await supabase.rpc('preco_medio_por_combustivel', params: {'p_empresa_id': empresaId}) as List;
  final totalPostosResp = await supabase.from('postos_gf').select('cnpj').eq('empresa_id', empresaId).count(CountOption.exact);
  final topMunicipiosRaw = await supabase.rpc('postos_gf_top_municipios', params: {'p_limit': 10}) as List;
  final pontosMapaRaw = await supabase.rpc('postos_gf_pontos_mapa', params: {'p_empresa_id': empresaId}) as List;
  final evolucaoMensalRaw = await supabase.rpc('historico_precos_evolucao_mensal') as List;
  final alertasRaw = await supabase.rpc('postos_gf_alertas_preco', params: {'p_threshold': 0.05, 'p_empresa_id': empresaId}) as List;
  final universoAvaliadoRaw = await supabase.rpc('postos_gf_alertas_preco', params: {'p_threshold': -100, 'p_empresa_id': empresaId}) as List;
  final municipiosPorUfRaw = await supabase.rpc('postos_gf_municipios_por_uf') as List;
  final distribuidorasPorUfRaw = await supabase.rpc('postos_gf_distribuidoras_por_uf') as List;
  final precosPorUfRaw = await supabase.rpc('preco_medio_por_combustivel_uf') as List;
  final serieTendenciaRaw = await supabase.rpc('historico_precos_serie_uf_combustivel', params: {'p_empresa_id': empresaId}) as List;
  final volatilidadeMensalRaw = await supabase.rpc('historico_precos_volatilidade_mensal', params: {'p_empresa_id': empresaId}) as List;
  final historicoDetalhadoRaw = await supabase.rpc('historico_precos_detalhado', params: {'p_empresa_id': empresaId}) as List;
  final precoRealPeriodoRaw = await supabase.rpc('abastecimentos_preco_periodo') as List;
  final precosMapaOperacionalRaw = await supabase.rpc('postos_gf_precos_mapa') as List;
  final desvioAnpRaw = await supabase.rpc('postos_gf_desvio_anp', params: {'p_empresa_id': empresaId}) as List;
  final servicosPostoRaw = await supabase.rpc('postos_gf_servicos', params: {'p_empresa_id': empresaId}) as List;
  final postosVisitadosRaw = await supabase.rpc('abastecimentos_postos_visitados') as List;
  final precosPorMeioPagamentoRaw = await supabase.rpc('preco_medio_por_meio_pagamento', params: {'p_empresa_id': empresaId}) as List;

  // Preço do diesel S10 por estado (ANP) — só pro score de oportunidade de
  // expansão.
  final dieselPorUfRaw = await supabase
      .from('anp_precos_referencia')
      .select('estado, preco_medio')
      .eq('nivel', 'estado')
      .eq('produto', 'OLEO DIESEL S10') as List;

  // Referência oficial ANP (nível Brasil, semana mais recente importada).
  final semanaMaisRecenteRaw = await supabase
      .from('anp_precos_referencia')
      .select('data_inicial, data_final')
      .eq('nivel', 'brasil')
      .order('data_final', ascending: false)
      .limit(1)
      .maybeSingle();

  SemanaAnp? semanaMaisRecente;
  final referenciaOficialPorProduto = <String, double>{};
  if (semanaMaisRecenteRaw != null) {
    semanaMaisRecente = SemanaAnp(
      dataInicial: DateTime.parse(semanaMaisRecenteRaw['data_inicial'] as String),
      dataFinal: DateTime.parse(semanaMaisRecenteRaw['data_final'] as String),
    );
    final referenciaSemana = await supabase
        .from('anp_precos_referencia')
        .select('produto, preco_medio')
        .eq('nivel', 'brasil')
        .eq('data_final', semanaMaisRecenteRaw['data_final'] as String) as List;
    for (final r in referenciaSemana) {
      final precoMedio = (r['preco_medio'] as num?)?.toDouble();
      final produto = r['produto'] as String?;
      if (precoMedio != null && produto != null) referenciaOficialPorProduto[produto] = precoMedio;
    }
  }

  // ---- Visão Geral ----
  final postosPorUf = <String, int>{
    for (final r in postosPorUfRaw) (r['uf'] as String): (r['total'] as num).toInt(),
  };
  final anpPorUf = <String, int>{
    for (final r in anpPorUfRaw) (r['uf'] as String): (r['total'] as num).toInt(),
  };
  final estadosComPosto = postosPorUf.keys.toSet();
  final coberturaBr = ((estadosComPosto.length / 27) * 100).round();
  final totalGf = (totalPostosResp).count;

  final cobertura = postosPorUf.entries
      .map((e) {
        final totalAnp = anpPorUf[e.key] ?? 0;
        return CoberturaUf(
          uf: e.key,
          postosGf: e.value,
          totalAnp: totalAnp,
          penetracao: totalAnp > 0 ? (e.value / totalAnp) * 100 : 0,
        );
      })
      .toList()
    ..sort((a, b) => b.postosGf.compareTo(a.postosGf));

  final precoPorCombustivel = (precoPorCombustivelRaw).map((r) {
    final combustivel = r['combustivel'] as String? ?? '—';
    final referencia = resolverReferencia(combustivel, referenciaOficialPorProduto);
    final categoriaAnp = produtoParaCategoriaAnp[combustivel];
    final ehOficial = categoriaAnp != null && referenciaOficialPorProduto.containsKey(categoriaAnp);
    final precoMedio = (r['preco_medio'] as num?)?.toDouble() ?? 0;
    return PrecoCombustivelRef(
      combustivel: combustivel,
      precoMedio: precoMedio,
      qtdPostos: (r['qtd_postos'] as num?)?.toInt() ?? 0,
      referencia: referencia,
      ehOficial: ehOficial,
      deltaPct: referencia != null && referencia != 0 ? ((precoMedio - referencia) / referencia) * 100 : null,
    );
  }).toList();

  final itensDiesel = precoPorCombustivel.where((p) => p.combustivel.toLowerCase().startsWith('diesel')).toList();
  final somaPostosDiesel = itensDiesel.fold<int>(0, (soma, p) => soma + p.qtdPostos);
  final dieselGf = somaPostosDiesel > 0
      ? itensDiesel.fold<double>(0, (soma, p) => soma + p.precoMedio * p.qtdPostos) / somaPostosDiesel
      : 0.0;
  final dieselAnpRef = referenciaOficialPorProduto['OLEO DIESEL S10'] ?? anpPrecoReferenciaFallback['Diesel S10'];
  final deltaDieselPct = dieselGf > 0 && dieselAnpRef != null ? ((dieselGf - dieselAnpRef) / dieselAnpRef) * 100 : null;
  final savingPotencialAno = (dieselGf > 0 && dieselAnpRef != null && dieselAnpRef > dieselGf)
      ? (dieselAnpRef - dieselGf) * 100 * 52 * totalGf
      : 0.15 * 100 * 52 * totalGf;

  final topMunicipios = (topMunicipiosRaw).map((m) => MunicipioRede.fromMap(m as Map<String, dynamic>)).toList();
  final pontosMapa = (pontosMapaRaw).map((m) => PontoMapaSimples.fromMap(m as Map<String, dynamic>)).toList();

  final evolucaoMensal = (evolucaoMensalRaw).map((m) => EvolucaoMensalPonto.fromMap(m as Map<String, dynamic>)).toList();
  final referenciasPorCombustivel = <String, double>{};
  for (final combustivel in evolucaoMensal.map((e) => e.combustivel).toSet()) {
    final ref = resolverReferencia(combustivel, referenciaOficialPorProduto);
    if (ref != null) referenciasPorCombustivel[combustivel] = ref;
  }

  // ---- Alertas de Preço ----
  final alertas = (alertasRaw).map((m) => AlertaPreco.fromMap(m as Map<String, dynamic>)).toList(); // já vem ordenado desc (diff_pct) do banco
  final totalAvaliados = universoAvaliadoRaw.length;
  final totalAlertas = alertas.length;
  final pctAlerta = totalAvaliados > 0 ? (totalAlertas / totalAvaliados) * 100 : 0.0;
  final piorDesvio = alertas.fold<double>(0, (max, a) => math.max(max, a.diffPct));
  final desvioMedio = totalAlertas > 0 ? alertas.fold<double>(0, (s, a) => s + a.diffPct) / totalAlertas : 0.0;

  final alertasPorEstadoMap = <String, ResumoAlertaEstado>{};
  for (final a in alertas) {
    if (a.uf == null) continue;
    final atual = alertasPorEstadoMap[a.uf!];
    alertasPorEstadoMap[a.uf!] = ResumoAlertaEstado(
      uf: a.uf!,
      postosAlerta: (atual?.postosAlerta ?? 0) + 1,
      piorDesvio: math.max(atual?.piorDesvio ?? 0, a.diffPct),
    );
  }
  final alertasPorEstado = alertasPorEstadoMap.values.toList()
    ..sort((a, b) => b.postosAlerta.compareTo(a.postosAlerta));

  // ---- Macrorregião & Expansão ----
  final municipiosPorUf = <String, int>{
    for (final r in municipiosPorUfRaw) (r['uf'] as String): (r['municipios'] as num).toInt(),
  };
  final coberturaMacrorregiao = regioesBrasil.entries.map((entry) {
    final regiao = entry.key;
    final ufs = entry.value;
    final postosGf = ufs.fold<int>(0, (soma, uf) => soma + (postosPorUf[uf] ?? 0));
    final municipiosComGf = ufs.fold<int>(0, (soma, uf) => soma + (municipiosPorUf[uf] ?? 0));
    final totalMunicipios = totalMunicipiosRegiao[regiao] ?? 1;
    final estadosComGf = ufs.where((uf) => postosPorUf.containsKey(uf)).length;
    return CoberturaMacro(
      regiao: regiao,
      postosGf: postosGf,
      municipiosComGf: municipiosComGf,
      totalMunicipios: totalMunicipios,
      coberturaPct: ((municipiosComGf / totalMunicipios) * 1000).round() / 10,
      estadosComGf: estadosComGf,
      totalUfs: ufs.length,
    );
  }).toList()
    ..sort((a, b) => b.coberturaPct.compareTo(a.coberturaPct));

  final dieselPorUf = <String, double>{};
  for (final r in dieselPorUfRaw) {
    final precoMedio = (r['preco_medio'] as num?)?.toDouble();
    if (precoMedio == null) continue;
    final estado = r['estado'] as String?;
    final uf = estadoParaUf[estado] ?? estado;
    if (uf != null) dieselPorUf[uf] = precoMedio;
  }
  final dieselMax = dieselPorUf.values.fold<double>(1, (m, v) => math.max(m, v));
  final oportunidades = anpPorUf.keys.map((uf) {
    final postosGf = postosPorUf[uf] ?? 0;
    final totalAnp = anpPorUf[uf] ?? 0;
    final penetracaoPct = totalAnp > 0 ? (postosGf / totalAnp) * 100 : 0.0;
    final dieselUf = dieselPorUf[uf];
    final score = dieselUf != null ? (1 - math.min(penetracaoPct / 100, 1)) * (dieselUf / dieselMax) * 100 : 0.0;
    return OportunidadeExpansao(
      uf: uf,
      postosGf: postosGf,
      penetracaoPct: (penetracaoPct * 100).round() / 100,
      dieselAnp: dieselUf,
      score: (score * 10).round() / 10,
    );
  }).toList()
    ..sort((a, b) => b.score.compareTo(a.score));
  final top10Oportunidades = oportunidades.take(10).toList();

  // ---- Modo Comparativo ----
  final coordPorUf = <String, int>{};
  for (final p in pontosMapa) {
    if (p.uf == null || p.uf!.isEmpty) continue;
    coordPorUf[p.uf!] = (coordPorUf[p.uf!] ?? 0) + 1;
  }
  final distribuidorasPorUf = (distribuidorasPorUfRaw).map((m) => DistribuidoraUf.fromMap(m as Map<String, dynamic>)).toList();
  final precosPorUf = (precosPorUfRaw).map((m) => PrecoUf.fromMap(m as Map<String, dynamic>)).toList();

  // ---- Tendência × Sazonalidade ----
  final serieTendencia = (serieTendenciaRaw).map((m) => SerieTendenciaPonto.fromMap(m as Map<String, dynamic>)).toList();
  final volatilidadeMensal = (volatilidadeMensalRaw).map((m) => VolatilidadeMensalPonto.fromMap(m as Map<String, dynamic>)).toList();

  // ---- Evolução Temporal ----
  final historicoDetalhado = (historicoDetalhadoRaw).map((m) => RegistroPrecoHistorico.fromMap(m as Map<String, dynamic>)).toList();
  final precoRealPeriodo = (precoRealPeriodoRaw).map((m) => PrecoRealPeriodo.fromMap(m as Map<String, dynamic>)).toList();

  // ---- Operacional ----
  final precosMapaOperacional = (precosMapaOperacionalRaw).map((m) => PontoPrecoMapaOperacional.fromMap(m as Map<String, dynamic>)).toList();
  final desvioAnp = (desvioAnpRaw).map((m) => AlertaPreco.fromMap(m as Map<String, dynamic>)).toList();
  final servicosPosto = (servicosPostoRaw).map((m) => ServicoPosto.fromMap(m as Map<String, dynamic>)).toList();
  final postosVisitados = (postosVisitadosRaw).map((m) => PostoVisitado.fromMap(m as Map<String, dynamic>)).toList();

  // ---- Cobertura × Demanda ----
  final demandaPorUf = <String, int>{};
  for (final p in postosVisitados) {
    if (p.uf == null || p.uf!.isEmpty) continue;
    demandaPorUf[p.uf!] = (demandaPorUf[p.uf!] ?? 0) + p.visitas;
  }

  // ---- Meios de Pagamento ----
  final precosPorMeioPagamento = (precosPorMeioPagamentoRaw).map((m) => ItemPrecoMeioPagamento.fromMap(m as Map<String, dynamic>)).toList();

  return InteligenciaRedeCompleta(
    kpis: KpisGerais(
      totalGf: totalGf,
      estadosComPosto: estadosComPosto.length,
      municipiosUnicos: municipiosUnicos,
      coberturaBr: coberturaBr,
      dieselGf: dieselGf,
      deltaDieselPct: deltaDieselPct,
      savingPotencialAno: savingPotencialAno,
    ),
    precoPorCombustivel: precoPorCombustivel,
    semanaAnpMaisRecente: semanaMaisRecente,
    evolucaoMensal: evolucaoMensal,
    referenciasPorCombustivel: referenciasPorCombustivel,
    alertas: alertas,
    totalAvaliados: totalAvaliados,
    piorDesvio: piorDesvio,
    desvioMedio: desvioMedio,
    pctAlerta: pctAlerta,
    alertasPorEstado: alertasPorEstado,
    coberturaMacrorregiao: coberturaMacrorregiao,
    oportunidades: top10Oportunidades,
    cobertura: cobertura,
    topMunicipios: topMunicipios,
    pontosMapa: pontosMapa,
    postosPorUf: postosPorUf,
    municipiosPorUf: municipiosPorUf,
    coordPorUf: coordPorUf,
    distribuidorasPorUf: distribuidorasPorUf,
    precosPorUf: precosPorUf,
    ufsDisponiveis: postosPorUf.keys.toList()..sort(),
    historicoDetalhado: historicoDetalhado,
    precoRealPeriodo: precoRealPeriodo,
    precosMapaOperacional: precosMapaOperacional,
    desvioAnp: desvioAnp,
    servicosPosto: servicosPosto,
    postosVisitados: postosVisitados,
    dieselAnpPorUf: dieselPorUf,
    demandaPorUf: demandaPorUf,
    serieTendencia: serieTendencia,
    volatilidadeMensal: volatilidadeMensal,
    precosPorMeioPagamento: precosPorMeioPagamento,
  );
});
