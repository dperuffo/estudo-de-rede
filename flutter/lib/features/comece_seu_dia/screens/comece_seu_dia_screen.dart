import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/menu_button.dart';

class ComeceSeuDiaScreen extends StatefulWidget {
  const ComeceSeuDiaScreen({super.key});
  @override State<ComeceSeuDiaScreen> createState() => _State();
}

class _State extends State<ComeceSeuDiaScreen> {
  Map<String, dynamic>? _dados;
  bool _loading = true;
  int _dias = 7;
  String? _periodo;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{'dias': _dias};
      if (_periodo != null) params['periodo'] = _periodo;
      final r = await ApiService().get('/comece-seu-dia', params: params);
      setState(() => _dados = r);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _saudacao() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bom dia';
    if (h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  String _dataHoje() {
    final dias = ['Segunda','Terca','Quarta','Quinta','Sexta','Sabado','Domingo'];
    final meses = ['janeiro','fevereiro','marco','abril','maio','junho','julho','agosto','setembro','outubro','novembro','dezembro'];
    final now = DateTime.now();
    return '${dias[now.weekday-1]}, ${now.day} de ${meses[now.month-1]}';
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final kpis    = _dados?['kpis'] as Map? ?? {};
    final porDia  = (_dados?['por_dia']  as List?) ?? [];
    final porComb = (_dados?['por_combustivel'] as List?) ?? [];
    final topVeic = (_dados?['top_veiculos'] as List?) ?? [];
    final ultimos = (_dados?['ultimos_abastecimentos'] as List?) ?? [];
    final alertas = (_dados?['alertas'] as List?) ?? [];
    final nome    = (_dados?['saudacao'] as Map?)?['nome'] ?? 'Gestor';
    final firstName = nome.split(' ').first;

    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: const Text('Comece seu dia'),
        actions: [
          DropdownButton<String>(
            value: _periodo ?? 'hoje',
            dropdownColor: const Color(0xFF0D2D6B),
            style: const TextStyle(color: Colors.white),
            items: const [
              DropdownMenuItem(value: 'hoje',   child: Text('Hoje')),
              DropdownMenuItem(value: 'ontem',  child: Text('Ontem')),
              DropdownMenuItem(value: '7dias',  child: Text('7 dias')),
              DropdownMenuItem(value: '15dias', child: Text('15 dias')),
              DropdownMenuItem(value: '30dias', child: Text('30 dias')),
            ],
            onChanged: (v) {
              setState(() {
                _periodo = v == 'ontem' ? 'ontem' : null;
                _dias = v == 'hoje' ? 1 : v == 'ontem' ? 1
                    : v == '7dias' ? 7 : v == '15dias' ? 15 : 30;
              });
              _load();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: ListView(
              padding: const EdgeInsets.all(16),
              children: [

                // Saudação
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D2D6B), Color(0xFF1565C0)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${_saudacao()}, $firstName! 👋',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_dataHoje(),
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    Text('Resumo operacional — ${_periodo == "ontem" ? "ontem" : _dias == 1 ? "hoje" : "ultimos $_dias dias"}',
                        style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ]),
                ),
                const SizedBox(height: 16),

                // Alertas
                if (alertas.isNotEmpty) ...[
                  ...alertas.map((a) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: a['tipo'] == 'warn' ? const Color(0xFFFFF3E0) : const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: a['tipo'] == 'warn' ? Colors.orange : Colors.blue,
                        width: 0.5,
                      ),
                    ),
                    child: Row(children: [
                      Icon(a['tipo'] == 'warn' ? Icons.warning_amber : Icons.info_outline,
                          color: a['tipo'] == 'warn' ? Colors.orange : Colors.blue, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(a['msg'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: a['tipo'] == 'warn' ? Colors.orange[900] : Colors.blue[900],
                          ))),
                    ]),
                  )),
                  const SizedBox(height: 8),
                ],

                // KPIs principais
                _secao('Combustivel & Abastecimentos'),
                Row(children: [
                  _kpiCard('Abastecimentos', '${kpis["n_abastecimentos"] ?? 0}', Icons.local_gas_station, Colors.blue),
                  const SizedBox(width: 8),
                  _kpiCard('Litros', '${(kpis["total_litros"] ?? 0).toStringAsFixed(0)} L', Icons.water_drop, Colors.cyan),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _kpiCard('Gasto Combustivel', fmt.format(kpis['total_gasto'] ?? 0), Icons.payments, Colors.green),
                  const SizedBox(width: 8),
                  _kpiCard('Preco Medio/L', fmt.format(kpis['preco_medio'] ?? 0), Icons.price_change, Colors.orange),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _kpiCard('Ticket Medio', fmt.format(kpis['ticket_medio'] ?? 0), Icons.receipt, Colors.purple),
                  const SizedBox(width: 8),
                  _kpiCard('Veiculos Ativos', '${kpis["n_veiculos"] ?? 0}', Icons.directions_car, Colors.teal),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _kpiCard('Manutencao', fmt.format(kpis['total_manutencao'] ?? 0), Icons.build, Colors.red),
                  const SizedBox(width: 8),
                  _kpiCard('Total Geral', fmt.format(kpis['total_geral'] ?? 0), Icons.account_balance_wallet, const Color(0xFF0D2D6B)),
                ]),
                const SizedBox(height: 24),

                // Gráfico gasto por dia
                if (porDia.isNotEmpty) ...[
                  _secao('Gasto por dia (R\$)'),
                  SizedBox(height: 200, child: _graficoBarras(porDia, fmt)),
                  const SizedBox(height: 24),
                ],

                // Gráfico por combustível
                if (porComb.isNotEmpty) ...[
                  _secao('Por combustivel'),
                  ...porComb.map((c) => _barraHorizontal(
                    c['item_nome'] ?? '-',
                    c['gasto'] ?? 0,
                    kpis['total_gasto'] ?? 1,
                    fmt,
                    '${(c["litros"] ?? 0).toStringAsFixed(0)} L · ${c["n"]} abast.',
                  )),
                  const SizedBox(height: 24),
                ],

                // Top veículos
                if (topVeic.isNotEmpty) ...[
                  _secao('Top veiculos por gasto'),
                  ...topVeic.asMap().entries.map((e) {
                    final i = e.key; final v = e.value;
                    return _itemRanking(
                      i + 1,
                      v['veiculo_placa'] ?? '-',
                      fmt.format(v['gasto'] ?? 0),
                      '${(v["litros"] ?? 0).toStringAsFixed(0)} L · ${v["n"]} abast.',
                      Colors.blue,
                    );
                  }),
                  const SizedBox(height: 24),
                ],

                // Últimos abastecimentos
                if (ultimos.isNotEmpty) ...[
                  _secao('Ultimos abastecimentos'),
                  ...ultimos.map((a) => Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE3F2FD),
                        radius: 18,
                        child: Icon(Icons.local_gas_station, color: Colors.blue, size: 18),
                      ),
                      title: Text('${a["veiculo_placa"] ?? "-"} — ${a["item_nome"] ?? "-"}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('${a["data_abastecimento"]?.toString().substring(0,10) ?? "-"} · ${a["pv_municipio"] ?? "-"}/${a["pv_uf"] ?? "-"}'),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(fmt.format(a['item_valor_total'] ?? 0),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12)),
                        Text('${(a["item_quantidade"] ?? 0).toStringAsFixed(0)} L',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ]),
                    ),
                  )),
                ],
              ],
            )),
    );
  }

  Widget _secao(String titulo) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D2D6B))),
  );

  Widget _kpiCard(String label, String value, IconData icon, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ])),
      ]),
    ),
  );

  Widget _graficoBarras(List dados, NumberFormat fmt) {
    if (dados.isEmpty) return const SizedBox();
    final maxVal = dados.map((d) => (d['gasto'] as num? ?? 0).toDouble()).reduce((a, b) => a > b ? a : b);
    return BarChart(BarChartData(
      maxY: maxVal * 1.2,
      barGroups: dados.asMap().entries.map((e) => BarChartGroupData(
        x: e.key,
        barRods: [BarChartRodData(
          toY: (e.value['gasto'] as num? ?? 0).toDouble(),
          color: const Color(0xFF1565C0),
          width: 12,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        )],
      )).toList(),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (v, _) {
            final idx = v.toInt();
            if (idx < 0 || idx >= dados.length) return const SizedBox();
            final dia = (dados[idx]['dia'] as String? ?? '').substring(8);
            return Text(dia, style: const TextStyle(fontSize: 10));
          },
        )),
      ),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(show: true, drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1)),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, _, rod, __) => BarTooltipItem(
            fmt.format(rod.toY),
            const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
      ),
    ));
  }

  Widget _barraHorizontal(String label, num valor, num total, NumberFormat fmt, String sub) {
    final pct = total > 0 ? valor / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          Text(fmt.format(valor), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0D2D6B))),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.toDouble(),
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation(Color(0xFF1565C0)),
            minHeight: 8,
          ),
        ),
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
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
        child: Center(child: Text('$pos', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13))),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ])),
      Text(valor, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
    ]),
  );
}
