import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});
  @override State<TicketsScreen> createState() => _State();
}

class _State extends State<TicketsScreen> {
  List<dynamic> _tickets = [];
  bool _loading = true;

  final _cores = {'aberto': Colors.red, 'em_analise': Colors.orange,
                  'resolvido': Colors.green, 'fechado': Colors.grey};

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService().get(ApiConstants.tickets);
      setState(() => _tickets = r['data'] ?? []);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: ${e}')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Suporte')),
    floatingActionButton: FloatingActionButton(
      onPressed: _novoTicket, child: const Icon(Icons.add)),
    body: _loading ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(onRefresh: _load, child: _tickets.isEmpty
            ? const Center(child: Text('Nenhum ticket'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _tickets.length,
                itemBuilder: (_, i) {
                  final t = _tickets[i];
                  final cor = _cores[t['status']] ?? Colors.grey;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: cor.withOpacity(0.15),
                          child: Icon(Icons.confirmation_number, color: cor)),
                      title: Text(t['titulo'] ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(t['descricao'] ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Chip(
                        label: Text(t['status'] ?? '-',
                            style: const TextStyle(fontSize: 11, color: Colors.white)),
                        backgroundColor: cor,
                      ),
                    ),
                  );
                },
              )),
  );

  Future<void> _novoTicket() async {
    final titulo    = TextEditingController();
    final descricao = TextEditingController();
    await showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Novo Ticket'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: titulo, decoration: const InputDecoration(labelText: 'Titulo')),
        const SizedBox(height: 12),
        TextField(controller: descricao, decoration: const InputDecoration(labelText: 'Descricao'), maxLines: 3),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () async {
            await ApiService().post(ApiConstants.tickets,
                data: {'titulo': titulo.text, 'descricao': descricao.text});
            if (mounted) { Navigator.pop(context); _load(); }
          },
          child: const Text('Enviar'),
        ),
      ],
    ));
  }
}