import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../providers/roteirizacao_provider.dart';
import '../services/geo_service.dart' as geo;
import '../services/roteirizacao_algoritmo.dart' show ParadaSugerida;

// Fase FLT-3 — mapa interativo (pedido do Daniel: "integrar mapas OSM na
// interface do PWA com os postos plotados nos mapas nas consultas
// realizadas por município/UF, posto ou roteirização inteligente").
// Equivalente Flutter do Leaflet usado na web (MapaRota.tsx) — mesma fonte
// de tiles OpenStreetMap, gratuita e sem chave de API. Widget único
// reutilizado nos 3 modos da tela de Roteirização.
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

  Color _corGrade(String? grade) {
    switch (grade) {
      case 'A':
        return Colors.green.shade600;
      case 'B':
        return Colors.lightGreen.shade700;
      case 'C':
        return Colors.orange.shade700;
      case 'D':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
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
                            color: _corGrade(p.score.grade),
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
      ],
    );
  }
}
