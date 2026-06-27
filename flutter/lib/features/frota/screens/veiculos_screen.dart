import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/menu_button.dart';

class VeiculosScreen extends StatefulWidget {
  const VeiculosScreen({super.key});
  @override State<VeiculosScreen> createState() => _State();
}

class _State extends State<VeiculosScreen> {
  List<dynamic> _veiculos = [];
  bool _loading = true;
  String _filtro = 'todos';

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService().get('/veiculos');
      setState(() => _veiculos = r['data'] ?? []);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List get _veiculosFiltrados {
    if (_filtro == 'cadastrados') return _veiculos.where((v) => v['cadastrado'] == true).toList();
    if (_filtro == 'nao_cadastrados') return _veiculos.where((v) => v['cadastrado'] != true).toList();
    return _veiculos;
  }

  Future<void> _novoOuEditar([Map? dados]) async {
    final placaCtrl    = TextEditingController(text: dados?['placa'] ?? '');
    final marcaCtrl    = TextEditingController(text: dados?['marca'] ?? '');
    final modeloCtrl   = TextEditingController(text: dados?['modelo'] ?? '');
    final motorCtrl    = TextEditingController(text: dados?['motor'] ?? '');
    final anoModCtrl   = TextEditingController(text: dados?['ano_modelo']?.toString() ?? '');
    final anoFabCtrl   = TextEditingController(text: dados?['ano_fabricacao']?.toString() ?? '');
    final hodCtrl      = TextEditingController(text: dados?['hodometro_atual']?.toString() ?? dados?['hodometro_abast']?.toString() ?? '');
    final combCtrl     = TextEditingController(text: dados?['combustivel'] ?? '');
    final tanqueCtrl   = TextEditingController(text: dados?['tanque']?.toString() ?? '');
    final autonomiaCtrl= TextEditingController(text: dados?['autonomia']?.toString() ?? '');
    final corCtrl      = TextEditingController(text: dados?['cor'] ?? '');
    final chassiCtrl   = TextEditingController(text: dados?['chassi'] ?? '');
    final renavamCtrl  = TextEditingController(text: dados?['renavam'] ?? '');

    final isCadastrado = dados?['cadastrado'] == true;
    final id = dados?['id'];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text(isCadastrado ? 'Editar Veiculo' : 'Cadastrar Veiculo',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D2D6B))),
              const Spacer(),
              if (!isCadastrado) Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: const Text('Nao cadastrado', style: TextStyle(color: Colors.orange, fontSize: 11)),
              ),
            ]),
          ),
          const Divider(height: 16),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _secao('Identificacao'),
              _campo(placaCtrl, 'Placa *', caps: TextCapitalization.characters, enabled: !isCadastrado),
              Row(children: [
                Expanded(child: _campo(marcaCtrl, 'Marca')),
                const SizedBox(width: 8),
                Expanded(child: _campo(modeloCtrl, 'Modelo')),
              ]),
              _campo(motorCtrl, 'Motor'),
              Row(children: [
                Expanded(child: _campo(anoModCtrl, 'Ano Modelo', tipo: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _campo(anoFabCtrl, 'Ano Fabricacao', tipo: TextInputType.number)),
              ]),
              _campo(corCtrl, 'Cor'),
              const SizedBox(height: 16),
              _secao('Documentacao'),
              _campo(chassiCtrl, 'Chassi'),
              _campo(renavamCtrl, 'RENAVAM'),
              const SizedBox(height: 16),
              _secao('Combustivel & Performance'),
              _campo(combCtrl, 'Combustivel'),
              Row(children: [
                Expanded(child: _campo(tanqueCtrl, 'Tanque (L)', tipo: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _campo(autonomiaCtrl, 'Autonomia (km/L)', tipo: TextInputType.number)),
              ]),
              const SizedBox(height: 16),
              _secao('Hodometro'),
              _campo(hodCtrl, 'Hodometro Atual (km)', tipo: TextInputType.number),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () async {
                  if (placaCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Placa obrigatoria')));
                    return;
                  }
                  try {
                    final body = {
                      'placa': placaCtrl.text.toUpperCase().trim(),
                      'marca': marcaCtrl.text.trim(),
                      'modelo': modeloCtrl.text.trim(),
                      'motor': motorCtrl.text.trim(),
                      'ano_modelo': int.tryParse(anoModCtrl.text),
                      'ano_fabricacao': int.tryParse(anoFabCtrl.text),
                      'hodometro_atual': double.tryParse(hodCtrl.text.replaceAll(',','.')),
                      'combustivel': combCtrl.text.trim(),
                      'tanque': double.tryParse(tanqueCtrl.text.replaceAll(',','.')),
                      'autonomia': double.tryParse(autonomiaCtrl.text.replaceAll(',','.')),
                      'cor': corCtrl.text.trim(),
                      'chassi': chassiCtrl.text.trim(),
                      'renavam': renavamCtrl.text.trim(),
                    };
                    body.removeWhere((k, v) => v == null || v == '');
                    if (isCadastrado && id != null) {
                      await ApiService().put('/veiculos/$id', data: body);
                    } else {
                      await ApiService().post('/veiculos', data: body);
                    }
                    if (mounted) { Navigator.pop(ctx); _load(); }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D2D6B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(isCadastrado ? 'Salvar alteracoes' : 'Cadastrar veiculo',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              )),
            ]),
          )),
        ]),
      ),
    );
  }

  Future<void> _deletar(String id, String placa) async {
    final ok = await showDialog<bool>(context: context, builder: (dialogCtx) => AlertDialog(
      title: const Text('Confirmar exclusao'),
      content: Text('Deseja remover o veiculo $placa?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remover', style: TextStyle(color: Colors.white))),
      ],
    ));
    if (ok != true) return;
    try {
      await ApiService().delete('/veiculos/$id');
      setState(() => _veiculos.removeWhere((v) => v['id'].toString() == id));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lista = _veiculosFiltrados;
    final nCadastrados = _veiculos.where((v) => v['cadastrado'] == true).length;
    final nNaoCad = _veiculos.where((v) => v['cadastrado'] != true).length;

    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: const Text('Frota — Veiculos'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _novoOuEditar(),
        backgroundColor: const Color(0xFF0D2D6B),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // Filtros
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  _chipFiltro('Todos', 'todos', _veiculos.length),
                  const SizedBox(width: 8),
                  _chipFiltro('Cadastrados', 'cadastrados', nCadastrados),
                  const SizedBox(width: 8),
                  _chipFiltro('Pendentes', 'nao_cadastrados', nNaoCad, cor: Colors.orange),
                ]),
              ),
              // Lista
              Expanded(child: RefreshIndicator(
                onRefresh: _load,
                child: lista.isEmpty
                    ? const Center(child: Text('Nenhum veiculo encontrado'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: lista.length,
                        itemBuilder: (_, i) {
                          final v = lista[i];
                          final cadastrado = v['cadastrado'] == true;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: cadastrado
                                    ? const Color(0xFFE3F2FD)
                                    : const Color(0xFFFFF3E0),
                                child: Icon(Icons.directions_car,
                                    color: cadastrado ? Colors.blue : Colors.orange),
                              ),
                              title: Row(children: [
                                Text(v['placa'] ?? '-',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(width: 8),
                                if (!cadastrado) Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Pendente', style: TextStyle(color: Colors.orange, fontSize: 10)),
                                ),
                              ]),
                              subtitle: Text(
                                cadastrado
                                    ? '${v["marca"] ?? ""} ${v["modelo"] ?? ""} ${v["ano_modelo"] ?? ""}'.trim().isEmpty
                                        ? v['combustivel'] ?? '-'
                                        : '${v["marca"] ?? ""} ${v["modelo"] ?? ""} ${v["ano_modelo"] != null ? "(${v["ano_modelo"]})" : ""}'.trim()
                                    : '${v["combustivel"] ?? "-"} · ${v["n_abastecimentos"] ?? 0} abast.',
                              ),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                if (v['hodometro_atual'] != null || v['hodometro_abast'] != null)
                                  Text(
                                    '${NumberFormat('#,##0').format(v['hodometro_atual'] ?? v['hodometro_abast'] ?? 0)} km',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: Icon(cadastrado ? Icons.edit : Icons.add_circle,
                                      color: cadastrado ? Colors.blue : Colors.orange, size: 20),
                                  onPressed: () => _novoOuEditar(v),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                if (cadastrado) ...[
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                    onPressed: () => _deletar(v['id'].toString(), v['placa'] ?? ''),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ]),
                            ),
                          );
                        },
                      ),
              )),
            ]),
    );
  }

  Widget _secao(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0D2D6B))),
  );

  Widget _campo(TextEditingController ctrl, String label,
      {TextInputType tipo = TextInputType.text,
       TextCapitalization caps = TextCapitalization.words,
       bool enabled = true}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: tipo,
        textCapitalization: caps,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          filled: !enabled,
          fillColor: enabled ? null : Colors.grey[100],
        ),
      ),
    );

  Widget _chipFiltro(String label, String valor, int count, {Color? cor}) => GestureDetector(
    onTap: () => setState(() => _filtro = valor),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _filtro == valor ? (cor ?? const Color(0xFF0D2D6B)) : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$label ($count)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _filtro == valor ? Colors.white : Colors.grey[700],
          )),
    ),
  );
}
