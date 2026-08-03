import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../providers/torre_de_controle_provider.dart';

// Fase Grupo 2 (Rodopar/Datapar, item 4, 03/08/2026) — mapa ao vivo da Torre
// de Controle, alimentado pelo endpoint GENÉRICO de ingestão GPS
// (/api/integracoes/gps). Mesma lib (flutter_map + latlong2) e mesma fonte
// de tiles OSM já usadas em roteirizacao/screens/mapa_postos.dart — widget
// próprio (mais simples) porque aqui o "marcador" é posição de veículo, não
// posto com bandeira/score.
Color _corPorIdade(DateTime timestampGps) {
  final minutos = DateTime.now().difference(timestampGps).inMinutes;
  if (minutos <= 15) return const Color(0xFF16A34A); // verde
  if (minutos <= 120) return const Color(0xFFEAB308); // amarelo
  return const Color(0xFF64748B); // cinza
}

String _tempoRelativo(DateTime data) {
  final diff = DateTime.now().difference(data);
  if (diff.inMinutes < 1) return 'agora';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'há ${diff.inHours}h';
  return 'há ${diff.inDays} dia${diff.inDays == 1 ? '' : 's'}';
}

class MapaVeiculos extends StatelessWidget {
  final List<PosicaoVeiculo> posicoes;
  final double height;

  const MapaVeiculos({super.key, required this.posicoes, this.height = 280});

  @override
  Widget build(BuildContext context) {
    if (posicoes.isEmpty) return const SizedBox.shrink();

    final bounds = LatLngBounds.fromPoints(posicoes.map((p) => ll.LatLng(p.lat, p.lon)).toList());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                MarkerLayer(
                  markers: posicoes.map((p) {
                    final cor = _corPorIdade(p.timestampGps);
                    return Marker(
                      point: ll.LatLng(p.lat, p.lon),
                      width: 26,
                      height: 26,
                      child: Tooltip(
                        message:
                            '${p.placa}${p.velocidadeKmh != null ? ' — ${p.velocidadeKmh!.toStringAsFixed(0)} km/h' : ''} — ${_tempoRelativo(p.timestampGps)}${p.provedor != null ? ' — ${p.provedor}' : ''}',
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cor,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
                          ),
                          child: const Icon(Icons.local_shipping, color: Colors.white, size: 14),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _legendaItem(const Color(0xFF16A34A), 'Recente (≤15 min)'),
              _legendaItem(const Color(0xFFEAB308), 'Até 2h atrás'),
              _legendaItem(const Color(0xFF64748B), 'Mais de 2h sem sinal'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendaItem(Color cor, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: cor)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
      ],
    );
  }
}
