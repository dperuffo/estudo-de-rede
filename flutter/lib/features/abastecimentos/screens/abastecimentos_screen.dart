import 'package:flutter/material.dart';
import '../../../core/widgets/menu_button.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/abastecimento_detalhe_modal.dart';
import '../../../core/constants/api_constants.dart';

class AbastecimentosScreen extends StatefulWidget {
  const AbastecimentosScreen({super.key});
  @override State<AbastecimentosScreen> createState() => _State();
}

class _State extends State<AbastecimentosScreen> {
  Map<String, dynamic>? _resumo;
  List<dynamic> _lista = [];
  bool _loading = true;
  int _dias = 30;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ApiService();
      final resumo = await api.get(ApiConstants.abastecimentosResumo, params: {'dias': _dias});
      final lista  = await api.get(ApiConstants.abastecimentos, params: {'dias': _dias, 'limit': 20});
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
      appBar: AppBar(leading: const MenuButton(),
        title: const Text('Abastecimentos'),
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
                if (_resumo != null) ...[
                  Row(children: [
                    _kpi('Litros', '${(_resumo!["total_litros"] ?? 0).toStringAsFixed(0)} L', Colors.blue),
                    const SizedBox(width: 12),
                    _kpi('Gasto', fmt.format(_resumo!['total_gasto'] ?? 0), Colors.green),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    _kpi('Veiculos', '${_resumo!["n_veiculos"]}', Colors.orange),
                    const SizedBox(width: 12),
                    _kpi('Media/dia', '${(_resumo!["media_dia"] ?? 0).toStringAsFixed(0)} L', Colors.purple),
                  ]),
                  const SizedBox(height: 24),
                ],
                const Text('Ultimos abastecimentos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ..._lista.map((a) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.local_gas_station)),
                    title: Text('${a["veiculo_placa"] ?? "-"} - ${a["item_nome"] ?? "-"}'),
                    subtitle: Text(a['pv_razao_social'] ?? '-'),
                    trailing: Text('${(a["item_quantidade"] ?? 0).toStringAsFixed(0)} L',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () => AbastecimentoDetalheModal.show(context, a),
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
