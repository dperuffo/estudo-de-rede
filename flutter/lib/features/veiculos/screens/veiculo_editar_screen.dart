import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../motoristas/providers/motoristas_provider.dart' show centrosCustoOpcoesProvider;
import '../providers/veiculos_provider.dart';
import '../services/veiculos_service.dart';

class VeiculoEditarScreen extends ConsumerStatefulWidget {
  final String id;
  const VeiculoEditarScreen({super.key, required this.id});

  @override
  ConsumerState<VeiculoEditarScreen> createState() => _VeiculoEditarScreenState();
}

class _VeiculoEditarScreenState extends ConsumerState<VeiculoEditarScreen> {
  final _formKey = GlobalKey<FormState>();
  final _placaCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _motorCtrl = TextEditingController();
  final _anoModeloCtrl = TextEditingController();
  final _anoFabricacaoCtrl = TextEditingController();
  final _hodometroCtrl = TextEditingController();
  final _tanqueCtrl = TextEditingController();
  final _autonomiaCtrl = TextEditingController();
  final _corCtrl = TextEditingController();
  final _chassiCtrl = TextEditingController();
  final _renavamCtrl = TextEditingController();
  final _municipioCtrl = TextEditingController();
  final _ufCtrl = TextEditingController();
  final _eixosCtrl = TextEditingController();

  String? _tipoVeiculo;
  String _classificacao = 'Próprio';
  String? _tipo;
  String? _combustivel;
  String? _centroCustoId;
  bool _ativo = true;
  bool _salvando = false;
  bool _preenchido = false;
  String? _erro;

  int? _intOuNull(String t) => t.trim().isEmpty ? null : int.tryParse(t.trim());
  double? _doubleOuNull(String t) => t.trim().isEmpty ? null : double.tryParse(t.trim().replaceAll(',', '.'));

  void _preencher(Veiculo v) {
    _placaCtrl.text = v.placa;
    _marcaCtrl.text = v.marca ?? '';
    _modeloCtrl.text = v.modelo ?? '';
    _motorCtrl.text = v.motor ?? '';
    _anoModeloCtrl.text = v.anoModelo?.toString() ?? '';
    _anoFabricacaoCtrl.text = v.anoFabricacao?.toString() ?? '';
    _hodometroCtrl.text = v.hodometroAtual?.toStringAsFixed(0) ?? '';
    _tanqueCtrl.text = v.tanque?.toString() ?? '';
    _autonomiaCtrl.text = v.autonomia?.toString() ?? '';
    _corCtrl.text = v.cor ?? '';
    _chassiCtrl.text = v.chassi ?? '';
    _renavamCtrl.text = v.renavam ?? '';
    _municipioCtrl.text = v.municipio ?? '';
    _ufCtrl.text = v.ufVeiculo ?? '';
    _eixosCtrl.text = v.numeroEixos?.toString() ?? '';
    _tipoVeiculo = tiposVeiculo.contains(v.tipoVeiculo) ? v.tipoVeiculo : null;
    _classificacao = classificacoesVeiculo.contains(v.classificacao) ? v.classificacao : 'Próprio';
    _tipo = tiposPorteVeiculo.contains(v.tipo) ? v.tipo : null;
    _combustivel = ciclosCombustivel.contains(v.combustivel) ? v.combustivel : null;
    _centroCustoId = v.centroCustoId;
    _ativo = v.ativo;
    _preenchido = true;
  }

