import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/menu_button.dart';

class AnaliseClienteScreen extends StatefulWidget {
  const AnaliseClienteScreen({super.key});
  @override State<AnaliseClienteScreen> createState() => _State();
}

class _State extends State<AnaliseClienteScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _dados;
  bool _loading = true;
  int _dias = 30;
  late TabController _tabCtrl;

  @override void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _load();
  }

  @override void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService().get('/analise-cliente', params: {'dias': _dias});
      setState(() => _dados = r);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt   = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final kpis  = _dados?['kpis'] as Map? ?? {};
    final evolucao   = (_dados?['evolucao']      as List?) ?? [];
    final porVeic    = (_dados?['por_veiculo']    as List?) ?? [];
    final porMot     = (_dados?['por_motorista']  as List?) ?? [];
    final porPosto   = (_dados?['por_posto']      as List?) ?? [];
    final porComb    = (_dados?['por_combustivel'] as List?) ?? [];
    final porUf      = (_dados?['por_uf']         as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: const Text('Analise de Cliente'),
        actions: [
          DropdownButton<int>(
            value: _dias,
            dropdownColor: const Color(0xFF0D2D6B),
            style: const TextStyle(color: Colors.white),
            items: [7,15,30,60,90,180].map((d) => DropdownMenuItem(
              value: d, child: Text('$d dias'))).toList(),
            onChanged: (v) { setState(() => _dias = v!); _load(); },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Resumo'),
            Tab(text: 'Veiculos'),
            Tab(text: 'Motoristas'),
            Tab(text: 'Postos'),
            Tab(text: 'Estados'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildResumo(fmt, kpis, evolucao, porComb),
                _buildVeiculos(fmt, porVeic, kpis),
                _buildMotoristas(fmt, porMot, kpis),
                _buildPostos(fmt, porPosto, kpis),
                _buildUfs(fmt, porUf, kpis),
              ],
            ),
    );
  }

  // ── ABA RESUMO ──────────────────────────────────────────────────
  Widget _buildResumo(NumberFormat fmt, Map kpis, List evolucao, List porComb) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [

        // Header gradient
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
            Text(fmt.format(kpis['total_gasto'] ?? 0),
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            const Text('Total em combustivel', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _metrica('${kpis["n_abastecimentos"] ?? 0}', 'Abastec.'),
              _metrica('${(kpis["total_litros"] ?? 0).toStringAsFixed(0)} L', 'Litros'),
              _metrica(fmt.format(kpis['ticket_medio'] ?? 0), 'Ticket Medio'),
            ]),
          ]),
        ),
        const SizedBox(height: 16),

        // KPIs secundários
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.5,
          children: [
            _kpiCard('Veiculos', '${kpis["n_veiculos"] ?? 0}', Icons.directions_car, Colors.blue),
            _kpiCard('Motoristas', '${kpis["n_motoristas"] ?? 0}', Icons.person, Colors.teal),
            _kpiCard('Postos', '${kpis["n_postos"] ?? 0}', Icons.local_gas_station, Colors.green),
            _kpiCard('Preco Medio', fmt.format(kpis['preco_medio'] ?? 0), Icons.price_change, Colors.orange),
            _kpiCard('Media/Veic', fmt.format((kpis['total_gasto'] ?? 0) / (kpis['n_veiculos'] ?? 1)), Icons.analytics, Colors.purple),
            _kpiCard('Litros/Abast', '${((kpis["total_litros"] ?? 0) / (kpis["n_abastecimentos"] ?? 1)).toStringAsFixed(0)} L', Icons.water_drop, Colors.cyan),
          ],
        ),
        const SizedBox(height: 24),

        // Gráfico evolução
        if (evolucao.isNotEmpty) ...[
          _secao('Evolucao diaria de gastos'),
          SizedBox(height: 200, child: _graficoBarras(evolucao, fmt)),
          const SizedBox(height: 24),
        ],

        // Por combustível
        if (porComb.isNotEmpty) ...[
          _secao('Por combustivel'),
          ...porComb.map((c) => _barraHorizontal(
            c['item_nome'] ?? '-',
            (c['gasto'] as num? ?? 0).toDouble(),
            (kpis['total_gasto'] as num? ?? 1).toDouble(),
            fmt,
            '${(c["litros"] ?? 0).toStringAsFixed(0)} L · ${c["n"]} abast. · ${fmt.format(c["preco_medio"] ?? 0)}/L',
            const Color(0xFF1565C0),
          )),
        ],
      ]),
    );
  }

  // ── ABA VEÍCULOS ─────────────────────────────────────────────────
  Widget _buildVeiculos(NumberFormat fmt, List dados, Map kpis) {
    if (dados.isEmpty) return const Center(child: Text('Nenhum dado disponivel'));
    final total = (kpis['total_gasto'] as num? ?? 1).toDouble();
    return ListView(padding: const EdgeInsets.all(16), children: [
      _secao('Top veiculos por gasto (${dados.length})'),
      // Gráfico horizontal
      ...dados.asMap().entries.map((e) {
        final v = e.value;
        final gasto = (v['gasto'] as num? ?? 0).toDouble();
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2D6B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: Text('${e.key+1}',
                    style: const TextStyle(color: Color(0xFF0D2D6B), fontWeight: FontWeight.bold, fontSize: 12))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(v['veiculo_placa'] ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              Text(fmt.format(gasto),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D2D6B), fontSize: 14)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
              value: total > 0 ? gasto / total : 0,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation(Color(0xFF1565C0)),
              minHeight: 6,
            )),
            const SizedBox(height: 6),
            Row(children: [
              _tag('${(v["litros"] ?? 0).toStringAsFixed(0)} L', Colors.blue),
              const SizedBox(width: 6),
              _tag('${v["n"]} abast.', Colors.teal),
              const SizedBox(width: 6),
              if ((v["hodometro_max"] as num? ?? 0) > 0)
                _tag('${NumberFormat('#,##0').format(v["hodometro_max"])} km', Colors.orange),
              const Spacer(),
              Text('${(gasto/total*100).toStringAsFixed(1)}% do total',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ]),
          ]),
        );
      }),
    ]);
  }

  // ── ABA MOTORISTAS ───────────────────────────────────────────────
  Widget _buildMotoristas(NumberFormat fmt, List dados, Map kpis) {
    if (dados.isEmpty) return const Center(child: Text('Nenhum motorista identificado'));
    final total = (kpis['total_gasto'] as num? ?? 1).toDouble();
    return ListView(padding: const EdgeInsets.all(16), children: [
      _secao('Top motoristas por gasto (${dados.length})'),
      ...dados.asMap().entries.map((e) {
        final m = e.value;
        final gasto = (m['gasto'] as num? ?? 0).toDouble();
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                radius: 16, backgroundColor: Colors.teal.withOpacity(0.1),
                child: Text('${e.key+1}', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(m['motorista_nome'] ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              Text(fmt.format(gasto),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 13)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
              value: total > 0 ? gasto / total : 0,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation(Colors.teal),
              minHeight: 6,
            )),
            const SizedBox(height: 6),
            Row(children: [
              _tag('${(m["litros"] ?? 0).toStringAsFixed(0)} L', Colors.blue),
              const SizedBox(width: 6),
              _tag('${m["n"]} abast.', Colors.teal),
              const SizedBox(width: 6),
              _tag('${m["n_veiculos"]} veic.', Colors.orange),
            ]),
          ]),
        );
      }),
    ]);
  }

  // ── ABA POSTOS ───────────────────────────────────────────────────
  Widget _buildPostos(NumberFormat fmt, List dados, Map kpis) {
    if (dados.isEmpty) return const Center(child: Text('Nenhum posto encontrado'));
    final total = (kpis['total_gasto'] as num? ?? 1).toDouble();
    return ListView(padding: const EdgeInsets.all(16), children: [
      _secao('Top postos por gasto (${dados.length})'),
      ...dados.asMap().entries.map((e) {
        final p = e.value;
        final gasto = (p['gasto'] as num? ?? 0).toDouble();
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                radius: 16, backgroundColor: Colors.green.withOpacity(0.1),
                child: Text('${e.key+1}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['pv_razao_social'] ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('${p["pv_municipio"] ?? "-"}/${p["pv_uf"] ?? "-"}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ])),
              Text(fmt.format(gasto),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
              value: total > 0 ? gasto / total : 0,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation(Colors.green),
              minHeight: 6,
            )),
            const SizedBox(height: 6),
            Row(children: [
              _tag('${(p["litros"] ?? 0).toStringAsFixed(0)} L', Colors.blue),
              const SizedBox(width: 6),
              _tag('${p["n"]} abast.', Colors.green),
              const SizedBox(width: 6),
              _tag(fmt.format(p["preco_medio"] ?? 0) + '/L', Colors.orange),
            ]),
          ]),
        );
      }),
    ]);
  }

  // ── ABA UFS ──────────────────────────────────────────────────────
  Widget _buildUfs(NumberFormat fmt, List dados, Map kpis) {
    if (dados.isEmpty) return const Center(child: Text('Nenhum dado disponivel'));
    final total = (kpis['total_gasto'] as num? ?? 1).toDouble();
    return ListView(padding: const EdgeInsets.all(16), children: [
      _secao('Distribuicao por estado'),
      if (dados.length >= 2) ...[
        SizedBox(height: 220, child: Row(children: [
          Expanded(child: PieChart(PieChartData(
            sections: dados.take(6).toList().asMap().entries.map((e) {
              final cores = [const Color(0xFF1565C0), Colors.teal, Colors.green,
                  Colors.orange, Colors.purple, Colors.red];
              final gasto = (e.value['gasto'] as num? ?? 0).toDouble();
              return PieChartSectionData(
                value: gasto, title: e.value['pv_uf'] ?? '-',
                color: cores[e.key % cores.length], radius: 70,
                titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              );
            }).toList(),
            centerSpaceRadius: 35, sectionsSpace: 2,
          ))),
          const SizedBox(width: 8),
          Column(mainAxisAlignment: MainAxisAlignment.center,
              children: dados.take(6).toList().asMap().entries.map((e) {
            final cores = [const Color(0xFF1565C0), Colors.teal, Colors.green,
                Colors.orange, Colors.purple, Colors.red];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(
                    color: cores[e.key % cores.length], borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                Text('${e.value["pv_uf"]} — ${fmt.format(e.value["gasto"] ?? 0)}',
                    style: const TextStyle(fontSize: 11)),
              ]),
            );
          }).toList()),
        ])),
        const SizedBox(height: 16),
      ],
      ...dados.asMap().entries.map((e) {
        final u = e.value;
        final gasto = (u['gasto'] as num? ?? 0).toDouble();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              SizedBox(width: 32, child: Text(u['pv_uf'] ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              const SizedBox(width: 8),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0 ? gasto / total : 0,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF1565C0)),
                    minHeight: 20,
                  ))),
              const SizedBox(width: 8),
              Text(fmt.format(gasto),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D2D6B), fontSize: 12)),
            ]),
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 2),
              child: Text('${(u["litros"] ?? 0).toStringAsFixed(0)} L · ${u["n"]} abast.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ),
          ]),
        );
      }),
    ]);
  }

  // ── WIDGETS HELPERS ──────────────────────────────────────────────
  Widget _secao(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D2D6B))),
  );

  Widget _metrica(String valor, String label) => Column(children: [
    Text(valor, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
  ]);

  Widget _kpiCard(String label, String value, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600]), textAlign: TextAlign.center),
    ]),
  );

  Widget _tag(String texto, Color cor) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
    child: Text(texto, style: TextStyle(fontSize: 10, color: cor, fontWeight: FontWeight.w500)),
  );

  Widget _graficoBarras(List dados, NumberFormat fmt) {
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
          width: 10, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
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
            return Text((dados[idx]['dia'] as String? ?? '').substring(8),
                style: const TextStyle(fontSize: 9));
          },
        )),
      ),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.withOpacity(0.15), strokeWidth: 1)),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (_, __, rod, ___) => BarTooltipItem(
            fmt.format(rod.toY), const TextStyle(color: Colors.white, fontSize: 11)),
        ),
      ),
    ));
  }

  Widget _barraHorizontal(String label, double valor, double total, NumberFormat fmt, String sub, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          Text(fmt.format(valor), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
          value: total > 0 ? valor / total : 0,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation(color), minHeight: 8,
        )),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ]),
    );
  }
}
