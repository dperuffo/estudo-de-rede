import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../providers/roteirizacao_provider.dart';
import '../services/geo_service.dart' as geo;
import '../services/roteirizacao_algoritmo.dart' show ParadaSugerida;

// Paleta fixa pras bandeiras "demais" (fora Ipiranga/Shell+Raízen/BR+
// Vibra, que têm cor própria pedida pelo Daniel) — escolhida por hash do
// nome normalizado da bandeira, sempre a mesma cor pra mesma bandeira em
// qualquer consulta/tela, sem precisar de uma lista fixa de bandeiras
// cadastrada em código (a base de postos tem bandeiras variadas demais
// pra isso).
const _paletaOutrasBandeiras = [
  Color(0xFF1E88E5), // azul
  Color(0xFF8E24AA), // roxo
  Color(0xFF00897B), // teal
  Color(0xFF6D4C41), // marrom
  Color(0xFFD81B60), // rosa
  Color(0xFF3949AB), // índigo
  Color(0xFF00ACC1), // ciano
  Color(0xFFF4511E), // laranja escuro
  Color(0xFF7CB342), // verde oliva
  Color(0xFF546E7A), // azul acinzentado
];

bool _contemPalavra(String texto, String palavra) => RegExp('\\b$palavra\\b').hasMatch(texto);

// Pedido do Daniel: "diferenciar as cores das bolinhas por bandeira" —
// padrão fixo Ipiranga/amarela, Shell e Raízen/vermelha, BR/Vibra (mesma
// distribuidora, trocou de nome)/verde; demais bandeiras (Alesat, Ale,
// bandeira branca etc.) ganham uma cor fixa da paleta acima, sempre a
// mesma pra mesma bandeira (hash do nome normalizado) — dá pra usar a
// mesma função tanto nas bolinhas do mapa quanto na legenda e no filtro
// por bandeira da tela de consulta.
Color corBandeira(String? bandeira) {
  final norm = normalizarTexto(bandeira);
  if (norm.isEmpty) return Colors.grey.shade500;
  if (_contemPalavra(norm, 'IPIRANGA')) return const Color(0xFFFBC02D); // amarela
  if (_contemPalavra(norm, 'SHELL') || _contemPalavra(norm, 'RAIZEN')) return const Color(0xFFE53935); // vermelha
  if (_contemPalavra(norm, 'BR') || _contemPalavra(norm, 'VIBRA') || _contemPalavra(norm, 'PETROBRAS')) {
    return const Color(0xFF43A047); // verde
  }
  final idx = norm.hashCode.abs() % _paletaOutrasBandeiras.length;
  return _paletaOutrasBandeiras[idx];
}

// Rótulo de exibição pra bandeira nula/vazia — usado igual no mapa, na
// legenda e no filtro, pra bater o mesmo texto nos 3 lugares.
String rotuloBandeira(String? bandeira) => (bandeira == null || bandeira.trim().isEmpty) ? 'Sem bandeira' : bandeira.trim();

// Fase FLT-3 — mapa interativo (pedido do Daniel: "integrar mapas OSM na
// interface do PWA com os postos plotados nos mapas nas consultas
// realizadas por município/UF, posto ou roteirização inteligente").
// Equivalente Flutter do Leaflet usado na web (MapaRota.tsx) — mesma fonte
// de tiles OpenStreetMap, gratuita e sem chave de API. Widget único
// reutilizado nos 3 modos da tela de Roteirização.
// Fase FLT-4 (hotfix, pedido do Daniel) — bolinhas coloridas por
// BANDEIRA em vez de por score/grade (ver corBandeira acima), com
// legenda dinâmica das bandeiras presentes no resultado atual.
class MapaPostos extends StatelessWidget {
  final List<PostoComScore> postos;
  final List<geo.Ponto>? rota; // só preenchido no modo "planejar"
  final List<ParadaSugerida>? paradas; // idem
  final double height;

  const MapaPostos({
    super.key,
    required this.postos,
    this.rota,
    this.paradas,
    this.height = 280,
  });

  // Legenda dinâmica: só lista as bandeiras que realmente aparecem no
  // resultado atual (não uma lista fixa cadastrada em código — a base de
  // postos tem bandeiras demais e variadas pra isso), sempre com a mesma
  // cor de corBandeira() usada nas bolinhas do mapa.
  Widget _legenda(List<PostoComScore> pontosComCoord) {
    final bandeiras = <String>{for (final p in pontosComCoord) rotuloBandeira(p.bandeira)};
    if (bandeiras.isEmpty) return const SizedBox.shrink();
    final lista = bandeiras.toList()..sort();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: lista.map((b) {
          final cor = b == 'Sem bandeira' ? Colors.grey.shade500 : corBandeira(b);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: cor)),
              const SizedBox(width: 4),
              Text(b, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
            ],
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pontosComCoord = postos.where((p) => p.lat != null && p.lon != null).toList();

    final todasLat = <double>[
      ...pontosComCoord.map((p) => p.lat!),
      if (rota != null) ...rota!.map((p) => p.lat),
    ];
    final todasLon = <double>[
      ...pontosComCoord.map((p) => p.lon!),
      if (rota != null) ...rota!.map((p) => p.lon),
    ];

    final contador = Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '${pontosComCoord.length} de ${postos.length} postos com coordenada no mapa',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      ),
    );

    if (todasLat.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          contador,
          SizedBox(
            height: height,
            child: const Center(
              child: Text('Sem coordenadas para exibir no mapa', style: TextStyle(color: Colors.grey)),
            ),
          ),
        ],
      );
    }

    final bounds = LatLngBounds.fromPoints([
      ...pontosComCoord.map((p) => ll.LatLng(p.lat!, p.lon!)),
      if (rota != null) ...rota!.map((p) => ll.LatLng(p.lat, p.lon)),
    ]);

    final cnpjsComParada = (paradas ?? []).map((p) => p.candidato.cnpj).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        contador,
        SizedBox(
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(32)),
                minZoom: 2,
                maxZoom: 18,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.fni.gestaodefrotas',
                ),
                if (rota != null && rota!.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: rota!.map((p) => ll.LatLng(p.lat, p.lon)).toList(),
                        strokeWidth: 4,
                        color: Colors.blue.shade600,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: pontosComCoord.map((p) {
                    final ehParada = cnpjsComParada.contains(p.cnpj);
                    final tamanho = ehParada ? 30.0 : 20.0;
                    return Marker(
                      point: ll.LatLng(p.lat!, p.lon!),
                      width: tamanho,
                      height: tamanho,
                      child: Tooltip(
                        message: '${p.razaoSocial ?? p.cnpj}${ehParada ? ' — parada sugerida' : ''}',
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: corBandeira(p.bandeira),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
                          ),
                          child: ehParada
                              ? const Icon(Icons.local_gas_station, color: Colors.white, size: 16)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        _legenda(pontosComCoord),
      ],
    );
  }
}