  @override
  void dispose() {
    _placaCtrl.dispose();
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _motorCtrl.dispose();
    _anoModeloCtrl.dispose();
    _anoFabricacaoCtrl.dispose();
    _hodometroCtrl.dispose();
    _tanqueCtrl.dispose();
    _autonomiaCtrl.dispose();
    _corCtrl.dispose();
    _chassiCtrl.dispose();
    _renavamCtrl.dispose();
    _municipioCtrl.dispose();
    _ufCtrl.dispose();
    _eixosCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });

    final erro = await VeiculosService().atualizarVeiculo(
      id: widget.id,
      placa: _placaCtrl.text,
      marca: _marcaCtrl.text,
      modelo: _modeloCtrl.text,
      motor: _motorCtrl.text,
      anoModelo: _intOuNull(_anoModeloCtrl.text),
      anoFabricacao: _intOuNull(_anoFabricacaoCtrl.text),
      hodometroAtual: _doubleOuNull(_hodometroCtrl.text),
      combustivel: _combustivel,
      tanque: _doubleOuNull(_tanqueCtrl.text),
      autonomia: _doubleOuNull(_autonomiaCtrl.text),
      cor: _corCtrl.text,
      chassi: _chassiCtrl.text,
      renavam: _renavamCtrl.text,
      municipio: _municipioCtrl.text,
      tipoVeiculo: _tipoVeiculo,
      ufVeiculo: _ufCtrl.text,
      numeroEixos: _intOuNull(_eixosCtrl.text),
      classificacao: _classificacao,
      tipo: _tipo,
      ativo: _ativo,
      centroCustoId: _centroCustoId,
    );

    if (!mounted) return;
    setState(() => _salvando = false);
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    ref.invalidate(veiculosClienteProvider);
    ref.invalidate(veiculoDetalheProvider(widget.id));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alterações salvas.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final detalheAsync = ref.watch(veiculoDetalheProvider(widget.id));
    final centrosCustoAsync = ref.watch(centrosCustoOpcoesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Veículo')),
      body: detalheAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (v) {
          if (v == null) return const Center(child: Text('Veículo não encontrado.'));
          if (!_preenchido) _preencher(v);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_erro != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                    child: Text(_erro!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
                  ),
                  const SizedBox(height: 12),
                ],
                Text('Identificação', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _placaCtrl,
                  decoration: const InputDecoration(labelText: 'Placa *', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a placa' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _marcaCtrl,
                  decoration: const InputDecoration(labelText: 'Marca', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _modeloCtrl,
                  decoration: const InputDecoration(labelText: 'Modelo', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _chassiCtrl,
                  decoration: const InputDecoration(labelText: 'Chassi', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _renavamCtrl,
                  decoration: const InputDecoration(labelText: 'Renavam', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _corCtrl,
                  decoration: const InputDecoration(labelText: 'Cor', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _tipoVeiculo,
                  decoration: const InputDecoration(labelText: 'Tipo de veículo', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Selecione...')),
                    for (final t in tiposVeiculo) DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (val) => setState(() => _tipoVeiculo = val),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _classificacao,
                  decoration: const InputDecoration(labelText: 'Classificação', border: OutlineInputBorder()),
                  items: [for (final c in classificacoesVeiculo) DropdownMenuItem(value: c, child: Text(c))],
                  onChanged: (val) => setState(() => _classificacao = val ?? 'Próprio'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _tipo,
                  decoration: const InputDecoration(labelText: 'Tipo (porte)', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Selecione...')),
                    for (final t in tiposPorteVeiculo) DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (val) => setState(() => _tipo = val),
                ),
                const SizedBox(height: 20),
                Text('Especificações técnicas', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _motorCtrl,
                  decoration: const InputDecoration(labelText: 'Motor', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _anoModeloCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Ano modelo', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _anoFabricacaoCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Ano fabricação', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _combustivel,
                  decoration: const InputDecoration(labelText: 'Combustível', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Selecione...')),
                    for (final c in ciclosCombustivel) DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (val) => setState(() => _combustivel = val),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _tanqueCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Tanque (L)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _autonomiaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Autonomia (km/l)', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _hodometroCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Hodômetro atual (km)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _eixosCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Nº de eixos', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Localização e centro de custo', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _municipioCtrl,
                        decoration: const InputDecoration(labelText: 'Município', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        controller: _ufCtrl,
                        maxLength: 2,
                        decoration:
                            const InputDecoration(labelText: 'UF', border: OutlineInputBorder(), counterText: ''),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                centrosCustoAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Erro ao carregar centros de custo: $e'),
                  data: (opcoes) => DropdownButtonFormField<String?>(
                    value: opcoes.any((c) => c.id == _centroCustoId) ? _centroCustoId : null,
                    decoration: const InputDecoration(labelText: 'Centro de custo', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Nenhum')),
                      for (final c in opcoes) DropdownMenuItem<String?>(value: c.id, child: Text(c.nome)),
                    ],
                    onChanged: (val) => setState(() => _centroCustoId = val),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Veículo ativo'),
                  value: _ativo,
                  onChanged: (val) => setState(() => _ativo = val),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _salvando ? null : _salvar,
                  child: _salvando
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Salvar alterações'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
