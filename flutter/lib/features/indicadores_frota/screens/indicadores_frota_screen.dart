import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/indicadores_frota_provider.dart';

final _dataBr = DateFormat('dd/MM/yyyy');
final _dataIso = DateFormat('yyyy-MM-dd');
final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

// Fase Indicadores-da-Frota (30/07/2026) — porta de indicadores-frota/page.tsx.
// Reúne os 4 KPIs que dá pra calcular com dado já coletado (disponibilidade,
// CPK operacional, consumo médio, utilização) + a proporção corretiva/
// preventiva. Ver escopo completo em indicadores_frota_provider.dart.
class IndicadoresFrotaScreen extends ConsumerStatefulWidget {
  const IndicadoresFrotaScreen({super.key});

  @override
  ConsumerState<IndicadoresFrotaScreen> createState() => _IndicadoresFrotaScreenState();
}

class _IndicadoresFrotaScreenState extends ConsumerState<IndicadoresFrotaScreen> {
  DateTime _dataInicio = DateTime.now().subtract(const Duration(days: 90));
  DateTime _dataFim = DateTime.now();

  Future<void> _escolherData({required bool inicio}) async {
    final atual = inicio ? _dataInicio : _dataFim;
    final escolhida = await showDatePicker(context: context, initialDate: atual, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (escolhida == null || !mounted) return;
    setState(() {
      if (inicio) {
        _dataInicio = escolhida;
      } else {
        _dataFim = escolhida;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtro = (dataInicio: _dataIso.format(_dataInicio), dataFim: _dataIso.format(_dataFim));
    final kpisAsync = ref.watch(kpisFrotaProvider(filtro));

    return Scaffold(
      appBar: AppBar(title: const Text('Indicadores da Frota')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(kpisFrotaProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Os principais KPIs de gestão de frota, calculados a partir dos dados já cadastrados — abastecimentos, '
              'manutenções e hodômetro.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _escolherData(inicio: true),
                    child: Text('De: ${_dataBr.format(_dataInicio)}', style: const TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _escolherData(inicio: false),
                    child: Text('Até: ${_dataBr.format(_dataFim)}', style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            kpisAsync.when(
              data: (kpis) => kpis == null
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('Nenhum dado encontrado para esse período.', style: TextStyle(color: Colors.grey))),
                    )
                  : _corpo(kpis),
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Erro ao carregar: $e', style: const TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _corpo(KpisFrota k) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.7,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            _card('Disponibilidade', k.disponibilidadePct != null ? '${k.disponibilidadePct}%' : '—', destaque: k.disponibilidadePct != null && k.disponibilidadePct! < 90),
            _card('CPK operacional', k.cpkOperacional != null ? '${_moeda.format(k.cpkOperacional)}/km' : '—'),
            _card('Consumo médio', k.mediaKmL != null ? '${k.mediaKmL} km/l' : '—'),
            _card('Utilização', k.utilizacaoPct != null ? '${k.utilizacaoPct}%' : '—', destaque: k.utilizacaoPct != null && k.utilizacaoPct! < 70),
            _card(
              'Manutenção corretiva',
              k.pctCorretiva != null ? '${k.pctCorretiva}%' : 'Sem classificação',
              destaque: k.pctCorretiva != null && k.pctCorretiva! > 20,
            ),
            _card('Veículos ativos', '${k.totalVeiculos}'),
          ],
        ),
        if (k.manutencaoNaoClassificadaCusto > 0) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFDE68A))),
            child: Text(
              '⚠️ ${_moeda.format(k.manutencaoNaoClassificadaCusto)} em manutenções deste período ainda não foram '
              'classificadas como Preventiva ou Corretiva. Classifique as novas manutenções em Manutenção Preditiva.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => context.push('/manutencao-preditiva'),
            child: const Text('Ir para Manutenção Preditiva →', style: TextStyle(fontSize: 12)),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
          child: const Text(
            'Taxa de conformidade (checklist de inspeção), tempo médio de resolução de não conformidades e índice de '
            'sinistralidade não aparecem aqui porque a plataforma ainda não tem um fluxo de captura desses dados.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _card(String label, String valor, {bool destaque = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: destaque ? const Color(0xFFFFFBEB) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: destaque ? const Color(0xFFFDE68A) : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: destaque ? const Color(0xFF92400E) : Colors.black87),
          ),
        ],
      ),
    );
  }
}
