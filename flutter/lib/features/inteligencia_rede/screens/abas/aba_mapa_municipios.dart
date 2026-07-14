import 'package:flutter/material.dart';

import '../../providers/inteligencia_rede_provider.dart';
import '../../widgets/inteligencia_shared.dart';
import '../../widgets/mapa_circulos.dart';

// Aba 4/10 — "🗺️ Mapa & Municípios". Porta MapaDensidade.tsx +
// GraficoTopMunicipios.tsx + tabela de cobertura por estado.
class AbaMapaMunicipios extends StatelessWidget {
  final InteligenciaRedeCompleta dados;
  const AbaMapaMunicipios({super.key, required this.dados});

  @override
  Widget build(BuildContext context) {
    final d = dados;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🗺️ Mapa de Densidade', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text('Distribuição geográfica dos postos GF.', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(height: 12),
                  MapaCirculos(
                    height: 420,
                    mensagemVazio: 'Nenhum posto com coordenadas cadastradas para exibir no mapa.',
                    pontos: d.pontosMapa
                        .map((p) => PontoCirculo(
                              lat: p.lat,
                              lon: p.lon,
                              cor: const Color(0xFF1565C0),
                              raio: 4,
                              tooltip: '${p.razaoSocial ?? "Posto GF"}\n${[p.municipio, p.uf].where((v) => v != null && v.isNotEmpty).join(" / ")}',
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Top 10 Municípios com Mais Postos GF', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 12),
                  if (d.topMunicipios.isEmpty)
                    const Text('Ainda não há postos cadastrados.', style: TextStyle(color: Colors.grey))
                  else
                    BarraHorizontal(
                      dados: d.topMunicipios
                          .map((m) => BarraHorizontalItem(label: '${m.municipio}/${m.uf}', valor: m.total.toDouble(), cor: const Color(0xFF1565C0), texto: '${m.total}'))
                          .toList(),
                      eixoX: 'Postos GF',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cobertura por estado (vs referência ANP)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 12),
                  if (d.cobertura.isEmpty)
                    const Text('Ainda não há postos cadastrados. Importe a planilha em Postos Revendedores.', style: TextStyle(color: Colors.grey))
                  else
                    TabelaSimples(
                      colunas: const ['UF', 'Rede', 'Total ANP', 'Penetração'],
                      linhas: d.cobertura
                          .map((c) => [c.uf, '${c.postosGf}', c.totalAnp > 0 ? '${c.totalAnp}' : '—', c.totalAnp > 0 ? '${c.penetracao.toStringAsFixed(2)}%' : '—'])
                          .toList(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
