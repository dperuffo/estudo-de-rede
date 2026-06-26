import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/menu_button.dart';

class RoteirizacaoScreen extends StatefulWidget {
  const RoteirizacaoScreen({super.key});
  @override State<RoteirizacaoScreen> createState() => _State();
}

class _State extends State<RoteirizacaoScreen> {
  List<dynamic> _veiculos = [];
  List<dynamic> _rotasSalvas = [];
  Map<String, dynamic>? _resultado;
  bool _loading = false;
  bool _loadingSalvas = false;
  int _tabIndex = 0;
  String? _veiculoId;

  Map<String, dynamic>? _origemSel;
  Map<String, dynamic>? _destinoSel;
  List<Map<String, dynamic>> _paradas = [];

  final _tanqueCtrl    = TextEditingController(text: '80');
  final _autonomiaCtrl = TextEditingController(text: '10');
  final _combCtrl      = TextEditingController(text: 'Diesel');

  @override void initState() { super.initState(); _carregarVeiculos(); _carregarRotasSalvas(); }

  Future<void> _carregarVeiculos() async {
    try {
      final r = await ApiService().get('/roteirizacao/veiculos');
      setState(() => _veiculos = r['data'] ?? []);
    } catch (_) {}
  }

  void _selecionarVeiculo(String id) {
    final v = _veiculos.firstWhere((v) => v['id'].toString() == id, orElse: () => {});
    if (v.isEmpty) return;
    setState(() {
      _veiculoId = id;
      _tanqueCtrl.text    = (v['tanque'] ?? 80).toString();
      _autonomiaCtrl.text = (v['autonomia'] ?? 10).toString();
      _combCtrl.text      = v['combustivel'] ?? 'Diesel';
    });
  }

  Future<List<Map>> _buscarLocal(String q) async {
    if (q.length < 3) return [];
    try {
      final r = await ApiService().get('/roteirizacao/geocoding', params: {'q': q});
      return List<Map>.from(r['data'] ?? []);
    } catch (_) { return []; }
  }

