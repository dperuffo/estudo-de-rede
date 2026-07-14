import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sessao_provider.dart';
import '../../motoristas/providers/motoristas_provider.dart' show motoristasClienteProvider;
import '../../veiculos/providers/veiculos_provider.dart' show veiculosClienteProvider;
import '../providers/parametros_uso_provider.dart';
import '../services/parametros_uso_service.dart';

class VinculoNovoScreen extends ConsumerStatefulWidget {
  const VinculoNovoScreen({super.key});

  @override
  ConsumerState<VinculoNovoScreen> createState() => _VinculoNovoScreenState();
}

class _VinculoNovoScreenState extends ConsumerState<VinculoNovoScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _placa;
  String? _motoristaId;
  final _observacaoCtrl = TextEditingController();
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _observacaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    final sessao = await ref.read(sessaoProvider.future);
    final empresaId = sessao.empresaId;
    if (empresaId == null) {
      setState(() => _erro = 'Não foi possível identificar sua empresa na sessão atual.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final erro = await ParametrosUsoService().criarVinculo(
      empresaId: empresaId,
      placa: _placa!,
      motoristaId: _motoristaId!,
      observacao: _observacaoCtrl.text,
    );
    if (!mounted) return;
    setState(() => _salvando = false);
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    ref.invalidate(vinculosProvider);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final veiculosAsync = ref.watch(veiculosClienteProvider);
    final motoristasAsync = ref.watch(motoristasClienteProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Novo Vínculo')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Associa um motorista a um veículo específico. Abastecimentos feitos em postos ou soluções de '
              'automação integradas via API podem ser autorizados apenas quando o par estiver ativo neste cadastro.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
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
                value: _placa,
                decoration: const InputDecoration(labelText: 'Veículo (placa) *', border: OutlineInputBorder()),
                items: [for (final v in veiculos) DropdownMenuItem(value: v.placa, child: Text(v.placa))],
                onChanged: (v) => setState(() => _placa = v),
                validator: (v) => v == null ? 'Selecione um veículo' : null,
              ),
            ),
            const SizedBox(height: 10),
            motoristasAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Erro ao carregar motoristas: $e'),
              data: (motoristas) => DropdownButtonFormField<String>(
                value: _motoristaId,
                decoration: const InputDecoration(labelText: 'Motorista *', border: OutlineInputBorder()),
                items: [for (final m in motoristas) DropdownMenuItem(value: m.id, child: Text(m.nomeCompleto))],
                onChanged: (v) => setState(() => _motoristaId = v),
                validator: (v) => v == null ? 'Selecione um motorista' : null,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _observacaoCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Observação', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _salvando ? null : _salvar,
              child: _salvando
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Salvar Vínculo'),
            ),
          ],
        ),
      ),
    );
  }
}
