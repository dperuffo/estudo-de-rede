import '../../../core/services/supabase_service.dart';
import '../../postos/providers/postos_provider.dart' show ufsBrasil;

// Fase FLT-3 — Roteirização (cliente), porta PARCIAL de roteirizacao/
// page.tsx + posto/page.tsx + actions.ts (funções buscarPostosPorUfAcao +
// buscarPostoPorTermoAcao). RLS/tabelas conferidas antes de portar:
// `postos_gf`/`historico_precos` têm self-service completo pra empresa do
// usuário (já usado em Postos Revendedores); `anp_postos`/
// `anp_precos_referencia` têm leitura PÚBLICA (`qual: true`, sem
// tenant-scoping) — dá pra consultar direto, sem RPC, igual à web.
//
// Escopo reduzido — a web tem 4 abas em Roteirização; só as 2 mais simples
// entraram no v1 mobile:
//   - "Por UF/Município" (esta tela, modo 'uf')
//   - "Consulta por Posto" (esta tela, modo 'posto')
// Fora do escopo: "Roteirizador Inteligente" (calcula rota real via OSRM,
// otimiza paradas de abastecimento por veículo/perfil de peso, compara 4
// estratégias, exporta GPX/PDF/PNG — muita lógica geo-espacial e
// dependência de mapa interativo, natural pra próxima fase) e "Rotas
// Salvas" (persistência de consultas — só faz sentido depois que o
// Roteirizador existir). Sem mapa interativo aqui: os resultados aparecem
// como lista (cada posto já mostra município/UF, o mapa da web é só uma
// visualização a mais dos mesmos dados).
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
}

// Reexportado pra tela não precisar importar postos_provider.dart só por
// causa da lista de UFs.
const ufsRoteirizacao = ufsBrasil;
