import 'dart:math' as math;
import 'package:dio/dio.dart';

// Fase FLT-3 — porta fiel de src/lib/geo.ts. Usa os mesmos 2 serviços
// públicos e gratuitos (sem chave de API) que a web: Nominatim
// (geocodificação de texto livre) e OSRM (cálculo de rota rodoviária).

class Ponto {
  final double lat;
  final double lon;
  const Ponto(this.lat, this.lon);
}

const _raioTerraKm = 6371.0;

double haversineKm(Ponto a, Ponto b) {
  final dLat = (b.lat - a.lat) * math.pi / 180;
  final dLon = (b.lon - a.lon) * math.pi / 180;
  final lat1 = a.lat * math.pi / 180;
  final lat2 = b.lat * math.pi / 180;
  final h = math.pow(math.sin(dLat / 2), 2) + math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
  return _raioTerraKm * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

Ponto _projetarPontoNoSegmento(Ponto ponto, Ponto a, Ponto b) {
  final dx = b.lon - a.lon;
  final dy = b.lat - a.lat;
  final comprimento2 = dx * dx + dy * dy;
  if (comprimento2 == 0) return a;
  var t = ((ponto.lon - a.lon) * dx + (ponto.lat - a.lat) * dy) / comprimento2;
  t = t.clamp(0, 1);
  return Ponto(a.lat + t * dy, a.lon + t * dx);
}

({double km, double desvioKm}) posicaoNaRotaKm(Ponto ponto, List<Ponto> rota, List<double> acumuladas) {
  if (rota.isEmpty) return (km: 0, desvioKm: double.infinity);
  var melhorDist = double.infinity;
  var melhorKm = 0.0;
  for (var i = 0; i < rota.length - 1; i++) {
    final a = rota[i];
    final b = rota[i + 1];
    final proj = _projetarPontoNoSegmento(ponto, a, b);
    final d = haversineKm(ponto, proj);
    if (d < melhorDist) {
      melhorDist = d;
      final distSegmento = haversineKm(a, b);
      final distAteProjecao = haversineKm(a, proj);
      final fracao = distSegmento > 0 ? distAteProjecao / distSegmento : 0;
      melhorKm = acumuladas[i] + fracao * (acumuladas[i + 1] - acumuladas[i]);
    }
  }
  return (km: melhorKm, desvioKm: melhorDist);
}

List<double> distanciasAcumuladas(List<Ponto> rota) {
  final acc = <double>[0];
  for (var i = 1; i < rota.length; i++) {
    acc.add(acc[i - 1] + haversineKm(rota[i - 1], rota[i]));
  }
  return acc;
}

class BoundingBox {
  final double minLat, maxLat, minLon, maxLon;
  const BoundingBox({required this.minLat, required this.maxLat, required this.minLon, required this.maxLon});
}

// Fase 27.21 na web — divide a rota em pedaços de até `passoKm` (capado a
// `maxSegmentos`) em vez de um bounding box único cobrindo a rota inteira,
// pra não esbarrar em `.limit()` nas consultas ao banco numa rota longa.
List<BoundingBox> construirBoundingBoxesDaRota(
  List<Ponto> rota,
  List<double> acumuladas,
  double margemGraus, {
  double passoKm = 150,
  int maxSegmentos = 20,
}) {
  if (rota.isEmpty) return [];
  final totalKm = acumuladas.isEmpty ? 0.0 : acumuladas.last;
  final passoEfetivoKm = math.max(passoKm, totalKm / maxSegmentos);

  final boxes = <BoundingBox>[];
  var inicioIdx = 0;
  var inicioKm = 0.0;
  for (var i = 1; i < rota.length; i++) {
    final ultimoPonto = i == rota.length - 1;
    if (acumuladas[i] - inicioKm >= passoEfetivoKm || ultimoPonto) {
      final fatia = rota.sublist(inicioIdx, i + 1);
      final lats = fatia.map((p) => p.lat);
      final lons = fatia.map((p) => p.lon);
      boxes.add(BoundingBox(
        minLat: lats.reduce(math.min) - margemGraus,
        maxLat: lats.reduce(math.max) + margemGraus,
        minLon: lons.reduce(math.min) - margemGraus,
        maxLon: lons.reduce(math.max) + margemGraus,
      ));
      inicioIdx = i;
      inicioKm = acumuladas[i];
    }
  }
  return boxes;
}

class SugestaoGeocoding {
  final String label;
  final double lat;
  final double lon;
  const SugestaoGeocoding({required this.label, required this.lat, required this.lon});
}

final _dio = Dio();

// Porta de geocodificar() — busca de local por texto livre via Nominatim.
Future<List<SugestaoGeocoding>> geocodificar(String texto) async {
  final termo = texto.trim();
  if (termo.length < 3) return [];
  try {
    final resp = await _dio.get(
      'https://nominatim.openstreetmap.org/search',
      queryParameters: {
        'q': '$termo, Brasil',
        'format': 'json',
        'limit': '6',
        'countrycodes': 'br',
        'addressdetails': '1',
      },
      options: Options(
        headers: {'User-Agent': 'FNI-GestaoDeFrotas-Flutter/1.0 (contato: d.peruffo@gmail.com)'},
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    final itens = (resp.data as List?) ?? [];
    final vistos = <String>{};
    final opcoes = <SugestaoGeocoding>[];
    for (final item in itens) {
      final m = item as Map<String, dynamic>;
      final addr = (m['address'] as Map<String, dynamic>?) ?? {};
      final cidade = (addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['municipality'] ?? addr['county'] ?? '') as String;
      final estado = (addr['state'] ?? '') as String;
      final label = cidade.isNotEmpty && estado.isNotEmpty
          ? '$cidade – $estado'
          : (estado.isNotEmpty ? estado : (m['display_name'] as String? ?? '').split(', ').take(2).join(', '));
      if (!vistos.contains(label) && label.isNotEmpty) {
        vistos.add(label);
        opcoes.add(SugestaoGeocoding(
          label: label,
          lat: double.parse(m['lat'] as String),
          lon: double.parse(m['lon'] as String),
        ));
      }
    }
    return opcoes;
  } catch (_) {
    return [];
  }
}

class ResultadoRota {
  final List<Ponto> coordenadas;
  final double distanciaKm;
  final double duracaoMin;
  final bool linhaReta;
  const ResultadoRota({
    required this.coordenadas,
    required this.distanciaKm,
    required this.duracaoMin,
    required this.linhaReta,
  });
}

const _osrmServidores = [
  'https://router.project-osrm.org/route/v1/driving',
  'https://routing.openstreetmap.de/routed-car/route/v1/driving',
];

// Porta de calcularRotaOsrm() — mesmos servidores públicos OSRM tentados em
// sequência, com fallback para linha reta se os dois falharem (garante que
// a funcionalidade não trave por indisponibilidade do serviço externo).
Future<ResultadoRota> calcularRotaOsrm(Ponto origem, Ponto destino, {List<Ponto> paradas = const []}) async {
  final pontos = [origem, ...paradas, destino];
  final coordsStr = pontos.map((p) => '${p.lon},${p.lat}').join(';');

  for (final servidor in _osrmServidores) {
    try {
      final url = '$servidor/$coordsStr';
      final resp = await _dio.get(
        url,
        queryParameters: {'overview': 'full', 'geometries': 'geojson'},
        options: Options(sendTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 10)),
      );
      final rota = (resp.data['routes'] as List?)?.firstOrNull as Map<String, dynamic>?;
      if (rota == null) continue;
      final coords = (rota['geometry']['coordinates'] as List)
          .map((c) => Ponto((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      return ResultadoRota(
        coordenadas: coords,
        distanciaKm: (rota['distance'] as num) / 1000,
        duracaoMin: (rota['duration'] as num) / 60,
        linhaReta: false,
      );
    } catch (_) {
      continue;
    }
  }

  // Fallback: segmentos de linha reta entre os pontos informados.
  final coordenadas = <Ponto>[];
  const segmentosPorTrecho = 12;
  for (var i = 0; i < pontos.length - 1; i++) {
    final a = pontos[i];
    final b = pontos[i + 1];
    for (var j = 0; j < segmentosPorTrecho; j++) {
      final t = j / segmentosPorTrecho;
      coordenadas.add(Ponto(a.lat + (b.lat - a.lat) * t, a.lon + (b.lon - a.lon) * t));
    }
  }
  coordenadas.add(pontos.last);
  var distanciaKm = 0.0;
  for (var i = 0; i < pontos.length - 1; i++) {
    distanciaKm += haversineKm(pontos[i], pontos[i + 1]);
  }
  return ResultadoRota(
    coordenadas: coordenadas,
    distanciaKm: distanciaKm,
    duracaoMin: (distanciaKm / 80) * 60,
    linhaReta: true,
  );
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
