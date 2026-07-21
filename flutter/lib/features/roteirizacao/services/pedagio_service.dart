import '../../../core/services/supabase_service.dart';
import 'geo_service.dart' as geo;

// Fase FLT-Pedagios — porta fiel de src/lib/pedagio.ts. Pedido do Daniel:
// "estes dois últimos desenvolvimentos precisam estar no PWA Cliente"
// (Base de Pedágios + Parâmetros de NF). Consulta a tabela `pracas_pedagio`
// (leitura pública pra qualquer autenticado, RLS já conferida na web) no
// corredor de uma rota já calculada, reaproveitando os mesmos helpers de
// geo_service.dart usados pros postos (construirBoundingBoxesDaRota +
// posicaoNaRotaKm).
class PracaPedagio {
  final int id;
  final String nome;
  final String? concessionaria;
  final String? rodovia;
  final String? uf;
  final double lat;
  final double lon;
  final double? valorCarro;
  final double? valorMoto;
  final double? valorCaminhaoEixo;

  const PracaPedagio({
    required this.id,
    required this.nome,
    this.concessionaria,
    this.rodovia,
    this.uf,
    required this.lat,
    required this.lon,
    this.valorCarro,
    this.valorMoto,
    this.valorCaminhaoEixo,
  });

  factory PracaPedagio.fromMap(Map<String, dynamic> m) => PracaPedagio(
        id: m['id'] as int,
        nome: m['nome'] as String,
        concessionaria: m['concessionaria'] as String?,
        rodovia: m['rodovia'] as String?,
        uf: m['uf'] as String?,
        lat: (m['lat'] as num).toDouble(),
        lon: (m['lon'] as num).toDouble(),
        valorCarro: (m['valor_carro'] as num?)?.toDouble(),
        valorMoto: (m['valor_moto'] as num?)?.toDouble(),
        valorCaminhaoEixo: (m['valor_caminhao_eixo'] as num?)?.toDouble(),
      );
}

class PracaPedagioNaRota extends PracaPedagio {
  final double kmNaRota;
  final double desvioKm;
  const PracaPedagioNaRota({
    required super.id,
    required super.nome,
    super.concessionaria,
    super.rodovia,
    super.uf,
    required super.lat,
    required super.lon,
    super.valorCarro,
    super.valorMoto,
    super.valorCaminhaoEixo,
    required this.kmNaRota,
    required this.desvioKm,
  });
}

// Categoria simplificada de veículo pra escolher qual valor de tarifa usar
// — mesmo racional de CategoriaVeiculoPedagio na web.
enum CategoriaVeiculoPedagio { carro, moto, caminhao }

const _raioCorredorPadraoKm = 3.0;

Future<List<PracaPedagioNaRota>> buscarPracasPedagioNaRota(
  List<geo.Ponto> rota,
  List<double> acumuladas, {
  double raioKm = _raioCorredorPadraoKm,
}) async {
  if (rota.isEmpty) return [];
  final margemGraus = raioKm / 100;
  final boxes = geo.construirBoundingBoxesDaRota(rota, acumuladas, margemGraus);
  if (boxes.isEmpty) return [];

  final supabase = SupabaseService.client;
  final porId = <int, Map<String, dynamic>>{};
  for (final box in boxes) {
    final rows = await supabase
        .from('pracas_pedagio')
        .select('id, nome, concessionaria, rodovia, uf, lat, lon, valor_carro, valor_moto, valor_caminhao_eixo')
        .gte('lat', box.minLat)
        .lte('lat', box.maxLat)
        .gte('lon', box.minLon)
        .lte('lon', box.maxLon)
        .limit(500) as List;
    for (final r in rows) {
      final m = r as Map<String, dynamic>;
      porId[m['id'] as int] = m;
    }
  }

  final resultado = <PracaPedagioNaRota>[];
  for (final m in porId.values) {
    final praca = PracaPedagio.fromMap(m);
    final pos = geo.posicaoNaRotaKm(geo.Ponto(praca.lat, praca.lon), rota, acumuladas);
    if (pos.desvioKm > raioKm) continue;
    resultado.add(PracaPedagioNaRota(
      id: praca.id,
      nome: praca.nome,
      concessionaria: praca.concessionaria,
      rodovia: praca.rodovia,
      uf: praca.uf,
      lat: praca.lat,
      lon: praca.lon,
      valorCarro: praca.valorCarro,
      valorMoto: praca.valorMoto,
      valorCaminhaoEixo: praca.valorCaminhaoEixo,
      kmNaRota: pos.km,
      desvioKm: pos.desvioKm,
    ));
  }
  resultado.sort((a, b) => a.kmNaRota.compareTo(b.kmNaRota));
  return resultado;
}

double? valorPedagio(PracaPedagio praca, CategoriaVeiculoPedagio categoria, {int numEixos = 2}) {
  switch (categoria) {
    case CategoriaVeiculoPedagio.moto:
      return praca.valorMoto;
    case CategoriaVeiculoPedagio.caminhao:
      return praca.valorCaminhaoEixo != null ? praca.valorCaminhaoEixo! * numEixos : null;
    case CategoriaVeiculoPedagio.carro:
      return praca.valorCarro;
  }
}

double custoPedagioTotal(List<PracaPedagio> pracas, CategoriaVeiculoPedagio categoria, {int numEixos = 2}) {
  var soma = 0.0;
  for (final p in pracas) {
    soma += valorPedagio(p, categoria, numEixos: numEixos) ?? 0;
  }
  return soma;
}

// Fase FLT-Pedagios — porta de buscarPracasPedagioPorNomeAcao
// (planos-viagem/actions.ts): autocomplete por nome/rodovia/concessionária,
// usado no campo "Nome da praça" de Planos de Viagem (plano_viagem_form.dart)
// pra preencher o valor automaticamente em vez de digitação livre.
Future<List<PracaPedagio>> buscarPracasPedagioPorNome(String termo) async {
  final t = termo.trim();
  if (t.length < 2) return [];
  final rows = await SupabaseService.client
      .from('pracas_pedagio')
      .select('id, nome, concessionaria, rodovia, uf, lat, lon, valor_carro, valor_moto, valor_caminhao_eixo')
      .or('nome.ilike.%$t%,rodovia.ilike.%$t%,concessionaria.ilike.%$t%')
      .limit(10) as List;
  return rows.map((r) => PracaPedagio.fromMap(r as Map<String, dynamic>)).toList();
}
