import 'package:flutter/material.dart';
import '../../../core/widgets/veiculo_detalhe_modal.dart';
import '../../../core/widgets/menu_button.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/abastecimento_detalhe_modal.dart';

class RelatoriosScreen extends StatefulWidget {
  const RelatoriosScreen({super.key});
  @override State<RelatoriosScreen> createState() => _State();
}

class _State extends State<RelatoriosScreen> {
  List<dynamic> _dados = [];
  bool _loading = false;
  int _dias = 30;
  final _placaCtrl = TextEditingController();
  final _ufCtrl    = TextEditingController();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final params = <String, dynamic>{'dias': _dias};
      if (_placaCtrl.text.isNotEmpty) params['placa'] = _placaCtrl.text;
      if (_ufCtrl.text.isNotEmpty)    params['uf']    = _ufCtrl.text;
      final r = await ApiService().get('/relatorios/abastecimentos', params: params);
      setState(() => _dados = r['data'] ?? []);
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
      appBar: AppBar(leading: const MenuButton(),title: const Text('Relatorios')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          Row(children: [
            Expanded(child: TextField(
              controller: _placaCtrl,
              decoration: const InputDecoration(labelText: 'Placa', border: OutlineInputBorder(), isDense: true),
              textCapitalization: TextCapitalization.characters,
            )),
            const SizedBox(width: 8),
            Expanded(child: TextField(
              controller: _ufCtrl,
              decoration: const InputDecoration(labelText: 'UF', border: OutlineInputBorder(), isDense: true),
              textCapitalization: TextCapitalization.characters,
            )),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: _dias,
              items: [7,15,30,60,90].map((d) => DropdownMenuItem(value: d, child: Text('${d}d'))).toList(),
              onChanged: (v) => setState(() => _dias = v!),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.search),
              label: Text(_loading ? 'Buscando...' : 'Buscar'),
            )),
        ])),
        if (_loading) const LinearProgressIndicator(),
        Expanded(child: _dados.isEmpty
            ? const Center(child: Text('Use os filtros acima para buscar'))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _dados.length,
                itemBuilder: (_, i) {
                  final a = _dados[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.local_gas_station, color: Colors.blue),
                      title: Text('${a["veiculo_placa"] ?? "-"} — ${a["item_nome"] ?? "-"}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('${a["data_abastecimento"] ?? "-"} · ${a["pv_municipio"] ?? "-"}/${a["pv_uf"] ?? "-"}'),
                      trailing: Text(fmt.format(a['item_valor_total'] ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)),
                    ),
                  );
                })),
      ]),
    );
  }
}
