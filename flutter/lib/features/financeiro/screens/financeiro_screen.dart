import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';

class FinanceiroScreen extends StatefulWidget {
  const FinanceiroScreen({super.key});
  @override State<FinanceiroScreen> createState() => _State();
}

class _State extends State<FinanceiroScreen> {
  Map<String, dynamic>? _dados;
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService().get(ApiConstants.financeiroResumo);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Painel Financeiro')),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_dados != null) ...[
                  Card(
                    color: const Color(0xFF0D2D6B),
                    child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
                      const Text('Total Geral', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(fmt.format(_dados!['total_geral'] ?? 0),
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                      Text('${_dados!["periodo"]?["inicio"]} - ${_dados!["periodo"]?["fim"]}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ])),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    _card('Combustivel', fmt.format(_dados!['combustivel']?['total_gasto'] ?? 0),
                        '${(_dados!["combustivel"]?["total_litros"] ?? 0).toStringAsFixed(0)} L', Colors.blue),
                    const SizedBox(width: 12),
                    _card('Manutencao', fmt.format(_dados!['manutencao']?['total_gasto'] ?? 0),
                        '${_dados!["manutencao"]?["n_registros"]} registros', Colors.orange),
                  ]),
                ],
              ],
            )),
    );
  }

  Widget _card(String t, String v, String s, Color c) => Expanded(
    child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 6),
        Text(v, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c)),
        Text(s, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    ))),
  );
}
