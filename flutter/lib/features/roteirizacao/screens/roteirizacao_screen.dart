import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/menu_button.dart';

class RoteirizacaoScreen extends StatefulWidget {
  const RoteirizacaoScreen({super.key});
  @override State<RoteirizacaoScreen> createState() => _State();
}

class _State extends State<RoteirizacaoScreen> {
  List<dynamic> _postos   = [];
  List<dynamic> _veiculos = [];
  List<String>  _ufs      = [];
  bool _loading           = false;
  String? _ufSelecionada;
  String? _veiculoSelecionado;
  final _municipioCtrl = TextEditingController();
  int _tabIndex = 0;

  @override void initState() { super.initState(); _carregarInicial(); }

  Future<void> _carregarInicial() async {
    try {
      final ufs = await ApiService().get('/roteirizacao/ufs');
      final veic = await ApiService().get('/roteirizacao/veiculos');
      setState(() {
        _ufs      = List<String>.from(ufs['data'] ?? []);
        _veiculos = veic['data'] ?? [];
      });
    } catch (_) {}
  }

  Future<void> _buscar() async {
    setState(() { _loading = true; _postos = []; });
    try {
      final params = <String, dynamic>{};
      if (_ufSelecionada != null)        params['uf']       = _ufSelecionada;
      if (_municipioCtrl.text.isNotEmpty) params['municipio'] = _municipioCtrl.text;
      final r = await ApiService().get('/roteirizacao/postos', params: params);
      setState(() => _postos = r['data'] ?? []);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _abrirMapa(Map posto) async {
    final lat = posto['lat'];
    final lon = posto['lon'];
    if (lat == null || lon == null || lat == '' || lon == '') {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Coordenadas nao disponiveis para este posto')));
      return;
    }
    final nome = Uri.encodeComponent(posto['razao_social'] ?? 'Posto');
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon&query_place_id=$nome');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _abrirRotaNoMapa() async {
    if (_postos.isEmpty) return;
    final postosComCoord = _postos.where((p) => p['lat'] != null && p['lat'] != '' && p['lon'] != null && p['lon'] != '').toList();
    if (postosComCoord.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum posto com coordenadas disponiveis')));
      return;
    }
    final waypoints = postosComCoord.take(10).map((p) => '${p["lat"]},${p["lon"]}').join('|');
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&waypoints=$waypoints');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _novoOuEditarVeiculo([Map? dados]) async {
    final nomeCtrl      = TextEditingController(text: dados?['nome'] ?? '');
    final placaCtrl     = TextEditingController(text: dados?['placa'] ?? '');
    final combCtrl      = TextEditingController(text: dados?['combustivel'] ?? '');
    final tanqueCtrl    = TextEditingController(text: dados?['tanque']?.toString() ?? '');
    final autonomiaCtrl = TextEditingController(text: dados?['autonomia']?.toString() ?? '');

    await showDialog(context: context, builder: (_) => AlertDialog(
      title: Text(dados == null ? 'Novo Veiculo' : 'Editar Veiculo'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nomeCtrl,      decoration: const InputDecoration(labelText: 'Nome/Apelido')),
        TextField(controller: placaCtrl,     decoration: const InputDecoration(labelText: 'Placa *'), textCapitalization: TextCapitalization.characters),
        TextField(controller: combCtrl,      decoration: const InputDecoration(labelText: 'Combustivel')),
        TextField(controller: tanqueCtrl,    decoration: const InputDecoration(labelText: 'Capacidade tanque (L)'), keyboardType: TextInputType.number),
        TextField(controller: autonomiaCtrl, decoration: const InputDecoration(labelText: 'Autonomia (km/L)'), keyboardType: TextInputType.number),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () async {
            try {
              final body = {
                'nome': nomeCtrl.text.trim(),
                'placa': placaCtrl.text.toUpperCase().trim(),
                'combustivel': combCtrl.text.trim(),
                'tanque': double.tryParse(tanqueCtrl.text.replaceAll(',', '.')) ?? 0,
                'autonomia': double.tryParse(autonomiaCtrl.text.replaceAll(',', '.')) ?? 0,
              };
              if (dados == null) {
                await ApiService().post('/frota/perfis', data: body);
              } else {
                await ApiService().put('/frota/perfis/${dados["id"]}', data: body);
              }
              if (mounted) { Navigator.pop(context); _carregarInicial(); }
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
            }
          },
          child: Text(dados == null ? 'Criar' : 'Salvar'),
        ),
      ],
    ));
  }

