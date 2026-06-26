import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/menu_button.dart';

class ManutencaoScreen extends StatefulWidget {
  const ManutencaoScreen({super.key});
  @override State<ManutencaoScreen> createState() => _State();
}

class _State extends State<ManutencaoScreen> {
  Map<String, dynamic>? _resumo;
  List<dynamic> _lista = [];
  bool _loading = true;
  int _dias = 30;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ApiService();
      final resumo = await api.get('/manutencao/resumo', params: {'dias': _dias});
      final lista  = await api.get('/manutencao', params: {'limit': 50});
      setState(() { _resumo = resumo; _lista = lista['data'] ?? []; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deletar(int id) async {
    final ok = await showDialog<bool>(context: context, builder: (dialogCtx) => AlertDialog(
      title: const Text('Confirmar exclusao'),
      content: const Text('Deseja excluir este registro de manutencao?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir', style: TextStyle(color: Colors.white))),
      ],
    ));
    if (ok != true) return;
    try {
      await ApiService().delete('/manutencao/$id');
      setState(() => _lista.removeWhere((m) => m['id'] == id));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro excluido com sucesso')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  Future<void> _novoOuEditar([Map? dados]) async {
    final placaCtrl    = TextEditingController(text: dados?['placa'] ?? '');
    final oficinaCtr   = TextEditingController(text: dados?['oficina'] ?? '');
    final tecnicoCtrl  = TextEditingController(text: dados?['tecnico'] ?? '');
    final custoCtrl    = TextEditingController(text: dados?['custo_total']?.toString() ?? '');
    final obsCtrl      = TextEditingController(text: dados?['obs_gerais'] ?? '');
    final dataCtrl     = TextEditingController(text: dados?['data_manutencao'] ?? DateTime.now().toIso8601String().substring(0,10));

    await showDialog(context: context, builder: (dialogCtx) => AlertDialog(
      title: Text(dados == null ? 'Nova Manutencao' : 'Editar Manutencao'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: placaCtrl,   decoration: const InputDecoration(labelText: 'Placa'), textCapitalization: TextCapitalization.characters),
        TextField(controller: oficinaCtr,  decoration: const InputDecoration(labelText: 'Oficina')),
        TextField(controller: tecnicoCtrl, decoration: const InputDecoration(labelText: 'Tecnico')),
        TextField(controller: custoCtrl,   decoration: const InputDecoration(labelText: 'Custo Total (R\$)'), keyboardType: TextInputType.number),
        TextField(controller: dataCtrl,    decoration: const InputDecoration(labelText: 'Data (YYYY-MM-DD)')),
        TextField(controller: obsCtrl,     decoration: const InputDecoration(labelText: 'Observacoes'), maxLines: 3),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () async {
            try {
              final body = {
                'placa': placaCtrl.text.toUpperCase().trim(),
                'oficina': oficinaCtr.text.trim(),
                'tecnico': tecnicoCtrl.text.trim(),
                'custo_total': double.tryParse(custoCtrl.text.replaceAll(',','.')) ?? 0,
                'data_manutencao': dataCtrl.text.trim(),
                'obs_gerais': obsCtrl.text.trim(),
              };
              if (dados == null) {
                await ApiService().post('/manutencao', data: body);
              } else {
                await ApiService().put('/manutencao/${dados["id"]}', data: body);
              }
              Navigator.pop(dialogCtx, true);
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
      appBar: AppBar(leading: const MenuButton(), title: const Text('Manutencao'),
        actions: [
          DropdownButton<int>(
            value: _dias, dropdownColor: Colors.white,
            items: [7,15,30,60,90].map((d) => DropdownMenuItem(value: d, child: Text('$d dias'))).toList(),
            onChanged: (v) { setState(() => _dias = v!); _load(); },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _novoOuEditar(),
        child: const Icon(Icons.add),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_resumo != null) ...[
                  Row(children: [
                    _kpi('Total Gasto', fmt.format(_resumo!['total_gasto'] ?? 0), Colors.red),
                    const SizedBox(width: 8),
                    _kpi('Registros', '${_resumo!["n_registros"] ?? 0}', Colors.orange),
                    const SizedBox(width: 8),
                    _kpi('Veiculos', '${_resumo!["n_veiculos"] ?? 0}', Colors.blue),
                  ]),
                  const SizedBox(height: 16),
                ],
                const Text('Registros', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._lista.map((m) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0xFFFFEBEE),
                        child: Icon(Icons.build, color: Colors.red)),
                    title: Text('${m["placa"] ?? "-"} — ${m["oficina"] ?? "-"}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${m["data_manutencao"] ?? "-"}\n${m["obs_gerais"] ?? "-"}'),
                    isThreeLine: true,
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(fmt.format(m['custo_total'] ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 12)),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                            onPressed: () => _novoOuEditar(m), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                        IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                            onPressed: () => _deletar(m['id']), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                      ]),
                    ]),
                  ),
                )),
              ],
            )),
    );
  }

  Widget _kpi(String label, String value, Color color) => Expanded(
    child: Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    ))),
  );
}
