import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/menu_button.dart';

class CentrosCustoScreen extends StatefulWidget {
  const CentrosCustoScreen({super.key});
  @override State<CentrosCustoScreen> createState() => _State();
}

class _State extends State<CentrosCustoScreen> {
  List<dynamic> _dados = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService().get('/centros-custo');
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
      appBar: AppBar(leading: const MenuButton(), title: const Text('Centros de Custo')),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: _dados.isEmpty
              ? const Center(child: Text('Nenhum centro de custo cadastrado'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _dados.length,
                  itemBuilder: (_, i) {
                    final c = _dados[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFF3E5F5),
                          child: Icon(Icons.business, color: Colors.purple),
                        ),
                        title: Text(c['nome'] ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(c['descricao'] ?? c['codigo'] ?? '-'),
                        trailing: c['orcamento'] != null
                            ? Text(fmt.format(c['orcamento']),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple))
                            : null,
                      ),
                    );
                  },
                )),
    );
  }
}
