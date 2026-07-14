import '../../../core/services/supabase_service.dart';
import '../../postos/providers/postos_provider.dart' show ufsBrasil;
import '../services/geo_service.dart' as geo;
import '../services/roteirizacao_algoritmo.dart';

// Fase FLT-3 — Roteirização (cliente), porta de roteirizacao/page.tsx +
// posto/page.tsx + planejar/page.tsx + actions.ts (buscarPostosPorUfAcao +
// buscarPostoPorTermoAcao + calcularRoteirizacaoAcao). RLS/tabelas
// conferidas antes de portar: `postos_gf`/`historico_precos` têm
// self-service completo pra empresa do usuário (já usado em Postos
// Revendedores); `anp_postos`/`anp_precos_referencia` têm leitura PÚBLICA
// (`qual: true`, sem tenant-scoping) — dá pra consultar direto, sem RPC,
// igual à web.
//
// Escopo reduzido — a web tem 4 abas em Roteirização; 3 entraram no v1
// mobile:
//   - "Por UF/Município" (modo 'uf')
//   - "Consulta por Posto" (modo 'posto')
//   - "Roteirizador Inteligente" (modo 'planejar' — rota real via OSRM +
//     otimização de paradas, ver buscarCandidatosCorredor/
//     calcularRoteirizacao abaixo e roteirizacao_algoritmo.dart)
// Fora do escopo: comparativo lado a lado das 4 estratégias de peso (a web
// recalcula as 4 de uma vez pra montar uma tabela comparativa; aqui só
// calcula a estratégia escolhida — reduz o trabalho sem perder a função
// principal, dá pra trocar de estratégia e recalcular manualmente), GPX/
// PDF/PNG export e "Rotas Salvas" (persistência de consultas). Mapa
// interativo (flutter_map + tiles OSM) incluído nos 3 modos — ver
// mapa_postos.dart.
final ufParaEstadoAnp = {
  'AC': 'ACRE', 'AL': 'ALAGOAS', 'AP': 'AMAPA', 'AM': 'AMAZONAS', 'BA': 'BAHIA',
  'CE': 'CEARA', 'DF': 'DISTRITO FEDERAL', 'ES': 'ESPIRITO SANTO', 'GO': 'GOIAS',
  'MA': 'MARANHAO', 'MT': 'MATO GROSSO', 'MS': 'MATO GROSSO DO SUL', 'MG': 'MINAS GERAIS',
  'PA': 'PARA', 'PB': 'PARAIBA', 'PR': 'PARANA', 'PE': 'PERNAMBUCO', 'PI': 'PIAUI',
  'RJ': 'RIO DE JANEIRO', 'RN': 'RIO GRANDE DO NORTE', 'RS': 'RIO GRANDE DO SUL',
  'RO': 'RONDONIA', 'RR': 'RORAIMA', 'SC': 'SANTA CATARINA', 'SP': 'SAO PAULO',
  'SE': 'SERGIPE', 'TO': 'TOCANTINS',
};

// Só os valores (categorias ANP) importam aqui — usados pra buscar preços
// de referência em lote, igual a CATEGORIAS_ANP (actions.ts).
const categoriasAnp = [
  'OLEO DIESEL', 'OLEO DIESEL S10', 'ETANOL HIDRATADO', 'GASOLINA COMUM', 'GASOLINA ADITIVADA', 'GNV', 'GLP',
];

const _camposServico = [
  'funciona_24h', 'pista_caminhao', 'arla', 'conveniencia', 'conveniencia_am_pm',
  'possui_restaurante', 'possui_banheiro', 'possui_estacionamento', 'possui_troca_oleo', 'possui_internet',
];

