import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/centros_custo_provider.dart';
import '../services/centros_custo_service.dart';

class CentroCustoNovoScreen extends ConsumerStatefulWidget {
  const CentroCustoNovoScreen({super.key});

  @override
  ConsumerState<CentroCustoNovoScreen> createState() => _CentroCustoNovoScreenState();
}

class _CentroCustoNovoScreenState extends ConsumerState<CentroCustoNovoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _responsavelCtrl = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  bool _salvando = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _codigoCtrl.dispose();
    _responsavelCtrl.dispose();
    _descricaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    final sessao = await ref.read(sessaoProvider.future);
    final empresaId = sessao.empresaId;
    if (empresaId == null) {
      setState(() => _salvando = false);
      return;
    }
    final resultado = await CentrosCustoService().criarCentroCusto(
      empresaId: empresaId,
      nome: _nomeCtrl.text,
      codigo: _codigoCtrl.text,
      responsavel: _responsavelCtrl.text,
      descricao: _descricaoCtrl.text,
    );
    if (!mounted) return;
    setState(() => _salvando = false);
    if (resultado.erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resultado.erro!)));
      return;
    }
    ref.invalidate(centrosCustoClienteProvider);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Centro de Custo')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nomeCtrl,
              decoration: const InputDecoration(labelText: 'Nome *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _codigoCtrl,
              decoration: const InputDecoration(labelText: 'Código', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _responsavelCtrl,
              decoration: const InputDecoration(labelText: 'Responsável', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descricaoCtrl,
              decoration: const InputDecoration(labelText: 'Descrição', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _salvando ? null : _salvar,
              child: _salvando
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Criar centro de custo'),
            ),
          ],
        ),
      ),
    );
  }
}
