import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/menu_button.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _State();
}

class _State extends State<DashboardScreen> {
  Map<String, dynamic>? _dados;
  bool _loading = true;
  int _dias = 30;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService().get('/dashboard/resumo', params: {'dias': _dias});
      setState(() => _dados = r);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt    = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final ab     = _dados?['abastecimentos'] as Map? ?? {};
    final mn     = _dados?['manutencao'] as Map? ?? {};
    final topV   = (_dados?['top_veiculos'] as List?) ?? [];
    final topU   = (_dados?['top_ufs'] as List?) ?? [];
    final total  = (_dados?['total_geral'] as num? ?? 0).toDouble();
    final totalC = (ab['total_gasto'] as num? ?? 0).toDouble();
    final totalM = (mn['total_gasto'] as num? ?? 0).toDouble();

    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: const Text('Dashboard'),
        actions: [
          DropdownButton<int>(
            value: _dias,
            dropdownColor: const Color(0xFF0D2D6B),
            style: const TextStyle(color: Colors.white),
            items: [7,15,30,60,90].map((d) => DropdownMenuItem(value: d, child: Text('$d dias'))).toList(),
            onChanged: (v) { setState(() => _dias = v!); _load(); },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: ListView(
              padding: const EdgeInsets.all(16),
              children: [

                // Card total
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D2D6B), Color(0xFF1565C0)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    Text('Ultimos $_dias dias', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    const SizedBox(height: 8),
                    const Text('Total Geral', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    Text(fmt.format(total),
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                      _metricaBranca('Combustivel', fmt.format(totalC),
                          total > 0 ? '${(totalC/total*100).toStringAsFixed(0)}%' : '0%'),
                      Container(width: 1, height: 40, color: Colors.white24),
                      _metricaBranca('Manutencao', fmt.format(totalM),
                          total > 0 ? '${(totalM/total*100).toStringAsFixed(0)}%' : '0%'),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),

                // KPIs
                Row(children: [
                  _kpi('Litros', '${(ab["total_litros"]??0).toStringAsFixed(0)} L', Colors.cyan),
                  const SizedBox(width: 8),
                  _kpi('Abastec.', '${ab["n_registros"]??0}', Colors.blue),
                  const SizedBox(width: 8),
                  _kpi('Veiculos', '${ab["n_veiculos"]??0}', Colors.teal),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _kpi('UFs', '${ab["n_ufs"]??0}', Colors.green),
                  const SizedBox(width: 8),
                  _kpi('Media/dia', '${(ab["media_litros_dia"]??0).toStringAsFixed(0)} L', Colors.orange),
                  const SizedBox(width: 8),
                  _kpi('Manut.', '${mn["n_registros"]??0}', Colors.red),
                ]),
                const SizedBox(height: 24),

                // Pizza
                if (total > 0) ...[
                  _secao('Distribuicao de custos'),
                  SizedBox(height: 180, child: Row(children: [
                    Expanded(child: PieChart(PieChartData(
                      sections: [
                        PieChartSectionData(
                          value: totalC,
                          title: '${(totalC/total*100).toStringAsFixed(0)}%',
                          color: const Color(0xFF1565C0),
                          radius: 70,
                          titleStyle: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        if (totalM > 0) PieChartSectionData(
                          value: totalM,
                          title: '${(totalM/total*100).toStringAsFixed(0)}%',
                          color: Colors.red,
                          radius: 70,
                          titleStyle: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                      centerSpaceRadius: 35,
                      sectionsSpace: 2,
                    ))),
                    const SizedBox(width: 16),
                    Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _legenda(const Color(0xFF1565C0), 'Combustivel', fmt.format(totalC)),
                      const SizedBox(height: 12),
                      if (totalM > 0) _legenda(Colors.red, 'Manutencao', fmt.format(totalM)),
                    ]),
                  ])),
                  const SizedBox(height: 24),
                ],

                // Top veículos
                if (topV.isNotEmpty) ...[
                  _secao('Top veiculos por gasto'),
                  _graficoHorizontal(
                    topV.map((v) => MapEntry(v['veiculo_placa']?.toString() ?? '-', (v['gasto'] as num? ?? 0).toDouble())).toList(),
                    Colors.blue, fmt,
                  ),
                  const SizedBox(height: 24),
                ],

                // Top UFs
                if (topU.isNotEmpty) ...[
                  _secao('Top estados por gasto'),
                  ...topU.asMap().entries.map((e) => _itemRanking(
                    e.key+1,
                    e.value['pv_uf']?.toString() ?? '-',
                    fmt.format(e.value['gasto'] ?? 0),
                    '${(e.value["litros"]??0).toStringAsFixed(0)} L · ${e.value["n"]} abast.',
                    Colors.teal,
                  )),
                ],
              ],
            )),
    );
  }

  Widget _secao(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D2D6B))),
  );

  Widget _metricaBranca(String label, String valor, String pct) => Column(children: [
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
    Text(valor, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
    Text(pct,   style: const TextStyle(color: Colors.white70, fontSize: 11)),
  ]);

  Widget _kpi(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ]),
    ),
  );

  Widget _legenda(Color color, String label, String valor) => Row(children: [
    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 6),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12)),
      Text(valor, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
    ]),
  ]);

  Widget _graficoHorizontal(List<MapEntry<String, double>> dados, Color color, NumberFormat fmt) {
    if (dados.isEmpty) return const SizedBox();
    final maxVal = dados.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return Column(children: dados.map((e) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(width: 80, child: Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
            value: maxVal > 0 ? e.value / maxVal : 0,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 20,
          ))),
          const SizedBox(width: 8),
          Text(fmt.format(e.value), style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
        ]),
      ]),
    )).toList());
  }

  Widget _itemRanking(int pos, String titulo, String valor, String sub, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.withOpacity(0.2)),
    ),
    child: Row(children: [
      Container(width: 28, height: 28,
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
        child: Center(child: Text('$pos', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ])),
      Text(valor, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
    ]),
  );
}
