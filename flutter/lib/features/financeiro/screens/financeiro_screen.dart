import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/menu_button.dart';

class FinanceiroScreen extends StatefulWidget {
  const FinanceiroScreen({super.key});
  @override State<FinanceiroScreen> createState() => _State();
}

class _State extends State<FinanceiroScreen> {
  Map<String, dynamic>? _dados;
  bool _loading = true;
  String? _mesSel;

  final List<String> _meses = _gerarMeses();

  static List<String> _gerarMeses() {
    final now = DateTime.now();
    return List.generate(12, (i) {
      final d = DateTime(now.year, now.month - i, 1);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    });
  }

  @override void initState() {
    super.initState();
    _mesSel = _meses.first;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService().get('/financeiro/resumo',
          params: _mesSel != null ? {'mes': _mesSel} : {});
      setState(() => _dados = r);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _nomeMes(String mes) {
    final meses = ['','Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
    final parts = mes.split('-');
    return '${meses[int.parse(parts[1])]}/${parts[0].substring(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final fmt  = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final kpis = _dados?['kpis'] as Map? ?? {};
    final porDia   = (_dados?['por_dia']   as List?) ?? [];
    final porComb  = (_dados?['por_combustivel'] as List?) ?? [];
    final porVeic  = (_dados?['por_veiculo'] as List?) ?? [];
    final porVeicM = (_dados?['por_veiculo_manut'] as List?) ?? [];
    final topMun   = (_dados?['top_municipios'] as List?) ?? [];
    final periodo  = _dados?['periodo'] as Map? ?? {};

    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: const Text('Painel Financeiro'),
        actions: [
          DropdownButton<String>(
            value: _mesSel,
            dropdownColor: const Color(0xFF0D2D6B),
            style: const TextStyle(color: Colors.white),
            items: _meses.map((m) => DropdownMenuItem(
              value: m, child: Text(_nomeMes(m)))).toList(),
            onChanged: (v) { setState(() => _mesSel = v); _load(); },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: ListView(
              padding: const EdgeInsets.all(16),
              children: [

                // Card total geral
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
                    Text('${periodo["inicio"] ?? ""} — ${periodo["fim"] ?? ""}',
                        style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    const SizedBox(height: 8),
                    Text('Total Geral', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    Text(fmt.format(kpis['total_geral'] ?? 0),
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                      _metricaBranca('Combustivel', fmt.format(kpis['total_comb'] ?? 0),
                          '${kpis["pct_comb"]}%'),
                      Container(width: 1, height: 40, color: Colors.white24),
                      _metricaBranca('Manutencao', fmt.format(kpis['total_manut'] ?? 0),
                          '${kpis["pct_manut"]}%'),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),

                // KPIs secundários
                Row(children: [
                  _kpi('Abastecimentos', '${kpis["n_abastec"] ?? 0}', Colors.blue),
                  const SizedBox(width: 8),
                  _kpi('Litros', '${(kpis["total_litros"] ?? 0).toStringAsFixed(0)} L', Colors.cyan),
                  const SizedBox(width: 8),
                  _kpi('Veiculos', '${kpis["n_veiculos"] ?? 0}', Colors.teal),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _kpi('Preco Medio/L', fmt.format(kpis['preco_medio'] ?? 0), Colors.orange),
                  const SizedBox(width: 8),
                  _kpi('Manutencoes', '${kpis["n_manut"] ?? 0}', Colors.red),
                  const SizedBox(width: 8),
                  _kpi('Custo/Veiculo', fmt.format((kpis['total_geral'] ?? 0) / (kpis['n_veiculos'] ?? 1).toDouble()), Colors.purple),
                ]),
                const SizedBox(height: 24),

                // Gráfico pizza combustivel vs manutencao
                if ((kpis['total_geral'] ?? 0) > 0) ...[
                  _secao('Distribuicao de custos'),
                  _barraDistribuicao('Combustivel', (kpis['total_comb'] ?? 0).toDouble(),
                      (kpis['total_geral'] ?? 1).toDouble(), fmt, const Color(0xFF1565C0),
                      '\${kpis["pct_comb"]}% do total'),
                  const SizedBox(height: 8),
                  _barraDistribuicao('Manutencao', (kpis['total_manut'] ?? 0).toDouble(),
                      (kpis['total_geral'] ?? 1).toDouble(), fmt, Colors.red,
                      '\${kpis["pct_manut"]}% do total · \${kpis["n_manut"]} registros'),
                  const SizedBox(height: 24),
                ],

                // Gráfico barras por dia
                if (porDia.isNotEmpty) ...[
                  _secao('Gasto diario (R\$)'),
                  SizedBox(height: 180, child: _graficoBarras(porDia, fmt)),
                  const SizedBox(height: 24),
                ],

                // Por combustível
                if (porComb.isNotEmpty) ...[
                  _secao('Por combustivel'),
                  ...porComb.map((c) => _barraHorizontal(
                    c['item_nome'] ?? '-',
                    (c['gasto'] as num? ?? 0).toDouble(),
                    (kpis['total_comb'] as num? ?? 1).toDouble(),
                    fmt,
                    '${(c["litros"] ?? 0).toStringAsFixed(0)} L · R\$ ${(c["preco_medio"] ?? 0).toStringAsFixed(3)}/L',
                    const Color(0xFF1565C0),
                  )),
                  const SizedBox(height: 24),
                ],

                // Top veículos combustível
                if (porVeic.isNotEmpty) ...[
                  _secao('Top veiculos — Combustivel'),
                  ...porVeic.take(5).toList().asMap().entries.map((e) =>
                    _itemRanking(e.key+1, e.value['veiculo_placa']??'-',
                      fmt.format(e.value['gasto']??0),
                      '${(e.value["litros"]??0).toStringAsFixed(0)} L · ${e.value["n"]} abast.',
                      Colors.blue)),
                  const SizedBox(height: 24),
                ],

                // Top veículos manutenção
                if (porVeicM.isNotEmpty) ...[
                  _secao('Top veiculos — Manutencao'),
                  ...porVeicM.asMap().entries.map((e) =>
                    _itemRanking(e.key+1, e.value['placa']??'-',
                      fmt.format(e.value['gasto']??0),
                      '${e.value["n"]} manutencao(oes)',
                      Colors.red)),
                  const SizedBox(height: 24),
                ],

                // Top municípios
                if (topMun.isNotEmpty) ...[
                  _secao('Top municipios por gasto'),
                  ...topMun.asMap().entries.map((e) =>
                    _itemRanking(e.key+1,
                      '${e.value["pv_municipio"]??"-"}/${e.value["pv_uf"]??"-"}',
                      fmt.format(e.value['gasto']??0),
                      '${e.value["n"]} abastecimentos',
                      Colors.teal)),
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
    Text(pct, style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ]),
    ),
  );

  Widget _barraDistribuicao(String label, double valor, double total, NumberFormat fmt, Color color, String sub) =>
    Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
          const Spacer(),
          Text(fmt.format(valor), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(
          value: total > 0 ? valor / total : 0,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 12,
        )),
        const SizedBox(height: 4),
        Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ]),
    );

  Widget _legenda(Color color, String label) => Row(children: [
    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(fontSize: 13)),
  ]);

  Widget _graficoBarras(List dados, NumberFormat fmt) {
    if (dados.isEmpty) return const SizedBox();
    final maxVal = dados.map((d) => (d['gasto'] as num? ?? 0).toDouble()).reduce((a, b) => a > b ? a : b);
    return BarChart(BarChartData(
      maxY: maxVal * 1.2,
      barGroups: dados.asMap().entries.map((e) => BarChartGroupData(
        x: e.key,
        barRods: [BarChartRodData(
          toY: (e.value['gasto'] as num? ?? 0).toDouble(),
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
            begin: Alignment.bottomCenter, end: Alignment.topCenter,
          ),
          width: 10,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        )],
      )).toList(),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 20,
          getTitlesWidget: (v, _) {
            final idx = v.toInt();
            if (idx < 0 || idx >= dados.length) return const SizedBox();
            final dia = (dados[idx]['dia'] as String? ?? '').substring(8);
            return Text(dia, style: const TextStyle(fontSize: 9));
          },
        )),
      ),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(show: true, drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.withOpacity(0.15), strokeWidth: 1)),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, _, rod, __) => BarTooltipItem(
            fmt.format(rod.toY), const TextStyle(color: Colors.white, fontSize: 11)),
        ),
      ),
    ));
  }

  Widget _barraHorizontal(String label, double valor, double total, NumberFormat fmt, String sub, Color color) {
    final pct = total > 0 ? valor / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          Text(fmt.format(valor), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
          value: pct, backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation(color), minHeight: 8,
        )),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ]),
    );
  }

  Widget _itemRanking(int pos, String titulo, String valor, String sub, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
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
