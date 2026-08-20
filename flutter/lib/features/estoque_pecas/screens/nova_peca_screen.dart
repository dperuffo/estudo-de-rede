import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/estoque_pecas_provider.dart';
import '../services/estoque_pecas_service.dart';

import '../../../core/theme/app_theme.dart';

// Fase Grupo 1 Rodopar item 2 (03/08/2026) — cadastro de peça, porta de
// estoque-pecas/nova/page.tsx + NovaPecaForm.tsx.
class NovaPecaScreen extends ConsumerStatefulWidget {
  const NovaPecaScreen({super.key});

  @override
  ConsumerState<NovaPecaScreen> createState() => _NovaPecaScreenState();
}

class _NovaPecaScreenState extends ConsumerState<NovaPecaScreen> {
  final _nomeCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  String _unidadeMedida = 'un';
  final _minimaCtrl = TextEditingController(text: '0');
  final _inicialCtrl = TextEditingController();
  final _custoCtrl = TextEditingController();
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _codigoCtrl.dispose();
    _minimaCtrl.dispose();
    _inicialCtrl.dispose();
    _custoCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    if (_nomeCtrl.text.trim().isEmpty) {
      setState(() => _erro = 'Nome da peça é obrigatório.');
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
      await EstoquePecasService().criarPeca(
        empresaId: empresaId,
        nome: _nomeCtrl.text.trim(),
        codigo:
            _codigoCtrl.text.trim().isEmpty ? null : _codigoCtrl.text.trim(),
        unidadeMedida: _unidadeMedida,
        quantidadeMinima:
            double.tryParse(_minimaCtrl.text.replaceAll(',', '.')) ?? 0,
        quantidadeInicial:
            double.tryParse(_inicialCtrl.text.replaceAll(',', '.')),
        custoUnitario: double.tryParse(_custoCtrl.text.replaceAll(',', '.')),
        criadoPor: sessao.email,
      );
      if (!mounted) return;
      ref.invalidate(pecasEstoqueListProvider);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível cadastrar: $e';
        _salvando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Nova Peça')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_erro != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_erro!,
                  style:
                      const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
            ),
          TextField(
            controller: _nomeCtrl,
            decoration: const InputDecoration(
                labelText: 'Nome da peça *',
                hintText: 'Filtro de óleo, pastilha de freio...',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
              controller: _codigoCtrl,
              decoration: const InputDecoration(
                  labelText: 'Código / SKU',
                  border: OutlineInputBorder(),
                  isDense: true)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _unidadeMedida,
            decoration: const InputDecoration(
                labelText: 'Unidade de medida',
                border: OutlineInputBorder(),
                isDense: true),
            items: const [
              DropdownMenuItem(value: 'un', child: Text('Unidade (un)')),
              DropdownMenuItem(value: 'l', child: Text('Litro (l)')),
              DropdownMenuItem(value: 'kg', child: Text('Quilo (kg)')),
              DropdownMenuItem(value: 'par', child: Text('Par')),
              DropdownMenuItem(value: 'jogo', child: Text('Jogo')),
            ],
            onChanged: (v) => setState(() => _unidadeMedida = v ?? 'un'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _minimaCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Estoque mínimo',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _inicialCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Estoque inicial (opcional)',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _custoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Custo unitário (estoque inicial)',
                hintText: 'R\$',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _salvando ? null : _salvar,
              child: Text(_salvando ? 'Salvando...' : 'Cadastrar Peça'),
            ),
          ),
        ],
      ),
    );
  }
}