  Future<Map<String, dynamic>?> _dialogBuscarLocal(String titulo) async {
    final ctrl = TextEditingController();
    List<Map> sugestoes = [];
    Map<String, dynamic>? selecionado;

    return showDialog<Map<String, dynamic>>(context: context, builder: (dialogCtx) =>
      StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
        title: Text(titulo),
        content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Digite a cidade ou endereco',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) async {
              final res = await _buscarLocal(v);
              setSt(() => sugestoes = res);
            },
          ),
          const SizedBox(height: 8),
          if (sugestoes.isNotEmpty) Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: sugestoes.length,
              itemBuilder: (_, i) => ListTile(
                dense: true,
                leading: const Icon(Icons.location_on, color: Colors.blue, size: 18),
                title: Text(sugestoes[i]['nome'] ?? '', style: const TextStyle(fontSize: 13)),
                subtitle: Text(sugestoes[i]['endereco'] ?? '',
                    style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(dialogCtx, sugestoes[i]),
              ),
            ),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
        ],
      )),
    );
  }

  Future<void> _calcular() async {
    if (_origemSel == null || _destinoSel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione origem e destino')));
      return;
    }
    setState(() { _loading = true; _resultado = null; });
    try {
      final r = await ApiService().post('/roteirizacao/calcular', data: {
        'origem':  _origemSel,
        'destino': _destinoSel,
        'paradas': _paradas,
        'veiculo': {
          'tanque':      double.tryParse(_tanqueCtrl.text) ?? 80,
          'autonomia':   double.tryParse(_autonomiaCtrl.text) ?? 10,
          'combustivel': _combCtrl.text,
        },
        'raio_km': 10,
        'pesos': {'preco': 0.6, 'score': 0.2, 'desvio': 0.2},
      });
      setState(() { _resultado = r; _tabIndex = 1; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _abrirMapaCompleto() async {
    if (_resultado == null) return;
    final orig   = _resultado!['origem'];
    final dest   = _resultado!['destino'];
    final sugest = (_resultado!['sugestoes'] as List?) ?? [];
    final waypoints = sugest.map((s) => '${s["lat"]},${s["lon"]}').join('|');
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${orig["lat"]},${orig["lon"]}'
      '&destination=${dest["lat"]},${dest["lon"]}'
      '${waypoints.isNotEmpty ? "&waypoints=$waypoints" : ""}'
      '&travelmode=driving'
    );
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _abrirPostoNoMapa(Map posto) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${posto["lat"]},${posto["lon"]}');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _novoOuEditarVeiculo([Map? dados]) async {
    final nomeCtrl      = TextEditingController(text: dados?['nome'] ?? '');
    final placaCtrl     = TextEditingController(text: dados?['placa'] ?? '');
    final combCtrl      = TextEditingController(text: dados?['combustivel'] ?? '');
    final tanqueCtrl    = TextEditingController(text: dados?['tanque']?.toString() ?? '');
    final autonomiaCtrl = TextEditingController(text: dados?['autonomia']?.toString() ?? '');
    final salvou = await showDialog<bool>(context: context, builder: (dialogCtx) => AlertDialog(
      title: Text(dados == null ? 'Novo Veiculo' : 'Editar Veiculo'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nomeCtrl,      decoration: const InputDecoration(labelText: 'Nome/Apelido')),
        TextField(controller: placaCtrl,     decoration: const InputDecoration(labelText: 'Placa *'), textCapitalization: TextCapitalization.characters),
        TextField(controller: combCtrl,      decoration: const InputDecoration(labelText: 'Combustivel')),
        TextField(controller: tanqueCtrl,    decoration: const InputDecoration(labelText: 'Capacidade tanque (L)'), keyboardType: TextInputType.number),
        TextField(controller: autonomiaCtrl, decoration: const InputDecoration(labelText: 'Autonomia (km/L)'), keyboardType: TextInputType.number),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
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
              Navigator.pop(dialogCtx, true);
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
            }
          },
          child: Text(dados == null ? 'Criar' : 'Salvar'),
        ),
      ],
    ));
    if (salvou == true) _carregarVeiculos();
  }

  Future<void> _deletarVeiculo(String id) async {
    final ok = await showDialog<bool>(context: context, builder: (dialogCtx) => AlertDialog(
      title: const Text('Confirmar exclusao'),
      content: const Text('Deseja excluir este veiculo?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir', style: TextStyle(color: Colors.white))),
      ],
    ));
    if (ok != true) return;
    try {
      await ApiService().delete('/frota/perfis/$id');
      setState(() => _veiculos.removeWhere((v) => v['id'].toString() == id));
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
            _tab('Planejar', 0),
            _tab('Resultado', 1),
            _tab('Salvas', 2),
            _tab('Veiculos', 3),
          ]),
        ),
      ),
      floatingActionButton: _tabIndex == 3 ? FloatingActionButton(
        onPressed: () => _novoOuEditarVeiculo(),
        child: const Icon(Icons.add),
      ) : null,
      body: _tabIndex == 0 ? _buildPlanejamento()
          : _tabIndex == 1 ? _buildResultado()
          : _tabIndex == 2 ? _buildRotasSalvas()
          : _buildVeiculos(),
    );
  }

  Widget _buildPlanejamento() => ListView(padding: const EdgeInsets.all(16), children: [
    // Veículo
    const Text('Veiculo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    const SizedBox(height: 8),
    if (_veiculos.isNotEmpty) DropdownButtonFormField<String>(
      value: _veiculoId,
      hint: const Text('Selecione veiculo salvo (opcional)'),
      items: _veiculos.map((v) => DropdownMenuItem(
        value: v['id'].toString(),
        child: Text('${v["placa"]} — ${v["combustivel"]} (${v["tanque"]}L)'),
      )).toList(),
      onChanged: (v) { if (v != null) _selecionarVeiculo(v); },
      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
    ),
    const SizedBox(height: 8),
    Row(children: [
      Expanded(child: TextField(controller: _tanqueCtrl,
          decoration: const InputDecoration(labelText: 'Tanque (L)', border: OutlineInputBorder(), isDense: true),
          keyboardType: TextInputType.number)),
      const SizedBox(width: 8),
      Expanded(child: TextField(controller: _autonomiaCtrl,
          decoration: const InputDecoration(labelText: 'km/L', border: OutlineInputBorder(), isDense: true),
          keyboardType: TextInputType.number)),
      const SizedBox(width: 8),
      Expanded(child: TextField(controller: _combCtrl,
          decoration: const InputDecoration(labelText: 'Combustivel', border: OutlineInputBorder(), isDense: true))),
    ]),
    const SizedBox(height: 16),

    // Origem
    const Text('Origem', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    const SizedBox(height: 8),
    _localSelector(_origemSel, 'Selecionar origem', () async {
      final r = await _dialogBuscarLocal('Origem');
      if (r != null) setState(() => _origemSel = r);
    }),
    const SizedBox(height: 12),

    // Paradas
    Row(children: [
      const Text('Paradas intermediarias', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const Spacer(),
      TextButton.icon(
        onPressed: () async {
          final r = await _dialogBuscarLocal('Adicionar parada');
          if (r != null) setState(() => _paradas.add(r));
        },
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Adicionar'),
      ),
    ]),
    ..._paradas.asMap().entries.map((e) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        const Icon(Icons.radio_button_checked, color: Colors.orange, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(e.value['nome'] ?? e.value['endereco'] ?? '-')),
        IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.red),
            onPressed: () => setState(() => _paradas.removeAt(e.key))),
      ]),
    )),
    const SizedBox(height: 12),

    // Destino
    const Text('Destino', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    const SizedBox(height: 8),
    _localSelector(_destinoSel, 'Selecionar destino', () async {
      final r = await _dialogBuscarLocal('Destino');
      if (r != null) setState(() => _destinoSel = r);
    }),
    const SizedBox(height: 24),

    SizedBox(width: double.infinity, child: ElevatedButton.icon(
      onPressed: _loading ? null : _calcular,
      icon: _loading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.route),
      label: Text(_loading ? 'Calculando...' : 'Calcular Rota'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0D2D6B),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    )),
  ]);

  Widget _localSelector(Map? sel, String hint, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(sel != null ? Icons.location_on : Icons.search,
            color: sel != null ? Colors.blue : Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(
          sel != null ? (sel['nome'] ?? sel['endereco'] ?? '-') : hint,
          style: TextStyle(color: sel != null ? Colors.black87 : Colors.grey[600]),
        )),
        if (sel != null) GestureDetector(
          onTap: () => setState(() {
            if (sel == _origemSel) _origemSel = null;
            else if (sel == _destinoSel) _destinoSel = null;
          }),
          child: const Icon(Icons.close, size: 18, color: Colors.grey),
        ),
      ]),
    ),
  );

  Widget _buildResultado() {
    if (_resultado == null) return const Center(child: Text('Calcule uma rota na aba "Planejar"'));
    final fmt    = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final rota   = _resultado!['rota'] as Map? ?? {};
    final resumo = _resultado!['resumo'] as Map? ?? {};
    final orig   = _resultado!['origem'] as Map? ?? {};
    final dest   = _resultado!['destino'] as Map? ?? {};
    final sugest = (_resultado!['sugestoes'] as List?) ?? [];

    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(color: const Color(0xFF0D2D6B), child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Text('${orig["nome"] ?? "Origem"} → ${dest["nome"] ?? "Destino"}',
            style: const TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _metrica('${rota["dist_km"]} km', 'Distancia', Colors.white),
          _metrica('${(rota["dur_min"] as num? ?? 0).toStringAsFixed(0)} min', 'Duracao', Colors.white),
          _metrica('${resumo["n_paradas"]}', 'Paradas', Colors.white),
        ]),
        if (rota["linha_reta"] == true) ...[
          const SizedBox(height: 8),
          const Text('* Rota em linha reta (OSRM indisponivel)',
              style: TextStyle(color: Colors.orange, fontSize: 11)),
        ],
      ]))),
      const SizedBox(height: 12),
      Row(children: [
        _kpi('Custo Total', fmt.format(resumo['custo_total'] ?? 0), Colors.green),
        const SizedBox(width: 8),
        _kpi('Litros', '${resumo["litros_total"]} L', Colors.blue),
        const SizedBox(width: 8),
        _kpi('R\$/km', 'R\$ ${resumo["custo_por_km"]}', Colors.orange),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: ElevatedButton.icon(
          onPressed: _abrirMapaCompleto,
          icon: const Icon(Icons.map),
          label: const Text('Ver no Maps'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
        )),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton.icon(
          onPressed: _salvarRota,
          icon: const Icon(Icons.bookmark),
          label: const Text('Salvar Rota'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D2D6B), foregroundColor: Colors.white),
        )),
      ]),
      const SizedBox(height: 16),
      if (sugest.isEmpty)
        const Card(child: Padding(padding: EdgeInsets.all(16),
            child: Text('Nenhum posto encontrado ao longo da rota nos ultimos 180 dias.',
                textAlign: TextAlign.center)))
      else ...[
        Text('${sugest.length} parada(s) sugerida(s)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ...sugest.asMap().entries.map((e) {
          final i = e.key; final s = e.value;
          return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(backgroundColor: const Color(0xFF0D2D6B),
                    child: Text('${i+1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s['razao_social'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${s["municipio"] ?? "-"}/${s["uf"] ?? "-"} · km ${s["_km"]}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ])),
                IconButton(icon: const Icon(Icons.map, color: Colors.green),
                    onPressed: () => _abrirPostoNoMapa(s)),
              ]),
              const Divider(height: 12),
              Row(children: [
                _metricaSmall(fmt.format(s['preco'] ?? 0), 'Preco/L', Colors.blue),
                _metricaSmall('${s["litros_sugeridos"]} L', 'Abastecer', Colors.orange),
                _metricaSmall(fmt.format(s['custo_abast'] ?? 0), 'Custo', Colors.green),
                _metricaSmall('${s["fuel_chegada_pct"]}%', 'Tanque chega', Colors.red),
              ]),
              const SizedBox(height: 4),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(4)),
                  child: Text(s['motivo'] ?? '-', style: const TextStyle(fontSize: 11, color: Color(0xFF1565C0)))),
            ]),
          ));
        }),
      ],
    ]);
  }

  Future<void> _carregarRotasSalvas() async {
    setState(() => _loadingSalvas = true);
    try {
      final r = await ApiService().get('/roteirizacao/salvas');
      setState(() => _rotasSalvas = r['data'] ?? []);
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingSalvas = false);
    }
  }

  Future<void> _salvarRota() async {
    if (_resultado == null) return;
    final nomeCtrl = TextEditingController(
        text: '${_resultado!["origem"]?["nome"] ?? "Origem"} → ${_resultado!["destino"]?["nome"] ?? "Destino"}');
    final ok = await showDialog<bool>(context: context, builder: (dialogCtx) => AlertDialog(
      title: const Text('Salvar rota'),
      content: TextField(controller: nomeCtrl,
          decoration: const InputDecoration(labelText: 'Nome da rota')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(dialogCtx, true), child: const Text('Salvar')),
      ],
    ));
    if (ok != true) return;
    try {
      await ApiService().post('/roteirizacao/salvas', data: {
        'nome':      nomeCtrl.text.trim(),
        'origem':    _resultado!['origem'],
        'destino':   _resultado!['destino'],
        'paradas':   _paradas,
        'veiculo':   _resultado!['veiculo'],
        'resultado': _resultado,
      });
      _carregarRotasSalvas();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rota salva com sucesso!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: \$e')));
    }
  }

  void _carregarRotaSalva(Map rota) {
    setState(() {
      _origemSel  = Map<String, dynamic>.from(rota['origem'] ?? {});
      _destinoSel = Map<String, dynamic>.from(rota['destino'] ?? {});
      _paradas    = List<Map<String, dynamic>>.from(rota['paradas'] ?? []);
      final v = rota['veiculo'] as Map? ?? {};
      _tanqueCtrl.text    = (v['tanque'] ?? 80).toString();
      _autonomiaCtrl.text = (v['autonomia'] ?? 10).toString();
      _combCtrl.text      = v['combustivel'] ?? 'Diesel';
      _resultado = rota['resultado'] != null ? Map<String, dynamic>.from(rota['resultado']) : null;
      _tabIndex  = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rota carregada! Clique em Calcular Rota para recalcular.')));
  }

  Future<void> _deletarRotaSalva(String id) async {
    final ok = await showDialog<bool>(context: context, builder: (dialogCtx) => AlertDialog(
      title: const Text('Excluir rota'),
      content: const Text('Deseja excluir esta rota salva?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir', style: TextStyle(color: Colors.white))),
      ],
    ));
    if (ok != true) return;
    try {
      await ApiService().delete('/roteirizacao/salvas/\$id');
      setState(() => _rotasSalvas.removeWhere((r) => r['id'].toString() == id));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: \$e')));
    }
  }

  Widget _buildRotasSalvas() => _loadingSalvas
      ? const Center(child: CircularProgressIndicator())
      : RefreshIndicator(
          onRefresh: _carregarRotasSalvas,
          child: _rotasSalvas.isEmpty
              ? const Center(child: Text('Nenhuma rota salva.\nCalcule uma rota e salve!', textAlign: TextAlign.center))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rotasSalvas.length,
                  itemBuilder: (_, i) {
                    final r = _rotasSalvas[i];
                    final orig = r['origem'] as Map? ?? {};
                    final dest = r['destino'] as Map? ?? {};
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xFFE3F2FD),
                            child: Icon(Icons.route, color: Colors.blue)),
                        title: Text(r['nome'] ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('\${orig["nome"] ?? "-"} → \${dest["nome"] ?? "-"}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.play_arrow, color: Colors.green),
                              onPressed: () => _carregarRotaSalva(r)),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deletarRotaSalva(r['id'].toString())),
                        ]),
                      ),
                    );
                  }),
        );

  Widget _buildVeiculos() => _veiculos.isEmpty
      ? const Center(child: Text('Nenhum veiculo cadastrado.\nToque em + para adicionar.', textAlign: TextAlign.center))
      : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _veiculos.length,
          itemBuilder: (_, i) {
            final v = _veiculos[i];
            return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFFFF3E0),
                  child: Icon(Icons.directions_car, color: Colors.orange)),
              title: Text('${v["placa"]} — ${v["nome"] ?? "-"}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${v["combustivel"] ?? "-"} · ${v["tanque"]}L · ${v["autonomia"]}km/L'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _novoOuEditarVeiculo(v)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deletarVeiculo(v['id'].toString())),
              ]),
            ));
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

  Widget _kpi(String label, String value, Color color) => Expanded(
    child: Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    ))),
  );

  Widget _metrica(String value, String label, Color color) => Column(children: [
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
    Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
  ]);

  Widget _metricaSmall(String value, String label, Color color) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
    Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
  ]));
}
