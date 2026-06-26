import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/menu_button.dart';

class AcordosScreen extends StatefulWidget {
  const AcordosScreen({super.key});
  @override State<AcordosScreen> createState() => _State();
}

class _State extends State<AcordosScreen> {
  List<dynamic> _dados = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService().get('/acordos');
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
      appBar: AppBar(leading: const MenuButton(), title: const Text('Acordos de Preco')),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: _dados.isEmpty
              ? const Center(child: Text('Nenhum acordo cadastrado'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _dados.length,
                  itemBuilder: (_, i) {
                    final a = _dados[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE8F5E9),
                          child: Icon(Icons.handshake, color: Colors.green),
                        ),
                        title: Text(a['razao_social'] ?? a['cnpj_posto'] ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${a["municipio"] ?? "-"}/${a["uf"] ?? "-"}\n'
                            'Valido: ${a["data_inicio"] ?? "-"} ate ${a["data_fim"] ?? "-"}'),
                        isThreeLine: true,
                        trailing: Text(
                          a['preco_acordado'] != null ? fmt.format(a['preco_acordado']) : '-',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ),
                    );
                  },
                )),
    );
  }
}
