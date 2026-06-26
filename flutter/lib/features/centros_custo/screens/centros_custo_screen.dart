import 'package:flutter/material.dart';
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

  Future<void> _deletar(String id) async {
    final ok = await showDialog<bool>(context: context, builder: (dialogCtx) => AlertDialog(
      title: const Text('Confirmar exclusao'),
      content: const Text('Deseja excluir este centro de custo?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir', style: TextStyle(color: Colors.white))),
      ],
    ));
    if (ok != true) return;
    try {
      await ApiService().delete('/centros-custo/$id');
      setState(() => _dados.removeWhere((c) => c['id'].toString() == id));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Centro de custo excluido com sucesso')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  Future<void> _novoOuEditar([Map? dados]) async {
    final nomeCtrl        = TextEditingController(text: dados?['nome'] ?? '');
    final codigoCtrl      = TextEditingController(text: dados?['codigo'] ?? '');
    final descricaoCtrl   = TextEditingController(text: dados?['descricao'] ?? '');
    final responsavelCtrl = TextEditingController(text: dados?['responsavel'] ?? '');

    await showDialog(context: context, builder: (_) => AlertDialog(
      title: Text(dados == null ? 'Novo Centro de Custo' : 'Editar Centro de Custo'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nomeCtrl,        decoration: const InputDecoration(labelText: 'Nome *')),
        TextField(controller: codigoCtrl,      decoration: const InputDecoration(labelText: 'Codigo')),
        TextField(controller: descricaoCtrl,   decoration: const InputDecoration(labelText: 'Descricao')),
        TextField(controller: responsavelCtrl, decoration: const InputDecoration(labelText: 'Responsavel')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () async {
            if (nomeCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nome obrigatorio')));
              return;
            }
            try {
              final body = {
                'nome': nomeCtrl.text.trim(),
                'codigo': codigoCtrl.text.trim(),
                'descricao': descricaoCtrl.text.trim(),
                'responsavel': responsavelCtrl.text.trim(),
                'ativo': true,
              };
              if (dados == null) {
                await ApiService().post('/centros-custo', data: body);
              } else {
                await ApiService().put('/centros-custo/${dados["id"]}', data: body);
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
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: const Text('Centros de Custo')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _novoOuEditar(),
        child: const Icon(Icons.add),
      ),
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
                        leading: const CircleAvatar(backgroundColor: Color(0xFFF3E5F5),
                            child: Icon(Icons.business, color: Colors.purple)),
                        title: Text(c['nome'] ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${c["codigo"] ?? "-"} · ${c["responsavel"] ?? "-"}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _novoOuEditar(c)),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deletar(c['id'].toString())),
                        ]),
                      ),
                    );
                  },
                )),
    );
  }
}
