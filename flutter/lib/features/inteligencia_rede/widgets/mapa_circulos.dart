import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

// Widget de mapa único, reaproveitado pelas 4 abas de Inteligência de Rede
// que têm um mapa Leaflet na web (MapaDensidade, MapaPrecoOperacional,
// MapaGapCobertura, MapaFrotaReal — todas quase idênticas: CircleMarker
// colorido + tooltip, ajuste automático de zoom pros pontos). Em vez de
// portar 4 arquivos quase iguais, um só parametrizado por raio/cor/tooltip
// por ponto.
class PontoCirculo {
  final double lat;
  final double lon;
  final Color cor;
  final double raio;
  final String tooltip;
  const PontoCirculo({required this.lat, required this.lon, required this.cor, required this.tooltip, this.raio = 5});
}

class MapaCirculos extends StatelessWidget {
  final List<PontoCirculo> pontos;
  final double height;
  final String mensagemVazio;

  const MapaCirculos({
    super.key,
    required this.pontos,
    this.height = 420,
    this.mensagemVazio = 'Sem pontos com coordenada pra exibir no mapa.',
  });

  @override
  Widget build(BuildContext context) {
    if (pontos.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(mensagemVazio, style: TextStyle(color: Colors.grey.shade500, fontSize: 12), textAlign: TextAlign.center),
        ),
      );
    }

    final bounds = LatLngBounds.fromPoints(pontos.map((p) => ll.LatLng(p.lat, p.lon)).toList());

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(24), maxZoom: 6),
            minZoom: 2,
            maxZoom: 18,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.fni.gestaodefrotas',
            ),
            CircleLayer(
              circles: pontos
                  .map((p) => CircleMarker(
                        point: ll.LatLng(p.lat, p.lon),
                        radius: p.raio,
                        color: p.cor.withOpacity(0.7),
                        borderColor: p.cor,
                        borderStrokeWidth: 1,
                      ))
                  .toList(),
            ),
            MarkerLayer(
              markers: pontos
                  .map((p) => Marker(
                        point: ll.LatLng(p.lat, p.lon),
                        width: p.raio * 2 + 8,
                        height: p.raio * 2 + 8,
                        child: Tooltip(
                          message: p.tooltip,
                          child: const SizedBox.expand(),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
