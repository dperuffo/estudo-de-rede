import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';

class InteligenciaScreen extends StatefulWidget {
  const InteligenciaScreen({super.key});
  @override State<InteligenciaScreen> createState() => _State();
}

class _State extends State<InteligenciaScreen> {
  Map<String, dynamic>? _dados;
  bool _loading = true;
  int _dias = 90;
  int _tabIndex = 0;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService().get('/inteligencia/resumo', params: {'dias': _dias});
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
    final porUf  = (_dados?['por_uf']  as List?) ?? [];
    final porMun = (_dados?['por_municipio'] as List?) ?? [];
    final porVei = (_dados?['por_veiculo'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inteligência'),
        actions: [
          DropdownButton<int>(
            value: _dias,
            dropdownColor: Colors.white,
            items: [30,60,90,180,365].map((d) => DropdownMenuItem(value: d, child: Text('$d dias'))).toList(),
            onChanged: (v) { setState(() => _dias = v!); _load(); },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(children: [
            _tab('Por UF', 0),
            _tab('Por Município', 1),
            _tab('Por Veículo', 2),
          ]),
        ),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: Builder(builder: (_) {
              final lista = _tabIndex == 0 ? porUf : _tabIndex == 1 ? porMun : porVei;
              final keyField = _tabIndex == 0 ? 'pv_uf' : _tabIndex == 1 ? 'pv_municipio' : 'veiculo_placa';
              if (lista.isEmpty) return const Center(child: Text('Sem dados para o período'));
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: lista.length,
                itemBuilder: (_, i) {
                  final item = lista[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFE3F2FD),
                        child: Text('${i+1}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(item[keyField]?.toString() ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${(item["litros"] ?? 0).toStringAsFixed(0)} L · ${item["n"]} abast.'),
                      trailing: Text(fmt.format(item['gasto'] ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    ),
                  );
                },
              );
            })),
    );
  }

  Widget _tab(String label, int idx) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() => _tabIndex = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(
            color: _tabIndex == idx ? Colors.white : Colors.transparent, width: 2)),
        ),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(color: _tabIndex == idx ? Colors.white : Colors.white60, fontSize: 13)),
      ),
    ),
  );
}