  Future<void> _deletarVeiculo(String id) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Confirmar exclusao'),
      content: const Text('Deseja excluir este veiculo?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir', style: TextStyle(color: Colors.white))),
      ],
    ));
    if (ok != true) return;
    try {
      await ApiService().delete('/frota/perfis/$id');
      _carregarInicial();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: const Text('Roteirizacao'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(children: [
            _tab('Buscar Postos', 0),
            _tab('Meus Veiculos', 1),
          ]),
        ),
      ),
      floatingActionButton: _tabIndex == 1 ? FloatingActionButton(
        onPressed: () => _novoOuEditarVeiculo(),
        child: const Icon(Icons.add),
      ) : null,
      body: _tabIndex == 0 ? _buildBuscaPostos() : _buildVeiculos(),
    );
  }

  Widget _buildBuscaPostos() => Column(children: [
    Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(
          value: _ufSelecionada,
          hint: const Text('UF'),
          items: _ufs.map((uf) => DropdownMenuItem(value: uf, child: Text(uf))).toList(),
          onChanged: (v) => setState(() => _ufSelecionada = v),
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
        )),
        const SizedBox(width: 8),
        Expanded(child: TextField(
          controller: _municipioCtrl,
          decoration: const InputDecoration(labelText: 'Municipio', border: OutlineInputBorder(), isDense: true),
          textCapitalization: TextCapitalization.words,
        )),
      ]),
      const SizedBox(height: 8),
      if (_veiculos.isNotEmpty) DropdownButtonFormField<String>(
        value: _veiculoSelecionado,
        hint: const Text('Selecione veiculo (opcional)'),
        items: _veiculos.map((v) => DropdownMenuItem(
          value: v['id'].toString(),
          child: Text('${v["placa"]} — ${v["combustivel"]} (${v["tanque"]}L)'),
        )).toList(),
        onChanged: (v) => setState(() => _veiculoSelecionado = v),
        decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: ElevatedButton.icon(
          onPressed: _buscar,
          icon: const Icon(Icons.search),
          label: Text(_loading ? 'Buscando...' : 'Buscar Postos'),
        )),
        const SizedBox(width: 8),
        if (_postos.isNotEmpty) ElevatedButton.icon(
          onPressed: _abrirRotaNoMapa,
          icon: const Icon(Icons.map),
          label: const Text('Ver no Mapa'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        ),
      ]),
    ])),
    if (_loading) const LinearProgressIndicator(),
    if (_postos.isNotEmpty) Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text('${_postos.length} postos encontrados',
          style: TextStyle(color: Colors.grey[600], fontSize: 13)),
    ),
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
                  leading: const CircleAvatar(backgroundColor: Color(0xFFE3F2FD),
                      child: Icon(Icons.local_gas_station, color: Colors.blue)),
                  title: Text(p['razao_social'] ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('${p["municipio"] ?? "-"}/${p["uf"] ?? "-"}\n${p["combustiveis"] ?? "-"}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.map, color: Colors.green),
                    onPressed: () => _abrirMapa(p),
                  ),
                ),
              );
            })),
  ]);

  Widget _buildVeiculos() => _veiculos.isEmpty
      ? const Center(child: Text('Nenhum veiculo cadastrado.\nToque em + para adicionar.', textAlign: TextAlign.center))
      : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _veiculos.length,
          itemBuilder: (_, i) {
            final v = _veiculos[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFFFF3E0),
                    child: Icon(Icons.directions_car, color: Colors.orange)),
                title: Text('${v["placa"]} — ${v["nome"] ?? "-"}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${v["combustivel"] ?? "-"} · Tanque: ${v["tanque"] ?? "-"}L · ${v["autonomia"] ?? "-"}km/L'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _novoOuEditarVeiculo(v)),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deletarVeiculo(v['id'].toString())),
                ]),
              ),
            );
          });

  Widget _tab(String label, int idx) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() => _tabIndex = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(
            color: _tabIndex == idx ? Colors.white : Colors.transparent, width: 2))),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(color: _tabIndex == idx ? Colors.white : Colors.white60, fontSize: 13)),
      ),
    ),
  );
}
