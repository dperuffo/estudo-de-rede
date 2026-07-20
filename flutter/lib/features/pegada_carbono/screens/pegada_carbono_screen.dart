import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/pegada_carbono_provider.dart';

const _kgCo2AbsorvidoPorArvoreAoAno = 22;

final _dataBr = DateFormat('dd/MM/yyyy');
final _numero0 = NumberFormat.decimalPattern('pt_BR');

const _labelCategoria = {
  'GASOLINA COMUM': '⛽ Gasolina Comum',
  'GASOLINA ADITIVADA': '⛽ Gasolina Aditivada',
  'ETANOL HIDRATADO': '🌱 Etanol Hidratado',
  'OLEO DIESEL': '🛢️ Óleo Diesel',
  'OLEO DIESEL S10': '🛢️ Óleo Diesel S10',
  'GNV': '🔥 GNV',
  'GLP': '🔥 GLP',
};

// Fase Onda-3 (benchmark TicketLog, item #10) — porta de
// pegada-carbono/page.tsx (web). Pedido do Daniel: "Implementar estas duas
// iniciativas na web e PWA cliente".
class PegadaCarbonoScreen extends ConsumerStatefulWidget {
  const PegadaCarbonoScreen({super.key});

  @override
  ConsumerState<PegadaCarbonoScreen> createState() => _PegadaCarbonoScreenState();
}

class _PegadaCarbonoScreenState extends ConsumerState<PegadaCarbonoScreen> {
  FiltroPeriodoCarbono _periodo = periodoPadraoCarbono();

  Future<void> _escolherData({required bool inicio}) async {
    final atual = inicio ? _periodo.inicio : _periodo.fim;
    final escolhida = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (escolhida == null || !mounted) return;
    setState(() {
      _periodo = inicio
          ? FiltroPeriodoCarbono(inicio: escolhida, fim: _periodo.fim)
          : FiltroPeriodoCarbono(inicio: _periodo.inicio, fim: escolhida);
    });
  }

  @override
  Widget build(BuildContext context) {
    final itensAsync = ref.watch(pegadaCarbonoProvider(_periodo));

    return Scaffold(
      appBar: AppBar(title: const Text('Pegada de Carbono')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(pegadaCarbonoProvider(_periodo)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Text(
              'Estimativa de CO2 emitido pela frota, calculada a partir dos litros já registrados nos '
              'abastecimentos. Indicador indicativo pra acompanhamento interno/ESG — não substitui um '
              'inventário de emissões certificado.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _escolherData(inicio: true),
                    child: Text('De: ${_dataBr.format(_periodo.inicio)}', style: const TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _escolherData(inicio: false),
                    child: Text('Até: ${_dataBr.format(_periodo.fim)}', style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            itensAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Erro ao carregar: $e'),
              data: (itens) {
                final totalKg = itens.fold<double>(0, (s, i) => s + (i.co2EstimadoKg ?? 0));
                final totalToneladas = totalKg / 1000;
                final litrosTotal = itens.fold<double>(0, (s, i) => s + i.litrosTotal);
                final arvores = (totalKg / _kgCo2AbsorvidoPorArvoreAoAno).round();
                final semFator = itens.where((i) => i.fatorKgCo2PorLitro == null).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _kpi('CO2 estimado', '${totalToneladas.toStringAsFixed(2)} t')),
                        const SizedBox(width: 8),
                        Expanded(child: _kpi('Litros', _numero0.format(litrosTotal))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (arvores > 0) _kpi('Equivalente a', '🌳 ${_numero0.format(arvores)} árvores/ano'),
                    const SizedBox(height: 12),
                    Card(
                      color: const Color(0xFFF8FAFC),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Litros de cada combustível × fator médio de emissão (kg de CO2 por litro, Programa '
                          'Brasileiro GHG Protocol). A equivalência em árvores usa $_kgCo2AbsorvidoPorArvoreAoAno '
                          'kg de CO2 absorvidos por árvore adulta por ano — só pra dar noção de tamanho, não é um '
                          'fator científico exato.',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (itens.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Nenhum abastecimento encontrado neste período.', style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    else
                      ...itens.map((i) => _cardCategoria(i, totalKg)),
                    if (semFator.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${semFator.map((i) => _labelCategoria[i.categoria] ?? i.categoria).join(", ")} sem '
                          'fator de emissão cadastrado — não entrou no total.',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpi(String label, String valor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 0.3)),
            const SizedBox(height: 4),
            Text(valor, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _cardCategoria(ItemPegadaCarbono i, double totalKg) {
    final pct = i.co2EstimadoKg != null && totalKg > 0 ? (i.co2EstimadoKg! / totalKg) * 100 : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(_labelCategoria[i.categoria] ?? i.categoria, style: const TextStyle(fontSize: 13)),
            ),
            Expanded(
              flex: 2,
              child: Text('${_numero0.format(i.litrosTotal)} L',
                  style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.right),
            ),
            Expanded(
              flex: 2,
              child: Text(
                i.co2EstimadoKg != null ? '${(i.co2EstimadoKg! / 1000).toStringAsFixed(2)} t' : 'não estimado',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                textAlign: TextAlign.right,
              ),
            ),
            if (pct != null)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }
}
