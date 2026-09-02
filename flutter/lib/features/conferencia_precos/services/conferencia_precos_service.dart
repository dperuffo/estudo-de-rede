import '../../../core/services/supabase_service.dart';

// Fase FLT-Conferência-Precos (02/09/2026, pedido do Daniel: "equalizar o
// PWA Cliente com as funcionalidades construídas para a web cliente") —
// porta da visão CLIENTE de conferencia-precos/page.tsx (a visão posto
// desta mesma tela não existe no PWA Cliente, mesma decisão de escopo já
// aplicada em outras telas "por segmento"). Mesmas 2 RPCs
// (cliente_divergencias_preco / cliente_extrato_diario) da migração
// "conferencia_precos_visao_cliente".
class DivergenciaPreco {
  final String id;
  final String provedor;
  final String dataAbastecimento;
  final String postoNome;
  final String? placa;
  final String? combustivel;
  final double? litros;
  final double? valorTotal;
  final double? precoPraticado;
  final double? precoAcordado;
  final double? diferencaRs;
  final double? diferencaPct;
  final bool temAjustePendente;

  const DivergenciaPreco({
    required this.id,
    required this.provedor,
    required this.dataAbastecimento,
    required this.postoNome,
    required this.placa,
    required this.combustivel,
    required this.litros,
    required this.valorTotal,
    required this.precoPraticado,
    required this.precoAcordado,
    required this.diferencaRs,
    required this.diferencaPct,
    required this.temAjustePendente,
  });

  String get chave => '$provedor:$id';

  factory DivergenciaPreco.fromMap(Map<String, dynamic> m) => DivergenciaPreco(
        id: m['id'].toString(),
        provedor: m['provedor'] as String,
        dataAbastecimento: m['data_abastecimento'] as String,
        postoNome: (m['posto_nome'] as String?) ?? '—',
        placa: m['placa'] as String?,
        combustivel: m['combustivel'] as String?,
        litros: (m['litros'] as num?)?.toDouble(),
        valorTotal: (m['valor_total'] as num?)?.toDouble(),
        precoPraticado: (m['preco_praticado'] as num?)?.toDouble(),
        precoAcordado: (m['preco_acordado'] as num?)?.toDouble(),
        diferencaRs: (m['diferenca_rs'] as num?)?.toDouble(),
        diferencaPct: (m['diferenca_pct'] as num?)?.toDouble(),
        temAjustePendente: m['tem_ajuste_pendente'] as bool? ?? false,
      );
}

class ExtratoDia {
  final String dia;
  final String provedor;
  final int qtdAbastecimentos;
  final double litros;
  final double valorTotal;
  final int qtdDivergencias;
  final double valorDivergencia;

  const ExtratoDia({
    required this.dia,
    required this.provedor,
    required this.qtdAbastecimentos,
    required this.litros,
    required this.valorTotal,
    required this.qtdDivergencias,
    required this.valorDivergencia,
  });

  factory ExtratoDia.fromMap(Map<String, dynamic> m) => ExtratoDia(
        dia: m['dia'] as String,
        provedor: m['provedor'] as String,
        qtdAbastecimentos: (m['qtd_abastecimentos'] as num).toInt(),
        litros: (m['litros'] as num).toDouble(),
        valorTotal: (m['valor_total'] as num).toDouble(),
        qtdDivergencias: (m['qtd_divergencias'] as num).toInt(),
        valorDivergencia: (m['valor_divergencia'] as num).toDouble(),
      );
}

class ResultadoConferenciaPrecos {
  final List<DivergenciaPreco> divergencias;
  final List<DivergenciaPreco> divergenciasHoje;
  final List<ExtratoDia> extrato;

  const ResultadoConferenciaPrecos({
    required this.divergencias,
    required this.divergenciasHoje,
    required this.extrato,
  });

  static const vazio = ResultadoConferenciaPrecos(
      divergencias: [], divergenciasHoje: [], extrato: []);

  double get valorDivergenciaHoje => divergenciasHoje.fold(
      0, (soma, d) => soma + (d.diferencaRs ?? 0).abs() * (d.litros ?? 0));

  int get totalAbastecimentosPeriodo =>
      extrato.fold(0, (s, e) => s + e.qtdAbastecimentos);
  double get totalLitrosPeriodo => extrato.fold(0, (s, e) => s + e.litros);
  double get totalValorPeriodo => extrato.fold(0, (s, e) => s + e.valorTotal);
  int get totalDivergenciasPeriodo =>
      extrato.fold(0, (s, e) => s + e.qtdDivergencias);
  double get totalValorDivergenciaPeriodo =>
      extrato.fold(0, (s, e) => s + e.valorDivergencia);
}

class ConferenciaPrecosService {
  final _supabase = SupabaseService.client;

  Future<ResultadoConferenciaPrecos> buscar({
    required String empresaId,
    required String de,
    required String ate,
  }) async {
    final hoje = DateTime.now().toIso8601String().substring(0, 10);

    final resultados = await Future.wait([
      _supabase.rpc('cliente_divergencias_preco', params: {
        'p_empresa_cliente_id': empresaId,
        'p_data_inicio': de,
        'p_data_fim': ate,
      }),
      _supabase.rpc('cliente_divergencias_preco', params: {
        'p_empresa_cliente_id': empresaId,
        'p_data_inicio': hoje,
        'p_data_fim': hoje,
      }),
      _supabase.rpc('cliente_extrato_diario', params: {
        'p_empresa_cliente_id': empresaId,
        'p_data_inicio': de,
        'p_data_fim': ate,
      }),
    ]);

    final divergenciasRaw = resultados[0] as List;
    final hojeRaw = resultados[1] as List;
    final extratoRaw = resultados[2] as List;

    return ResultadoConferenciaPrecos(
      divergencias: divergenciasRaw
          .map((m) => DivergenciaPreco.fromMap(m as Map<String, dynamic>))
          .toList(),
      divergenciasHoje: hojeRaw
          .map((m) => DivergenciaPreco.fromMap(m as Map<String, dynamic>))
          .toList(),
      extrato: extratoRaw
          .map((m) => ExtratoDia.fromMap(m as Map<String, dynamic>))
          .toList(),
    );
  }
}
