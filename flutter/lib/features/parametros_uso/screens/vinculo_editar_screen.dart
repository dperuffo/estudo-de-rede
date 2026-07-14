import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../motoristas/providers/motoristas_provider.dart' show motoristasClienteProvider;
import '../../veiculos/providers/veiculos_provider.dart' show veiculosClienteProvider;
import '../providers/parametros_uso_provider.dart';
import '../services/parametros_uso_service.dart';

class VinculoEditarScreen extends ConsumerStatefulWidget {
  final String id;
  const VinculoEditarScreen({super.key, required this.id});

  @override
  ConsumerState<VinculoEditarScreen> createState() => _VinculoEditarScreenState();
}

class _VinculoEditarScreenState extends ConsumerState<VinculoEditarScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _placa;
  String? _motoristaId;
  final _observacaoCtrl = TextEditingController();
  bool _ativo = true;
  bool _salvando = false;
  bool _preenchido = false;
  String? _erro;

  void _preencher(VinculoRow v) {
    _placa = v.placa;
    _motoristaId = v.motoristaId;
    _observacaoCtrl.text = v.observacao ?? '';
    _ativo = v.ativo;
    _preenchido = true;
  }

  @override
  void dispose() {
    _observacaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final erro = await ParametrosUsoService().atualizarVinculo(
      id: widget.id,
      placa: _placa!,
      motoristaId: _motoristaId!,
      observacao: _observacaoCtrl.text,
      ativo: _ativo,
    );
    if (!mounted) return;
    setState(() => _salvando = false);
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    ref.invalidate(vinculosProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alterações salvas.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final detalheAsync = ref.watch(vinculoDetalheProvider(widget.id));
    final veiculosAsync = ref.watch(veiculosClienteProvider);
    final motoristasAsync = ref.watch(motoristasClienteProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Vínculo')),
      body: detalheAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (v) {
          if (v == null) return const Center(child: Text('Vínculo não encontrado.'));
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
                veiculosAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Erro ao carregar veículos: $e'),
                  data: (veiculos) => DropdownButtonFormField<String>(
                    value: veiculos.any((x) => x.placa == _placa) ? _placa : null,
                    decoration: const InputDecoration(labelText: 'Veículo (placa) *', border: OutlineInputBorder()),
                    items: [for (final vv in veiculos) DropdownMenuItem(value: vv.placa, child: Text(vv.placa))],
                    onChanged: (val) => setState(() => _placa = val),
                    validator: (val) => val == null ? 'Selecione um veículo' : null,
                  ),
                ),
                const SizedBox(height: 10),
                motoristasAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Erro ao carregar motoristas: $e'),
                  data: (motoristas) => DropdownButtonFormField<String>(
                    value: motoristas.any((m) => m.id == _motoristaId) ? _motoristaId : null,
                    decoration: const InputDecoration(labelText: 'Motorista *', border: OutlineInputBorder()),
                    items: [for (final m in motoristas) DropdownMenuItem(value: m.id, child: Text(m.nomeCompleto))],
                    onChanged: (val) => setState(() => _motoristaId = val),
                    validator: (val) => val == null ? 'Selecione um motorista' : null,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _observacaoCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Observação', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Vínculo ativo'),
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
