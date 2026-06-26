import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/menu_button.dart';

class RoteirizacaoScreen extends StatefulWidget {
  const RoteirizacaoScreen({super.key});
  @override State<RoteirizacaoScreen> createState() => _State();
}

class _State extends State<RoteirizacaoScreen> {
  List<dynamic> _postos = [];
  List<String> _ufs = [];
  bool _loading = false;
  String? _ufSelecionada;
  final _municipioCtrl = TextEditingController();

  @override void initState() { super.initState(); _carregarUfs(); }

  Future<void> _carregarUfs() async {
    try {
      final r = await ApiService().get('/roteirizacao/ufs');
      setState(() => _ufs = List<String>.from(r['data'] ?? []));
    } catch (_) {}
  }

  Future<void> _buscar() async {
    setState(() { _loading = true; _postos = []; });
    try {
      final params = <String, dynamic>{};
      if (_ufSelecionada != null) params['uf'] = _ufSelecionada;
      if (_municipioCtrl.text.isNotEmpty) params['municipio'] = _municipioCtrl.text;
      final r = await ApiService().get('/roteirizacao/postos', params: params);
      setState(() => _postos = r['data'] ?? []);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: const Text('Roteirizacao')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _ufSelecionada,
                hint: const Text('Selecione UF'),
                items: _ufs.map((uf) => DropdownMenuItem(value: uf, child: Text(uf))).toList(),
                onChanged: (v) => setState(() => _ufSelecionada = v),
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _municipioCtrl,
                decoration: const InputDecoration(
                  labelText: 'Municipio',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _buscar,
              icon: const Icon(Icons.search),
              label: Text(_loading ? 'Buscando...' : 'Buscar Postos'),
            )),
        ])),
        if (_loading) const LinearProgressIndicator(),
        Expanded(child: _postos.isEmpty
            ? const Center(child: Text('Selecione UF ou municipio para buscar'))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _postos.length,
                itemBuilder: (_, i) {
                  final p = _postos[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE3F2FD),
                        child: Icon(Icons.local_gas_station, color: Colors.blue),
                      ),
                      title: Text(p['razao_social'] ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('${p["municipio"] ?? "-"}/${p["uf"] ?? "-"}'),
                      trailing: p['combustiveis'] != null
                          ? Text(p['combustiveis'].toString(),
                              style: const TextStyle(fontSize: 11, color: Colors.grey))
                          : null,
                    ),
                  );
                })),
      ]),
    );
  }
}
