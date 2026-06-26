import 'package:flutter/material.dart';
import '../../../core/widgets/menu_button.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';

class PrecosScreen extends StatefulWidget {
  const PrecosScreen({super.key});
  @override State<PrecosScreen> createState() => _State();
}

class _State extends State<PrecosScreen> {
  Map<String, dynamic>? _dados;
  bool _loading = true;
  int _dias = 90;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService().get('/precos/variacao', params: {'dias': _dias});
      setState(() => _dados = r);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmtP = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final porComb = (_dados?['por_combustivel'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(),
        title: const Text('Variacao de Precos'),
        actions: [
          DropdownButton<int>(
            value: _dias,
            dropdownColor: Colors.white,
            items: [30,60,90,180].map((d) => DropdownMenuItem(value: d, child: Text('$d dias'))).toList(),
            onChanged: (v) { setState(() => _dias = v!); _load(); },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (porComb.isEmpty)
                  const Center(child: Text('Sem dados para o periodo'))
                else ...[
                  const Text('Por combustivel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...porComb.map((c) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(padding: const EdgeInsets.all(14), child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c['item_nome'] ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 8),
                        Row(children: [
                          _precoBadge('Medio', c['preco_medio'] ?? 0, Colors.blue, fmtP),
                          const SizedBox(width: 8),
                          _precoBadge('Min', c['preco_min'] ?? 0, Colors.green, fmtP),
                          const SizedBox(width: 8),
                          _precoBadge('Max', c['preco_max'] ?? 0, Colors.red, fmtP),
                        ]),
                        const SizedBox(height: 6),
                        Text('${c["n"]} abastecimentos',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    )),
                  )),
                ],
              ],
            )),
    );
  }

  Widget _precoBadge(String label, num value, Color color, NumberFormat fmt) => Expanded(
    child: Column(children: [
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      Text(fmt.format(value), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
    ]),
  );
}
