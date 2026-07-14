import 'package:flutter/material.dart';

import '../../providers/inteligencia_rede_provider.dart';
import '../../widgets/inteligencia_shared.dart';

// Aba 2/10 — "⚠️ Alertas de Preço". Porta GraficoAlertasPorEstado.tsx +
// tabelas de resumo por estado e top 20 desvios.
class AbaAlertas extends StatelessWidget {
  final InteligenciaRedeCompleta dados;
  const AbaAlertas({super.key, required this.dados});

  static Color _corPorDesvio(double desvio) {
    if (desvio > 10) return const Color(0xFFB71C1C);
    if (desvio > 7) return const Color(0xFFE53935);
    return const Color(0xFFEF9A9A);
  }

  @override
  Widget build(BuildContext context) {
    final d = dados;
    final top20 = d.alertas.take(20).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Postos com preço acima do ANP', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                'Postos GF com preço mais de 5% acima da referência ANP (município → estado → Brasil).',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.7,
                children: [
                  CartaoIndicador(label: '⚠️ Postos em Alerta', valor: formatarInt(d.alertas.length), sub: '${d.pctAlerta.toStringAsFixed(0)}% da base', mini: true),
                  CartaoIndicador(label: '✅ Dentro da Média', valor: formatarInt(d.totalAvaliados - d.alertas.length), mini: true),
                  CartaoIndicador(label: '📈 Pior Desvio', valor: '+${d.piorDesvio.toStringAsFixed(1)}%', mini: true),
                  CartaoIndicador(label: '📊 Desvio Médio', valor: '+${d.desvioMedio.toStringAsFixed(1)}%', mini: true),
                ],
              ),
              const SizedBox(height: 16),
              if (d.alertasPorEstado.isNotEmpty) ...[
                Text('Postos em Alerta por Estado', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                BarraHorizontal(
                  dados: d.alertasPorEstado
                      .map((e) => BarraHorizontalItem(label: e.uf, valor: e.postosAlerta.toDouble(), cor: _corPorDesvio(e.piorDesvio), texto: '${e.postosAlerta}'))
                      .toList(),
                  eixoX: 'Postos em alerta',
                ),
                const SizedBox(height: 16),
                Text('Resumo por Estado', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                TabelaSimples(
                  colunas: const ['Estado', 'Postos', 'Pior Desvio'],
                  linhas: d.alertasPorEstado.map((e) => [e.uf, '${e.postosAlerta}', '+${e.piorDesvio.toStringAsFixed(1)}%']).toList(),
                ),
              ] else
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Nenhum posto em alerta no momento.', style: TextStyle(color: Colors.grey))),
              if (top20.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Top 20 Postos com Maior Desvio', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                TabelaSimples(
                  colunas: const ['Posto', 'UF', 'Combustível', 'Preço GF', 'Ref. ANP', 'Desvio'],
                  flexColunas: const [3, 1, 3, 2, 2, 2],
                  maxHeight: 420,
                  linhas: top20
                      .map((a) => [
                            truncarTexto(a.razaoSocial, 20),
                            a.uf ?? '—',
                            a.combustivel,
                            formatarMoeda(a.precoGf),
                            a.precoAnp != null ? formatarMoeda(a.precoAnp!) : '—',
                            '+${a.diffPct.toStringAsFixed(1)}%',
                          ])
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
