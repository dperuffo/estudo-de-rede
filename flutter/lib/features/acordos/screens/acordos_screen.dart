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

  Future<void> _deletar(String id) async {
    final ok = await showDialog<bool>(context: context, builder: (dialogCtx) => AlertDialog(
      title: const Text('Confirmar exclusao'),
      content: const Text('Deseja desativar este acordo?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Desativar', style: TextStyle(color: Colors.white))),
      ],
    ));
    if (ok != true) return;
    try {
      await ApiService().delete('/acordos/$id');
      setState(() => _dados.removeWhere((a) => a['id'].toString() == id));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acordo desativado com sucesso')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  Future<void> _novoOuEditar([Map? dados]) async {
    final cnpjCtrl    = TextEditingController(text: dados?['cnpj_posto'] ?? '');
    final nomeCtrl    = TextEditingController(text: dados?['nome_posto'] ?? '');
    final combCtrl    = TextEditingController(text: dados?['combustivel'] ?? '');
    final precoCtrl   = TextEditingController(text: dados?['preco_negociado']?.toString() ?? '');
    final inicioCtrl  = TextEditingController(text: dados?['dt_vigencia_inicio'] ?? '');
    final fimCtrl     = TextEditingController(text: dados?['dt_vigencia_fim'] ?? '');

    await showDialog(context: context, builder: (_) => AlertDialog(
      title: Text(dados == null ? 'Novo Acordo' : 'Editar Acordo'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: cnpjCtrl,   decoration: const InputDecoration(labelText: 'CNPJ do Posto *')),
        TextField(controller: nomeCtrl,   decoration: const InputDecoration(labelText: 'Nome do Posto')),
        TextField(controller: combCtrl,   decoration: const InputDecoration(labelText: 'Combustivel *')),
        TextField(controller: precoCtrl,  decoration: const InputDecoration(labelText: 'Preco Negociado (R\$)'), keyboardType: TextInputType.number),
        TextField(controller: inicioCtrl, decoration: const InputDecoration(labelText: 'Inicio vigencia (YYYY-MM-DD)')),
        TextField(controller: fimCtrl,    decoration: const InputDecoration(labelText: 'Fim vigencia (YYYY-MM-DD)')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () async {
            try {
              final body = {
                'cnpj_posto': cnpjCtrl.text.replaceAll(RegExp(r'\D'), ''),
                'nome_posto': nomeCtrl.text.trim(),
                'combustivel': combCtrl.text.trim(),
                'preco_negociado': double.tryParse(precoCtrl.text.replaceAll(',', '.')) ?? 0,
                'dt_vigencia_inicio': inicioCtrl.text.trim(),
                'dt_vigencia_fim': fimCtrl.text.trim(),
              };
              if (dados == null) {
                await ApiService().post('/acordos', data: body);
              } else {
                await ApiService().put('/acordos/${dados["id"]}', data: body);
              }
              Navigator.pop(context, true);
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
            }
          },
          child: Text(dados == null ? 'Criar' : 'Salvar'),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: const Text('Acordos de Preco')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _novoOuEditar(),
        child: const Icon(Icons.add),
      ),
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
                        leading: const CircleAvatar(backgroundColor: Color(0xFFE8F5E9),
                            child: Icon(Icons.handshake, color: Colors.green)),
                        title: Text(a['nome_posto'] ?? a['cnpj_posto'] ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${a["combustivel"] ?? "-"}\n'
                            '${a["dt_vigencia_inicio"] ?? "-"} ate ${a["dt_vigencia_fim"] ?? "-"}'),
                        isThreeLine: true,
                        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(a['preco_negociado'] != null ? fmt.format(a['preco_negociado']) : '-',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12)),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                onPressed: () => _novoOuEditar(a), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                            IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                onPressed: () => _deletar(a['id'].toString()), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                          ]),
                        ]),
                      ),
                    );
                  },
                )),
    );
  }
}
