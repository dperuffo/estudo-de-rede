import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-Cotações (02/09/2026, pedido do Daniel: "equalizar o PWA Cliente
// com as funcionalidades construídas para a web cliente") — porta de
// cotacoes/novo/page.tsx + [id]/page.tsx + actions.ts + src/lib/
// freteCalculo.ts. O motor de cálculo é função pura (sem RPC), replicada
// 1:1 aqui (mesmas fórmulas e arredondamento). Geocodificação reaproveita
// geo_service.dart (Nominatim), já usado em /fretes — não precisa de nada
// novo. Sem cálculo de rota (OSRM): km_estimado é digitado manualmente,
// igual à web.
double round2(num v) => (v * 100).round() / 100;

class TabelaFrete {
  final String id;
  final String nome;
  final double percentualAdValorem;
  final double percentualGris;
  final double valorTde;
  final double valorTda;
  final double valorDespacho;
  final double valorPedagio;
  final double percentualIcms;

  const TabelaFrete({
    required this.id,
    required this.nome,
    required this.percentualAdValorem,
    required this.percentualGris,
    required this.valorTde,
    required this.valorTda,
    required this.valorDespacho,
    required this.valorPedagio,
    required this.percentualIcms,
  });

  factory TabelaFrete.fromMap(Map<String, dynamic> m) => TabelaFrete(
        id: m['id'] as String,
        nome: m['nome'] as String,
        percentualAdValorem:
            (m['percentual_ad_valorem'] as num?)?.toDouble() ?? 0,
        percentualGris: (m['percentual_gris'] as num?)?.toDouble() ?? 0,
        valorTde: (m['valor_tde'] as num?)?.toDouble() ?? 0,
        valorTda: (m['valor_tda'] as num?)?.toDouble() ?? 0,
        valorDespacho: (m['valor_despacho'] as num?)?.toDouble() ?? 0,
        valorPedagio: (m['valor_pedagio'] as num?)?.toDouble() ?? 0,
        percentualIcms: (m['percentual_icms'] as num?)?.toDouble() ?? 0,
      );
}

class FaixaPeso {
  final double pesoMinKg;
  final double? pesoMaxKg;
  final double valorPorKg;
  final double valorMinimo;

  const FaixaPeso({
    required this.pesoMinKg,
    required this.pesoMaxKg,
    required this.valorPorKg,
    required this.valorMinimo,
  });

  factory FaixaPeso.fromMap(Map<String, dynamic> m) => FaixaPeso(
        pesoMinKg: (m['peso_min_kg'] as num).toDouble(),
        pesoMaxKg: (m['peso_max_kg'] as num?)?.toDouble(),
        valorPorKg: (m['valor_por_kg'] as num).toDouble(),
        valorMinimo: (m['valor_minimo'] as num?)?.toDouble() ?? 0,
      );
}

class ResultadoCalculoFrete {
  final double valorFretePeso;
  final double valorAdValorem;
  final double valorGris;
  final double valorTde;
  final double valorTda;
  final double valorDespacho;
  final double valorPedagio;
  final double valorIcms;
  final double valorTotal;

  const ResultadoCalculoFrete({
    required this.valorFretePeso,
    required this.valorAdValorem,
    required this.valorGris,
    required this.valorTde,
    required this.valorTda,
    required this.valorDespacho,
    required this.valorPedagio,
    required this.valorIcms,
    required this.valorTotal,
  });
}

class Cotacao {
  final String id;
  final String origemLabel;
  final double origemLat;
  final double origemLon;
  final String destinoLabel;
  final double destinoLat;
  final double destinoLon;
  final double? kmEstimado;
  final double pesoKg;
  final double valorCarga;
  final String? tipoCarga;
  final int? numeroEixos;
  final double valorFretePeso;
  final double valorAdValorem;
  final double valorGris;
  final double valorTde;
  final double valorTda;
  final double valorDespacho;
  final double valorPedagio;
  final double valorIcms;
  final double valorTotal;
  final double? pisoAnttValor;
  final bool pisoAnttAlerta;
  final String status; // simulada | convertida | descartada
  final String? freteId;
  final String? observacoes;
  final String criadoEm;

  const Cotacao({
    required this.id,
    required this.origemLabel,
    required this.origemLat,
    required this.origemLon,
    required this.destinoLabel,
    required this.destinoLat,
    required this.destinoLon,
    required this.kmEstimado,
    required this.pesoKg,
    required this.valorCarga,
    required this.tipoCarga,
    required this.numeroEixos,
    required this.valorFretePeso,
    required this.valorAdValorem,
    required this.valorGris,
    required this.valorTde,
    required this.valorTda,
    required this.valorDespacho,
    required this.valorPedagio,
    required this.valorIcms,
    required this.valorTotal,
    required this.pisoAnttValor,
    required this.pisoAnttAlerta,
    required this.status,
    required this.freteId,
    required this.observacoes,
    required this.criadoEm,
  });

  factory Cotacao.fromMap(Map<String, dynamic> m) => Cotacao(
        id: m['id'] as String,
        origemLabel: m['origem_label'] as String,
        origemLat: (m['origem_lat'] as num?)?.toDouble() ?? 0,
        origemLon: (m['origem_lon'] as num?)?.toDouble() ?? 0,
        destinoLabel: m['destino_label'] as String,
        destinoLat: (m['destino_lat'] as num?)?.toDouble() ?? 0,
        destinoLon: (m['destino_lon'] as num?)?.toDouble() ?? 0,
        kmEstimado: (m['km_estimado'] as num?)?.toDouble(),
        pesoKg: (m['peso_kg'] as num).toDouble(),
        valorCarga: (m['valor_carga'] as num?)?.toDouble() ?? 0,
        tipoCarga: m['tipo_carga'] as String?,
        numeroEixos: (m['numero_eixos'] as num?)?.toInt(),
        valorFretePeso: (m['valor_frete_peso'] as num?)?.toDouble() ?? 0,
        valorAdValorem: (m['valor_ad_valorem'] as num?)?.toDouble() ?? 0,
        valorGris: (m['valor_gris'] as num?)?.toDouble() ?? 0,
        valorTde: (m['valor_tde'] as num?)?.toDouble() ?? 0,
        valorTda: (m['valor_tda'] as num?)?.toDouble() ?? 0,
        valorDespacho: (m['valor_despacho'] as num?)?.toDouble() ?? 0,
        valorPedagio: (m['valor_pedagio'] as num?)?.toDouble() ?? 0,
        valorIcms: (m['valor_icms'] as num?)?.toDouble() ?? 0,
        valorTotal: (m['valor_total'] as num?)?.toDouble() ?? 0,
        pisoAnttValor: (m['piso_antt_valor'] as num?)?.toDouble(),
        pisoAnttAlerta: m['piso_antt_alerta'] as bool? ?? false,
        status: m['status'] as String? ?? 'simulada',
        freteId: m['frete_id'] as String?,
        observacoes: m['observacoes'] as String?,
        criadoEm: m['criado_em'] as String? ?? '',
      );
}

class CotacoesService {
  final _supabase = SupabaseService.client;

  FaixaPeso? _encontrarFaixaPeso(double pesoKg, List<FaixaPeso> faixas) {
    if (faixas.isEmpty) return null;
    for (final f in faixas) {
      final dentroMin = pesoKg >= f.pesoMinKg;
      final dentroMax = f.pesoMaxKg == null || pesoKg <= f.pesoMaxKg!;
      if (dentroMin && dentroMax) return f;
    }
    final abertas = faixas.where((f) => f.pesoMaxKg == null).toList();
    if (abertas.isNotEmpty) return abertas.first;
    final ordenadas = [...faixas]
      ..sort((a, b) => b.pesoMinKg.compareTo(a.pesoMinKg));
    return ordenadas.first;
  }

  ResultadoCalculoFrete calcularFrete({
    required double pesoKg,
    required double valorCarga,
    required TabelaFrete tabela,
    required List<FaixaPeso> faixas,
  }) {
    final faixa = _encontrarFaixaPeso(pesoKg, faixas);
    final valorFretePeso = faixa == null
        ? 0.0
        : (pesoKg * faixa.valorPorKg > faixa.valorMinimo
            ? pesoKg * faixa.valorPorKg
            : faixa.valorMinimo);
    final valorAdValorem = round2(valorCarga * tabela.percentualAdValorem / 100);
    final valorGris = round2(valorCarga * tabela.percentualGris / 100);
    final subtotal = round2(valorFretePeso +
        valorAdValorem +
        valorGris +
        tabela.valorTde +
        tabela.valorTda +
        tabela.valorDespacho +
        tabela.valorPedagio);
    final aliquota = tabela.percentualIcms / 100;
    final valorTotal =
        (aliquota > 0 && aliquota < 1) ? round2(subtotal / (1 - aliquota)) : subtotal;
    final valorIcms = round2(valorTotal - subtotal);
    return ResultadoCalculoFrete(
      valorFretePeso: round2(valorFretePeso),
      valorAdValorem: valorAdValorem,
      valorGris: valorGris,
      valorTde: tabela.valorTde,
      valorTda: tabela.valorTda,
      valorDespacho: tabela.valorDespacho,
      valorPedagio: tabela.valorPedagio,
      valorIcms: valorIcms,
      valorTotal: valorTotal,
    );
  }

  Future<List<TabelaFrete>> buscarTabelasFrete(String empresaId) async {
    final rows = await _supabase
        .from('tabelas_frete')
        .select(
          'id, nome, percentual_ad_valorem, percentual_gris, valor_tde, valor_tda, valor_despacho, valor_pedagio, percentual_icms',
        )
        .eq('empresa_id', empresaId)
        .eq('ativo', true)
        .order('nome');
    return rows.map((m) => TabelaFrete.fromMap(m)).toList();
  }

  Future<List<FaixaPeso>> buscarFaixas(String tabelaFreteId) async {
    final rows = await _supabase
        .from('tabelas_frete_faixas')
        .select('peso_min_kg, peso_max_kg, valor_por_kg, valor_minimo')
        .eq('tabela_frete_id', tabelaFreteId)
        .order('peso_min_kg');
    return rows.map((m) => FaixaPeso.fromMap(m)).toList();
  }

  Future<List<String>> buscarTiposCarga() async {
    final rows =
        await _supabase.from('pisos_antt').select('tipo_carga');
    return rows.map((m) => m['tipo_carga'] as String).toSet().toList()..sort();
  }

  Future<List<int>> buscarEixosPorTipo(String tipoCarga) async {
    final rows = await _supabase
        .from('pisos_antt')
        .select('numero_eixos')
        .eq('tipo_carga', tipoCarga);
    return rows.map((m) => (m['numero_eixos'] as num).toInt()).toSet().toList()
      ..sort();
  }

  Future<({double? valor, bool alerta})> _calcularPisoAntt({
    required String? tipoCarga,
    required int? numeroEixos,
    required double? kmEstimado,
    required double valorTotal,
  }) async {
    if (tipoCarga == null || numeroEixos == null || kmEstimado == null) {
      return (valor: null, alerta: false);
    }
    final piso = await _supabase
        .from('pisos_antt')
        .select('coeficiente_deslocamento, coeficiente_carga_descarga')
        .eq('tipo_carga', tipoCarga)
        .eq('numero_eixos', numeroEixos)
        .order('vigencia_inicio', ascending: false)
        .limit(1)
        .maybeSingle();
    if (piso == null) return (valor: null, alerta: false);
    final coefDeslocamento =
        (piso['coeficiente_deslocamento'] as num).toDouble();
    final coefCargaDescarga =
        (piso['coeficiente_carga_descarga'] as num).toDouble();
    final pisoValor =
        round2(kmEstimado * coefDeslocamento + coefCargaDescarga);
    return (valor: pisoValor, alerta: valorTotal < pisoValor);
  }

  Future<({String? id, String? erro})> criarCotacao({
    required String empresaId,
    required String tabelaFreteId,
    required String origemLabel,
    required double origemLat,
    required double origemLon,
    required String destinoLabel,
    required double destinoLat,
    required double destinoLon,
    double? kmEstimado,
    required double pesoKg,
    double valorCarga = 0,
    String? tipoCarga,
    int? numeroEixos,
    String? observacoes,
  }) async {
    if (pesoKg <= 0) return (id: null, erro: 'Informe um peso válido.');
    final tabelaMap = await _supabase
        .from('tabelas_frete')
        .select(
          'id, nome, percentual_ad_valorem, percentual_gris, valor_tde, valor_tda, valor_despacho, valor_pedagio, percentual_icms',
        )
        .eq('id', tabelaFreteId)
        .maybeSingle();
    if (tabelaMap == null) {
      return (id: null, erro: 'Tabela de frete não encontrada.');
    }
    final tabela = TabelaFrete.fromMap(tabelaMap);
    final faixas = await buscarFaixas(tabelaFreteId);
    final calculo = calcularFrete(
        pesoKg: pesoKg, valorCarga: valorCarga, tabela: tabela, faixas: faixas);
    final piso = await _calcularPisoAntt(
      tipoCarga: tipoCarga,
      numeroEixos: numeroEixos,
      kmEstimado: kmEstimado,
      valorTotal: calculo.valorTotal,
    );
    try {
      final inserido = await _supabase
          .from('cotacoes')
          .insert({
            'empresa_id': empresaId,
            'tabela_frete_id': tabelaFreteId,
            'origem_label': origemLabel,
            'origem_lat': origemLat,
            'origem_lon': origemLon,
            'destino_label': destinoLabel,
            'destino_lat': destinoLat,
            'destino_lon': destinoLon,
            'km_estimado': kmEstimado,
            'peso_kg': pesoKg,
            'valor_carga': valorCarga,
            'tipo_carga': tipoCarga,
            'numero_eixos': numeroEixos,
            'valor_frete_peso': calculo.valorFretePeso,
            'valor_ad_valorem': calculo.valorAdValorem,
            'valor_gris': calculo.valorGris,
            'valor_tde': calculo.valorTde,
            'valor_tda': calculo.valorTda,
            'valor_despacho': calculo.valorDespacho,
            'valor_pedagio': calculo.valorPedagio,
            'valor_icms': calculo.valorIcms,
            'valor_total': calculo.valorTotal,
            'piso_antt_valor': piso.valor,
            'piso_antt_alerta': piso.alerta,
            'status': 'simulada',
            'observacoes':
                (observacoes == null || observacoes.trim().isEmpty) ? null : observacoes.trim(),
            'criado_por': AuthService().emailAtual,
          })
          .select('id')
          .single();
      return (id: inserido['id'] as String, erro: null);
    } catch (e) {
      return (id: null, erro: 'Não foi possível salvar a cotação: $e');
    }
  }

  Future<List<Cotacao>> buscar(String empresaId) async {
    final rows = await _supabase
        .from('cotacoes')
        .select(
          'id, origem_label, origem_lat, origem_lon, destino_label, destino_lat, destino_lon, km_estimado, peso_kg, valor_carga, tipo_carga, numero_eixos, valor_frete_peso, valor_ad_valorem, valor_gris, valor_tde, valor_tda, valor_despacho, valor_pedagio, valor_icms, valor_total, piso_antt_valor, piso_antt_alerta, status, frete_id, observacoes, criado_em',
        )
        .eq('empresa_id', empresaId)
        .order('criado_em', ascending: false)
        .limit(100);
    return rows.map((m) => Cotacao.fromMap(m)).toList();
  }

  Future<Cotacao?> buscarDetalhe(String id) async {
    final m = await _supabase
        .from('cotacoes')
        .select(
          'id, origem_label, origem_lat, origem_lon, destino_label, destino_lat, destino_lon, km_estimado, peso_kg, valor_carga, tipo_carga, numero_eixos, valor_frete_peso, valor_ad_valorem, valor_gris, valor_tde, valor_tda, valor_despacho, valor_pedagio, valor_icms, valor_total, piso_antt_valor, piso_antt_alerta, status, frete_id, observacoes, criado_em',
        )
        .eq('id', id)
        .maybeSingle();
    if (m == null) return null;
    return Cotacao.fromMap(m);
  }

  Future<String?> descartar(String id) async {
    try {
      await _supabase.from('cotacoes').update({
        'status': 'descartada',
        'atualizado_em': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      return null;
    } catch (e) {
      return 'Não foi possível descartar: $e';
    }
  }

  // Porta simplificada de converterCotacaoEmFreteAcao: cria o frete +
  // plano de viagem vinculado, atualiza a cotação. Mesmo gate de plano
  // (Enterprise/trial) da web é aplicado pela RLS de `fretes`, então um
  // erro aqui pode vir dela.
  Future<({String? freteId, String? erro})> converterEmFrete(
      Cotacao cotacao, String empresaId) async {
    try {
      final frete = await _supabase
          .from('fretes')
          .insert({
            'empresa_id': empresaId,
            'titulo': 'Frete ${cotacao.origemLabel} → ${cotacao.destinoLabel}',
            'origem_label': cotacao.origemLabel,
            'origem_lat': cotacao.origemLat,
            'origem_lon': cotacao.origemLon,
            'destino_label': cotacao.destinoLabel,
            'destino_lat': cotacao.destinoLat,
            'destino_lon': cotacao.destinoLon,
            'tipo_carga': cotacao.tipoCarga,
            'peso_carga_kg': cotacao.pesoKg,
            'km_estimado': cotacao.kmEstimado,
            'valor_oferecido': cotacao.valorTotal,
            'status': 'disponivel',
            'criado_por': AuthService().emailAtual,
          })
          .select('id')
          .single();
      final freteId = frete['id'] as String;

      final plano = await _supabase
          .from('planos_viagem')
          .insert({
            'empresa_id': empresaId,
            'nome': 'Viagem ${cotacao.origemLabel} → ${cotacao.destinoLabel}',
            'km_estimado': cotacao.kmEstimado,
            'receita_viagem': cotacao.valorTotal,
            'observacoes':
                'Gerado a partir da cotação de ${cotacao.criadoEm.isEmpty ? '' : cotacao.criadoEm.substring(0, 10)}.',
          })
          .select('id')
          .single();
      final planoId = plano['id'] as String;

      await _supabase
          .from('fretes')
          .update({'plano_viagem_id': planoId}).eq('id', freteId);
      await _supabase.from('cotacoes').update({
        'status': 'convertida',
        'frete_id': freteId,
        'atualizado_em': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', cotacao.id);
      return (freteId: freteId, erro: null);
    } catch (e) {
      return (freteId: null, erro: 'Não foi possível converter em frete: $e');
    }
  }
}
