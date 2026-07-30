import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../veiculos/providers/veiculos_provider.dart';
import '../providers/sinistros_provider.dart';
import '../services/sinistros_service.dart';

// Fase Indicadores-da-Frota C (30/07/2026) — porta de sinistros/nova/page.tsx
// + NovoSinistroForm.tsx.
class NovoSinistroScreen extends ConsumerStatefulWidget {
  const NovoSinistroScreen({super.key});

  @override
  ConsumerState<NovoSinistroScreen> createState() => _NovoSinistroScreenState();
}

class _NovoSinistroScreenState extends ConsumerState<NovoSinistroScreen> {
  String? _placa;
  final _dataCtrl = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
  String? _tipo;
  String? _gravidade;
  final _motoristaCtrl = TextEditingController();
  final _localCtrl = TextEditingController();
  final _custoCtrl = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  bool _houveVitima = false;
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _dataCtrl.dispose();
    _motoristaCtrl.dispose();
    _localCtrl.dispose();
    _custoCtrl.dispose();
    _descricaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final atual = DateTime.tryParse(_dataCtrl.text) ?? DateTime.now();
    final escolhida = await showDatePicker(context: context, initialDate: atual, firstDate: DateTime(2015), lastDate: DateTime.now());
    if (escolhida != null) _dataCtrl.text = escolhida.toIso8601String().substring(0, 10);
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    if (_placa == null || _placa!.isEmpty) {
      setState(() => _erro = 'Placa é obrigatória.');
      return;
    }
    if (_dataCtrl.text.trim().isEmpty) {
      setState(() => _erro = 'Data do sinistro é obrigatória.');
      return;
    }
    if (_tipo == null) {
      setState(() => _erro = 'Tipo do sinistro é obrigatório.');
      return;
    }
    final sessao = await ref.read(sessaoProvider.future);
    final empresaId = sessao.empresaId;
    if (empresaId == null) {
      setState(() => _erro = 'Selecione uma empresa antes.');
      return;
    }
    setState(() => _salvando = true);
    try {
      await SinistrosService().criar(
        empresaId: empresaId,
        placa: _placa!,
        dataSinistro: _dataCtrl.text.trim(),
        tipo: _tipo!,
        gravidade: _gravidade,
        motoristaNome: _motoristaCtrl.text.trim().isEmpty ? null : _motoristaCtrl.text.trim(),
        houveVitima: _houveVitima,
        custoEstimado: double.tryParse(_custoCtrl.text.replaceAll(',', '.')),
        localOcorrencia: _localCtrl.text.trim().isEmpty ? null : _localCtrl.text.trim(),
        descricao: _descricaoCtrl.text.trim().isEmpty ? null : _descricaoCtrl.text.trim(),
        criadoPor: sessao.email,
      );
      if (!mounted) return;
      ref.invalidate(sinistrosListProvider);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível registrar: $e';
        _salvando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final veiculosAsync = ref.watch(veiculosClienteProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Novo Sinistro')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_erro != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
              child: Text(_erro!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
            ),
          veiculosAsync.when(
            data: (lista) => DropdownButtonFormField<String>(
              value: _placa,
              decoration: const InputDecoration(labelText: 'Placa *', border: OutlineInputBorder(), isDense: true),
              items: lista.map((v) => DropdownMenuItem(value: v.placa, child: Text(v.placa))).toList(),
              onChanged: (v) => setState(() => _placa = v),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Não foi possível carregar os veículos.', style: TextStyle(color: Colors.red, fontSize: 12)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _dataCtrl,
            readOnly: true,
            onTap: _selecionarData,
            decoration: const InputDecoration(labelText: 'Data do sinistro *', border: OutlineInputBorder(), isDense: true, suffixIcon: Icon(Icons.calendar_today, size: 16)),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            value: _tipo,
            decoration: const InputDecoration(labelText: 'Tipo *', border: OutlineInputBorder(), isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('Selecione...')),
              for (final t in tiposSinistro) DropdownMenuItem(value: t, child: Text(t)),
            ],
            onChanged: (v) => setState(() => _tipo = v),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            value: _gravidade,
            decoration: const InputDecoration(labelText: 'Gravidade', border: OutlineInputBorder(), isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('Selecione...')),
              for (final g in gravidadesSinistro) DropdownMenuItem(value: g, child: Text(g)),
            ],
            onChanged: (v) => setState(() => _gravidade = v),
          ),
          const SizedBox(height: 10),
          TextField(controller: _motoristaCtrl, decoration: const InputDecoration(labelText: 'Motorista', border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 10),
          TextField(controller: _localCtrl, decoration: const InputDecoration(labelText: 'Local da ocorrência', border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 10),
          TextField(
            controller: _custoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Custo estimado (R\$)', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            value: _houveVitima,
            onChanged: (v) => setState(() => _houveVitima = v ?? false),
            title: const Text('Houve vítima', style: TextStyle(fontSize: 13)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _descricaoCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Descrição', hintText: 'Circunstâncias do sinistro...', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _salvando ? null : _salvar,
              child: Text(_salvando ? 'Salvando...' : 'Registrar Sinistro'),
            ),
          ),
        ],
      ),
    );
  }
}
