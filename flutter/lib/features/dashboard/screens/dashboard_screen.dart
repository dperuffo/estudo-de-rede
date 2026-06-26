import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';

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
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final ab = _dados?['abastecimentos'] as Map? ?? {};
    final mn = _dados?['manutencao'] as Map? ?? {};
    final topV = (_dados?['top_veiculos'] as List?) ?? [];
    final topU = (_dados?['top_ufs'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            final scaffold = context.findAncestorStateOfType<ScaffoldState>();
            scaffold?.openDrawer();
          },
        ),
        title: const Text('Dashboard'),
        actions: [
          DropdownButton<int>(
            value: _dias,
            dropdownColor: Colors.white,
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
                Card(
                  color: const Color(0xFF0D2D6B),
                  child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                    const Text('Total Geral', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(fmt.format(_dados?['total_geral'] ?? 0),
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                    Text('Combustivel + Manutencao — $_dias dias',
                        style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ])),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  _kpi('Litros', '${(ab['total_litros'] ?? 0).toStringAsFixed(0)} L', Colors.blue),
                  const SizedBox(width: 8),
                  _kpi('Combustivel', fmt.format(ab['total_gasto'] ?? 0), Colors.green),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _kpi('Veiculos', '${ab['n_veiculos'] ?? 0}', Colors.orange),
                  const SizedBox(width: 8),
                  _kpi('Abastec.', '${ab['n_registros'] ?? 0}', Colors.purple),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _kpi('UFs', '${ab['n_ufs'] ?? 0}', Colors.teal),
                  const SizedBox(width: 8),
                  _kpi('Manutencao', fmt.format(mn['total_gasto'] ?? 0), Colors.red),
                ]),
                const SizedBox(height: 24),
                if (topV.isNotEmpty) ...[
                  const Text('Top veiculos por gasto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...topV.map((v) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      const Icon(Icons.directions_car, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(child: Text(v['veiculo_placa'] ?? '-')),
                      Text(fmt.format(v['gasto'] ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    ]),
                  )),
                  const SizedBox(height: 16),
                ],
                if (topU.isNotEmpty) ...[
                  const Text('Top estados por gasto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...topU.map((u) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(child: Text(u['pv_uf'] ?? '-')),
                      Text(fmt.format(u['gasto'] ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    ]),
                  )),
                ],
              ],
            )),
    );
  }

  Widget _kpi(String label, String value, Color color) => Expanded(
    child: Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    ))),
  );
}
