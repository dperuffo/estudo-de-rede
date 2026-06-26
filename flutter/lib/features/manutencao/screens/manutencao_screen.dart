import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';

class ManutencaoScreen extends StatefulWidget {
  const ManutencaoScreen({super.key});
  @override State<ManutencaoScreen> createState() => _State();
}

class _State extends State<ManutencaoScreen> {
  Map<String, dynamic>? _resumo;
  List<dynamic> _lista = [];
  bool _loading = true;
  int _dias = 30;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ApiService();
      final resumo = await api.get('/manutencao/resumo', params: {'dias': _dias});
      final lista  = await api.get('/manutencao', params: {'limit': 20});
      setState(() { _resumo = resumo; _lista = lista['data'] ?? []; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manutenção'),
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
                if (_resumo != null) ...[
                  Row(children: [
                    _kpi('Total Gasto', fmt.format(_resumo!['total_gasto'] ?? 0), Colors.red),
                    const SizedBox(width: 12),
                    _kpi('Registros', '${_resumo!["n_registros"] ?? 0}', Colors.orange),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    _kpi('Veículos', '${_resumo!["n_veiculos"] ?? 0}', Colors.blue),
                    const SizedBox(width: 12),
                    _kpi('Período', '$_dias dias', Colors.grey),
                  ]),
                  const SizedBox(height: 24),
                  if ((_resumo!['por_oficina'] as List?)?.isNotEmpty == true) ...[
                    const Text('Por oficina', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...(_resumo!['por_oficina'] as List).map((o) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        Expanded(child: Text(o['oficina'] ?? '-')),
                        Text(fmt.format(o['total'] ?? 0),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                        const SizedBox(width: 8),
                        Text('(${o["n"]}x)', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ]),
                    )),
                    const SizedBox(height: 16),
                  ],
                ],
                const Text('Últimas manutenções', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ..._lista.map((m) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFFEBEE),
                      child: Icon(Icons.build, color: Colors.red),
                    ),
                    title: Text('${m["placa"] ?? "-"} — ${m["oficina"] ?? "-"}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(m['itens_realizados'] is List
                        ? (m['itens_realizados'] as List).join(', ')
                        : (m['itens_realizados'] ?? m['obs_gerais'] ?? '-'),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: Text(fmt.format(m['custo_total'] ?? 0),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  ),
                )),
              ],
            )),
    );
  }

  Widget _kpi(String label, String value, Color color) => Expanded(
    child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    ))),
  );
}