String normalizarTexto(String? v) {
  if (v == null) return '';
  const comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
  const semAcento = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
  final buffer = StringBuffer();
  for (final ch in v.trim().toUpperCase().split('')) {
    final idx = comAcento.indexOf(ch);
    buffer.write(idx >= 0 ? semAcento[idx] : ch);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
}

// Porta fiel de calcularScorePosto (src/lib/roteirizacaoScore.ts). Nos 2
// modos portados aqui, `precoReferenciaAnp`/`posto`/`pontoReferencia`
// sempre chegam null (a web também não tem esse dado nesses 2 modos) — o
// score fica dominado pela % de serviços do posto.
class ScorePosto {
  final double score;
  final String grade; // A | B | C | D
  final String detalhePreco;
  final String detalheServicos;
  final String detalheDistancia;
  const ScorePosto({
    required this.score,
    required this.grade,
    required this.detalhePreco,
    required this.detalheServicos,
    required this.detalheDistancia,
  });
}

ScorePosto calcularScorePosto({
  double? precoPosto,
  double? precoReferenciaAnp,
  required int servicosAtivos,
  required int servicosTotal,
}) {
  double scorePreco = 50;
  String detalhePreco = 'Sem referência ANP';
  if (precoReferenciaAnp != null && precoReferenciaAnp > 0 && precoPosto != null && precoPosto > 0) {
    final diff = (precoPosto - precoReferenciaAnp) / precoReferenciaAnp;
    scorePreco = (50 - diff * 500).clamp(0, 100);
    detalhePreco = '${diff >= 0 ? '+' : ''}${(diff * 100).toStringAsFixed(1)}% vs ANP (${precoReferenciaAnp.toStringAsFixed(3)})';
  }

  double scoreServicos = 0;
  String detalheServicos = 'Sem dados de serviços';
  if (servicosTotal > 0) {
    scoreServicos = ((servicosAtivos / servicosTotal) * 100).clamp(0, 100);
    detalheServicos = '$servicosAtivos/$servicosTotal serviços';
  }

  const scoreDistancia = 50.0;
  const detalheDistancia = 'Sem ponto de referência';

  final score = 0.5 * scorePreco + 0.3 * scoreServicos + 0.2 * scoreDistancia;
  final grade = score >= 75 ? 'A' : score >= 55 ? 'B' : score >= 35 ? 'C' : 'D';

  return ScorePosto(
    score: (score * 10).round() / 10,
    grade: grade,
    detalhePreco: detalhePreco,
    detalheServicos: detalheServicos,
    detalheDistancia: detalheDistancia,
  );
}

class PrecoPosto {
  final String combustivel;
  final double preco;
  final String? dataRef;
  const PrecoPosto({required this.combustivel, required this.preco, this.dataRef});
}

class PostoComScore {
  final String cnpj;
  final String? razaoSocial;
  final String? municipio;
  final String? uf;
  final String? bandeira;
  final double? lat;
  final double? lon;
  final List<PrecoPosto> precos;
  final ScorePosto score;
  final String origem; // 'proprio' | 'anp'

  const PostoComScore({
    required this.cnpj,
    this.razaoSocial,
    this.municipio,
    this.uf,
    this.bandeira,
    this.lat,
    this.lon,
    required this.precos,
    required this.score,
    required this.origem,
  });
}

class RoteirizacaoService {
  final _supabase = SupabaseService.client;

  int _contarServicos(Map<String, dynamic> p) {
    var n = 0;
    for (final c in _camposServico) {
      if (p[c] == true) n++;
    }
    return n;
  }

  Future<List<Map<String, dynamic>>> _carregarPostosComCoordenadas(
    String empresaId, {
    String? uf,
    String? municipioContem,
  }) async {
    var query = _supabase
        .from('postos_gf')
        .select(
            'cnpj, razao_social, municipio, uf, bandeira, lat, lon, ativo, funciona_24h, pista_caminhao, arla, conveniencia, conveniencia_am_pm, possui_restaurante, possui_banheiro, possui_estacionamento, possui_troca_oleo, possui_internet')
        .eq('empresa_id', empresaId)
        .eq('ativo', true)
        .not('lat', 'is', null)
        .not('lon', 'is', null);
    if (uf != null && uf.isNotEmpty) query = query.eq('uf', uf);
    if (municipioContem != null && municipioContem.isNotEmpty) query = query.ilike('municipio', '%$municipioContem%');
    final rows = await query.limit(5000);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, List<PrecoPosto>>> _carregarPrecosPorCnpj(List<String> cnpjs) async {
    final mapa = <String, List<PrecoPosto>>{};
    if (cnpjs.isEmpty) return mapa;
    final rows = await _supabase
        .from('historico_precos')
        .select('cnpj, combustivel, preco, data_ref')
        .inFilter('cnpj', cnpjs)
        .order('data_ref', ascending: false) as List;

    final vistos = <String>{};
    for (final r in rows) {
      final m = r as Map<String, dynamic>;
      final chave = '${m['cnpj']}__${m['combustivel']}';
      if (vistos.contains(chave)) continue;
      vistos.add(chave);
      final lista = mapa[m['cnpj'] as String] ?? [];
      lista.add(PrecoPosto(
        combustivel: m['combustivel'] as String,
        preco: (m['preco'] as num).toDouble(),
        dataRef: m['data_ref'] as String?,
      ));
      mapa[m['cnpj'] as String] = lista;
    }
    return mapa;
  }

  Future<List<Map<String, dynamic>>> _carregarPostosAnpPorFiltro({String? uf, String? municipioContem}) async {
    var query = _supabase
        .from('anp_postos')
        .select('cnpj, razao_social, municipio, uf, bandeira, latitude, longitude')
        .eq('ativo', true)
        .not('latitude', 'is', null)
        .not('longitude', 'is', null)
        .not('cnpj', 'is', null);
    if (uf != null && uf.isNotEmpty) query = query.eq('uf', uf);
    if (municipioContem != null && municipioContem.isNotEmpty) query = query.ilike('municipio', '%$municipioContem%');
    final rows = await query.limit(6000);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<({Map<String, Map<String, double>> porMunicipio, Map<String, Map<String, double>> porEstado, Map<String, double> brasil})>
      _carregarPrecosAnpEmLote(List<String> estadosAnp) async {
    final porMunicipio = <String, Map<String, double>>{};
    final porEstado = <String, Map<String, double>>{};
    final brasil = <String, double>{};

    if (estadosAnp.isNotEmpty) {
      final municRows = await _supabase
          .from('anp_precos_referencia')
          .select('municipio, estado, produto, preco_medio, data_final')
          .eq('nivel', 'municipio')
          .inFilter('estado', estadosAnp)
          .inFilter('produto', categoriasAnp)
          .order('data_final', ascending: false) as List;
      for (final r in municRows) {
        final m = r as Map<String, dynamic>;
        if (m['preco_medio'] == null) continue;
        final chave = '${m['municipio']}__${m['estado']}';
        final mapa = porMunicipio[chave] ?? {};
        mapa.putIfAbsent(m['produto'] as String, () => (m['preco_medio'] as num).toDouble());
        porMunicipio[chave] = mapa;
      }

      final estRows = await _supabase
          .from('anp_precos_referencia')
          .select('estado, produto, preco_medio, data_final')
          .eq('nivel', 'estado')
          .inFilter('estado', estadosAnp)
          .inFilter('produto', categoriasAnp)
          .order('data_final', ascending: false) as List;
      for (final r in estRows) {
        final m = r as Map<String, dynamic>;
        if (m['preco_medio'] == null) continue;
        final mapa = porEstado[m['estado'] as String] ?? {};
        mapa.putIfAbsent(m['produto'] as String, () => (m['preco_medio'] as num).toDouble());
        porEstado[m['estado'] as String] = mapa;
      }
    }

    final brasilRows = await _supabase
        .from('anp_precos_referencia')
        .select('produto, preco_medio, data_final')
        .eq('nivel', 'brasil')
        .inFilter('produto', categoriasAnp)
        .order('data_final', ascending: false) as List;
    for (final r in brasilRows) {
      final m = r as Map<String, dynamic>;
      if (m['preco_medio'] == null) continue;
      brasil.putIfAbsent(m['produto'] as String, () => (m['preco_medio'] as num).toDouble());
    }

    return (porMunicipio: porMunicipio, porEstado: porEstado, brasil: brasil);
  }

  List<PostoComScore> _montarPostosAnp(
    List<Map<String, dynamic>> postosAnp,
    Set<String> cnpjsJaPresentes,
    ({Map<String, Map<String, double>> porMunicipio, Map<String, Map<String, double>> porEstado, Map<String, double> brasil}) precosAnp,
  ) {
    final resultado = <PostoComScore>[];
    for (final p in postosAnp) {
      final cnpjBruto = p['cnpj'] as String?;
      if (cnpjBruto == null || p['latitude'] == null || p['longitude'] == null) continue;
      final cnpjNorm = cnpjBruto.replaceAll(RegExp(r'\D'), '');
      if (cnpjNorm.isEmpty || cnpjsJaPresentes.contains(cnpjNorm)) continue;
      cnpjsJaPresentes.add(cnpjNorm);

      final uf = p['uf'] as String?;
      final estadoAnp = uf != null ? ufParaEstadoAnp[uf.toUpperCase()] : null;
      final municipioNorm = normalizarTexto(p['municipio'] as String?);
      final mapaMunicipio = estadoAnp != null ? precosAnp.porMunicipio['${municipioNorm}__$estadoAnp'] : null;
      final mapaEstado = estadoAnp != null ? precosAnp.porEstado[estadoAnp] : null;

      final precos = <PrecoPosto>[];
      for (final categoria in categoriasAnp) {
        final achado = mapaMunicipio?[categoria] ?? mapaEstado?[categoria] ?? precosAnp.brasil[categoria];
        if (achado != null) precos.add(PrecoPosto(combustivel: categoria, preco: achado));
      }
      final precoMedio = precos.isEmpty ? null : precos.map((e) => e.preco).reduce((a, b) => a + b) / precos.length;

      resultado.add(PostoComScore(
        cnpj: cnpjNorm,
        razaoSocial: p['razao_social'] as String?,
        municipio: p['municipio'] as String?,
        uf: uf,
        bandeira: p['bandeira'] as String?,
        lat: (p['latitude'] as num).toDouble(),
        lon: (p['longitude'] as num).toDouble(),
        precos: precos,
        score: calcularScorePosto(precoPosto: precoMedio, servicosAtivos: 0, servicosTotal: _camposServico.length),
        origem: 'anp',
      ));
    }
    return resultado;
  }

  List<String> _estadosAnpDePostos(List<Map<String, dynamic>> postos, {String Function(Map<String, dynamic>)? ufKey}) {
    final set = <String>{};
    for (final p in postos) {
      final uf = (ufKey != null ? ufKey(p) : p['uf']) as String?;
      if (uf == null) continue;
      final estado = ufParaEstadoAnp[uf.toUpperCase()];
      if (estado != null) set.add(estado);
    }
    return set.toList();
  }

  // ── Modo "Por UF/Município" ──────────────────────────────────────────
  Future<List<PostoComScore>> buscarPostosPorUf({required String empresaId, String? uf, String? municipio}) async {
    final postos = await _carregarPostosComCoordenadas(empresaId, uf: uf, municipioContem: municipio);
    final precosPorCnpj = await _carregarPrecosPorCnpj(postos.map((p) => p['cnpj'] as String).toList());

    final resultadoGf = postos.map((p) {
      final precos = precosPorCnpj[p['cnpj']] ?? <PrecoPosto>[];
      final precoMedio = precos.isEmpty ? null : precos.map((e) => e.preco).reduce((a, b) => a + b) / precos.length;
      return PostoComScore(
        cnpj: p['cnpj'] as String,
        razaoSocial: p['razao_social'] as String?,
        municipio: p['municipio'] as String?,
        uf: p['uf'] as String?,
        bandeira: p['bandeira'] as String?,
        lat: (p['lat'] as num?)?.toDouble(),
        lon: (p['lon'] as num?)?.toDouble(),
        precos: precos,
        score: calcularScorePosto(precoPosto: precoMedio, servicosAtivos: _contarServicos(p), servicosTotal: _camposServico.length),
        origem: 'proprio',
      );
    }).toList();

    if ((uf != null && uf.isNotEmpty) || (municipio != null && municipio.isNotEmpty)) {
      final cnpjsJaPresentes = resultadoGf.map((p) => p.cnpj.replaceAll(RegExp(r'\D'), '')).toSet();
      final postosAnpBrutos = await _carregarPostosAnpPorFiltro(uf: uf, municipioContem: municipio);
      final estadosAnp = _estadosAnpDePostos(postosAnpBrutos);
      final precosAnp = await _carregarPrecosAnpEmLote(estadosAnp);
      final resultadoAnp = _montarPostosAnp(postosAnpBrutos, cnpjsJaPresentes, precosAnp);
      return [...resultadoGf, ...resultadoAnp];
    }

    return resultadoGf;
  }

  // ── Modo "Consulta por Posto" ────────────────────────────────────────
  Future<List<PostoComScore>> buscarPostoPorTermo({required String empresaId, required String termo}) async {
    final termoDigitos = termo.replaceAll(RegExp(r'\D'), '');
    final ehCnpj = termoDigitos.length >= 11;

    var query = _supabase
        .from('postos_gf')
        .select(
            'cnpj, razao_social, municipio, uf, bandeira, lat, lon, funciona_24h, pista_caminhao, arla, conveniencia, conveniencia_am_pm, possui_restaurante, possui_banheiro, possui_estacionamento, possui_troca_oleo, possui_internet')
        .eq('empresa_id', empresaId)
        .not('lat', 'is', null)
        .not('lon', 'is', null);
    query = ehCnpj ? query.ilike('cnpj', '%$termoDigitos%') : query.ilike('razao_social', '%$termo%');
    final postos = ((await query.limit(30)) as List).cast<Map<String, dynamic>>();

    final precosPorCnpj = await _carregarPrecosPorCnpj(postos.map((p) => p['cnpj'] as String).toList());
    final resultadoGf = postos.map((p) {
      final precos = precosPorCnpj[p['cnpj']] ?? <PrecoPosto>[];
      final precoMedio = precos.isEmpty ? null : precos.map((e) => e.preco).reduce((a, b) => a + b) / precos.length;
      return PostoComScore(
        cnpj: p['cnpj'] as String,
        razaoSocial: p['razao_social'] as String?,
        municipio: p['municipio'] as String?,
        uf: p['uf'] as String?,
        bandeira: p['bandeira'] as String?,
        lat: (p['lat'] as num?)?.toDouble(),
        lon: (p['lon'] as num?)?.toDouble(),
        precos: precos,
        score: calcularScorePosto(precoPosto: precoMedio, servicosAtivos: _contarServicos(p), servicosTotal: _camposServico.length),
        origem: 'proprio',
      );
    }).toList();

    var queryAnp = _supabase
        .from('anp_postos')
        .select('cnpj, razao_social, municipio, uf, bandeira, latitude, longitude')
        .eq('ativo', true)
        .not('latitude', 'is', null)
        .not('longitude', 'is', null)
        .not('cnpj', 'is', null);
    queryAnp = ehCnpj ? queryAnp.ilike('cnpj', '%$termoDigitos%') : queryAnp.ilike('razao_social', '%$termo%');
    final postosAnpBrutos = ((await queryAnp.limit(30)) as List).cast<Map<String, dynamic>>();

    final cnpjsJaPresentes = resultadoGf.map((p) => p.cnpj.replaceAll(RegExp(r'\D'), '')).toSet();
    final estadosAnp = _estadosAnpDePostos(postosAnpBrutos);
    final precosAnp = await _carregarPrecosAnpEmLote(estadosAnp);
    final resultadoAnp = _montarPostosAnp(postosAnpBrutos, cnpjsJaPresentes, precosAnp);

    return [...resultadoGf, ...resultadoAnp];
  }

  // ── Modo "Roteirizador Inteligente" ────────────────────────────────
  Future<List<Map<String, dynamic>>> _carregarPostosGfPorBoxes(String empresaId, List<geo.BoundingBox> boxes) async {
    final porCnpj = <String, Map<String, dynamic>>{};
    for (final box in boxes) {
      final rows = await _supabase
          .from('postos_gf')
          .select(
              'cnpj, razao_social, municipio, uf, bandeira, lat, lon, ativo, funciona_24h, pista_caminhao, arla, conveniencia, conveniencia_am_pm, possui_restaurante, possui_banheiro, possui_estacionamento, possui_troca_oleo, possui_internet')
          .eq('empresa_id', empresaId)
          .eq('ativo', true)
          .not('lat', 'is', null)
          .not('lon', 'is', null)
          .gte('lat', box.minLat)
          .lte('lat', box.maxLat)
          .gte('lon', box.minLon)
          .lte('lon', box.maxLon)
          .limit(3000) as List;
      for (final r in rows) {
        final m = r as Map<String, dynamic>;
        porCnpj[m['cnpj'] as String] = m;
      }
    }
    return porCnpj.values.toList();
  }

  Future<List<Map<String, dynamic>>> _carregarAnpPostosPorBoxes(List<geo.BoundingBox> boxes) async {
    final porCnpj = <String, Map<String, dynamic>>{};
    for (final box in boxes) {
      final rows = await _supabase
          .from('anp_postos')
          .select('cnpj, razao_social, municipio, uf, bandeira, latitude, longitude')
          .eq('ativo', true)
          .not('latitude', 'is', null)
          .not('longitude', 'is', null)
          .gte('latitude', box.minLat)
          .lte('latitude', box.maxLat)
          .gte('longitude', box.minLon)
          .lte('longitude', box.maxLon)
          .limit(3000) as List;
      for (final r in rows) {
        final m = r as Map<String, dynamic>;
        final cnpj = m['cnpj'] as String?;
        if (cnpj == null) continue;
        porCnpj[cnpj] = m;
      }
    }
    return porCnpj.values.toList();
  }

  // Porta de calcularRoteirizacaoAcao (actions.ts) — só a parte de busca de
  // candidatos + otimização da estratégia ESCOLHIDA (sem o comparativo das
  // 4 estratégias de uma vez, ver escopo no comentário do topo do arquivo).
  Future<ResultadoRoteirizacaoInteligente> calcularRoteirizacao({
    required String empresaId,
    required geo.Ponto origem,
    required geo.Ponto destino,
    List<geo.Ponto> paradas = const [],
    required double capacidadeTanqueL,
    required double autonomiaKmPorL,
    required String combustivel,
    double? combustivelInicialL,
    required PerfilPeso perfil,
  }) async {
    const raioCorredorKm = 5.0;
    final rota = await geo.calcularRotaOsrm(origem, destino, paradas: paradas);
    final acumuladas = geo.distanciasAcumuladas(rota.coordenadas);
    final margem = raioCorredorKm / 100;
    final boxesRota = geo.construirBoundingBoxesDaRota(rota.coordenadas, acumuladas, margem);

    final postosBrutos = await _carregarPostosGfPorBoxes(empresaId, boxesRota);
    final candidatosBrutosGf = postosBrutos
        .map((p) {
          final pos = geo.posicaoNaRotaKm(geo.Ponto((p['lat'] as num).toDouble(), (p['lon'] as num).toDouble()),
              rota.coordenadas, acumuladas);
          return (p: p, km: pos.km, desvioKm: pos.desvioKm);
        })
        .where((x) => x.desvioKm <= raioCorredorKm)
        .toList();

    final precosPorCnpj =
        await _carregarPrecosPorCnpj(candidatosBrutosGf.map((x) => x.p['cnpj'] as String).toList());

    var candidatos = <CandidatoAbastecimento>[];
    for (final x in candidatosBrutosGf) {
      final precoRegistrado = (precosPorCnpj[x.p['cnpj']] ?? [])
          .where((pr) => pr.combustivel.toLowerCase() == combustivel.toLowerCase())
          .toList();
      if (precoRegistrado.isEmpty) continue;
      final score =
          calcularScorePosto(precoPosto: precoRegistrado.first.preco, servicosAtivos: _contarServicos(x.p), servicosTotal: _camposServico.length);
      candidatos.add(CandidatoAbastecimento(
        cnpj: x.p['cnpj'] as String,
        km: x.km,
        desvioKm: x.desvioKm,
        preco: precoRegistrado.first.preco,
        grade: score.grade,
        label: x.p['razao_social'] as String? ?? x.p['cnpj'] as String,
        lat: (x.p['lat'] as num).toDouble(),
        lon: (x.p['lon'] as num).toDouble(),
        bandeira: x.p['bandeira'] as String?,
        uf: x.p['uf'] as String?,
        origem: 'proprio',
      ));
    }

    // Fallback/complemento ANP no corredor — mesma cascata de preço
    // (município → estado → Brasil) usada nos outros 2 modos, só que
    // aplicada aos candidatos do corredor da rota.
    var usouFallbackAnp = false;
    final categoriaAnp = produtoParaCategoriaAnp[combustivel];
    if (categoriaAnp != null) {
      final cnpjsProprios = candidatos.map((c) => c.cnpj.replaceAll(RegExp(r'\D'), '')).toSet();
      final anpBrutos = await _carregarAnpPostosPorBoxes(boxesRota);
      final anpNoCorredor = anpBrutos
          .where((p) => !cnpjsProprios.contains((p['cnpj'] as String).replaceAll(RegExp(r'\D'), '')))
          .map((p) {
            final pos = geo.posicaoNaRotaKm(
                geo.Ponto((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble()),
                rota.coordenadas,
                acumuladas);
            return (p: p, km: pos.km, desvioKm: pos.desvioKm);
          })
          .where((x) => x.desvioKm <= raioCorredorKm)
          .toList();

      final estadosNoCorredor = _estadosAnpDePostos(anpNoCorredor.map((x) => x.p).toList());
      final precoPorMunicipio = <String, double>{};
      final precoPorEstado = <String, double>{};
      double? precoBrasil;

      if (estadosNoCorredor.isNotEmpty) {
        final municRows = await _supabase
            .from('anp_precos_referencia')
            .select('municipio, estado, preco_medio, data_final')
            .eq('nivel', 'municipio')
            .eq('produto', categoriaAnp)
            .inFilter('estado', estadosNoCorredor)
            .order('data_final', ascending: false) as List;
        for (final r in municRows) {
          final m = r as Map<String, dynamic>;
          final chave = '${m['municipio']}__${m['estado']}';
          if (!precoPorMunicipio.containsKey(chave) && m['preco_medio'] != null) {
            precoPorMunicipio[chave] = (m['preco_medio'] as num).toDouble();
          }
        }
        final estRows = await _supabase
            .from('anp_precos_referencia')
            .select('estado, preco_medio, data_final')
            .eq('nivel', 'estado')
            .eq('produto', categoriaAnp)
            .inFilter('estado', estadosNoCorredor)
            .order('data_final', ascending: false) as List;
        for (final r in estRows) {
          final m = r as Map<String, dynamic>;
          if (!precoPorEstado.containsKey(m['estado']) && m['preco_medio'] != null) {
            precoPorEstado[m['estado'] as String] = (m['preco_medio'] as num).toDouble();
          }
        }
      }
      final brasilRow = await _supabase
          .from('anp_precos_referencia')
          .select('preco_medio')
          .eq('nivel', 'brasil')
          .eq('produto', categoriaAnp)
          .order('data_final', ascending: false)
          .limit(1)
          .maybeSingle();
      precoBrasil = (brasilRow?['preco_medio'] as num?)?.toDouble();

      final candidatosAnp = <CandidatoAbastecimento>[];
      for (final x in anpNoCorredor) {
        final uf = x.p['uf'] as String?;
        final estadoAnp = uf != null ? ufParaEstadoAnp[uf.toUpperCase()] : null;
        final municipioNorm = normalizarTexto(x.p['municipio'] as String?);
        final preco = (estadoAnp != null ? precoPorMunicipio['${municipioNorm}__$estadoAnp'] : null) ??
            (estadoAnp != null ? precoPorEstado[estadoAnp] : null) ??
            precoBrasil;
        if (preco == null) continue;
        final score = calcularScorePosto(precoPosto: preco, servicosAtivos: 0, servicosTotal: _camposServico.length);
        candidatosAnp.add(CandidatoAbastecimento(
          cnpj: x.p['cnpj'] as String,
          km: x.km,
          desvioKm: x.desvioKm,
          preco: preco,
          grade: score.grade,
          label: x.p['razao_social'] as String? ?? x.p['cnpj'] as String,
          lat: (x.p['latitude'] as num).toDouble(),
          lon: (x.p['longitude'] as num).toDouble(),
          bandeira: x.p['bandeira'] as String?,
          uf: uf,
          origem: 'anp',
        ));
      }
      candidatos = [...candidatos, ...candidatosAnp];
      usouFallbackAnp = candidatosAnp.isNotEmpty;
    }

    final paradas2 = otimizarAbastecimento(
      candidatos: candidatos,
      capacidadeTanqueL: capacidadeTanqueL,
      autonomiaKmPorL: autonomiaKmPorL,
      distanciaTotalRotaKm: rota.distanciaKm,
      pesos: perfil.pesos,
      fillMode: perfil.fillMode,
      combustivelInicialL: combustivelInicialL,
    );

    return ResultadoRoteirizacaoInteligente(
      coordenadas: rota.coordenadas,
      distanciaKm: (rota.distanciaKm * 10).round() / 10,
      duracaoMin: rota.duracaoMin.round().toDouble(),
      linhaReta: rota.linhaReta,
      paradas: paradas2,
      litrosTotal: paradas2.fold(0.0, (s, p) => s + p.litrosSugeridos),
      custoTotal: ((paradas2.fold(0.0, (s, p) => s + p.custoAbastecimento)) * 100).round() / 100,
      candidatosEncontrados: candidatos.length,
      usouFallbackAnp: usouFallbackAnp,
    );
  }
}

class ResultadoRoteirizacaoInteligente {
  final List<geo.Ponto> coordenadas;
  final double distanciaKm;
  final double duracaoMin;
  final bool linhaReta;
  final List<ParadaSugerida> paradas;
  final double litrosTotal;
  final double custoTotal;
  final int candidatosEncontrados;
  final bool usouFallbackAnp;
  const ResultadoRoteirizacaoInteligente({
    required this.coordenadas,
    required this.distanciaKm,
    required this.duracaoMin,
    required this.linhaReta,
    required this.paradas,
    required this.litrosTotal,
    required this.custoTotal,
    required this.candidatosEncontrados,
    required this.usouFallbackAnp,
  });
}

// Porta de PRODUTO_PARA_CATEGORIA_ANP (src/lib/constants.ts) — combustível
// do veículo -> categoria oficial ANP, usado só no Roteirizador Inteligente
// (os outros 2 modos não filtram por combustível específico do veículo).
const produtoParaCategoriaAnp = {
  'Diesel S-500 Comum': 'OLEO DIESEL',
  'Diesel S-500 Aditivado': 'OLEO DIESEL',
  'Diesel S-10 Comum': 'OLEO DIESEL S10',
  'Diesel S-10 Aditivado': 'OLEO DIESEL S10',
  'Etanol Comum': 'ETANOL HIDRATADO',
  'Etanol Aditivado': 'ETANOL HIDRATADO',
  'Gasolina Comum': 'GASOLINA COMUM',
  'Gasolina Aditivada': 'GASOLINA ADITIVADA',
  'Gasolina Alta Octanagem': 'GASOLINA ADITIVADA',
  'GNV': 'GNV',
  'GLP': 'GLP',
};

// Reexportado pra tela não precisar importar postos_provider.dart só por
// causa da lista de UFs.
const ufsRoteirizacao = ufsBrasil;
