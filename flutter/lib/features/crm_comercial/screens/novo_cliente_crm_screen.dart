import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/crm_provider.dart';
import '../services/crm_service.dart';

// Fase Grupo 2 (Rodopar/Datapar, item 5, 03/08/2026) — cadastro de cliente,
// porta de crm-comercial/clientes/novo/page.tsx + ClienteForm.tsx.
class NovoClienteCrmScreen extends ConsumerStatefulWidget {
  const NovoClienteCrmScreen({super.key});

  @override
  ConsumerState<NovoClienteCrmScreen> createState() => _NovoClienteCrmScreenState();
}

class _NovoClienteCrmScreenState extends ConsumerState<NovoClienteCrmScreen> {
  final _cnpjCpfCtrl = TextEditingController();
  final _razaoSocialCtrl = TextEditingController();
  final _ieCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _logradouroCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _bairroCtrl = TextEditingController();
  final _municipioCtrl = TextEditingController();
  final _ufCtrl = TextEditingController();
  final _cepCtrl = TextEditingController();
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _cnpjCpfCtrl.dispose();
    _razaoSocialCtrl.dispose();
    _ieCtrl.dispose();
    _telefoneCtrl.dispose();
    _emailCtrl.dispose();
    _logradouroCtrl.dispose();
    _numeroCtrl.dispose();
    _bairroCtrl.dispose();
    _municipioCtrl.dispose();
    _ufCtrl.dispose();
    _cepCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    final cnpjCpf = _cnpjCpfCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (cnpjCpf.length != 11 && cnpjCpf.length != 14) {
      setState(() => _erro = 'Informe um CNPJ ou CPF válido.');
      return;
    }
    if (_razaoSocialCtrl.text.trim().isEmpty) {
      setState(() => _erro = 'Informe a razão social ou nome do cliente.');
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
      await CrmService().criarCliente(
        empresaId: empresaId,
        cnpjCpf: cnpjCpf,
        razaoSocial: _razaoSocialCtrl.text.trim(),
        ie: _ieCtrl.text.trim().isEmpty ? null : _ieCtrl.text.trim(),
        telefone: _telefoneCtrl.text.trim().isEmpty ? null : _telefoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        enderecoLogradouro: _logradouroCtrl.text.trim().isEmpty ? null : _logradouroCtrl.text.trim(),
        enderecoNumero: _numeroCtrl.text.trim().isEmpty ? null : _numeroCtrl.text.trim(),
        enderecoBairro: _bairroCtrl.text.trim().isEmpty ? null : _bairroCtrl.text.trim(),
        enderecoMunicipio: _municipioCtrl.text.trim().isEmpty ? null : _municipioCtrl.text.trim(),
        enderecoUf: _ufCtrl.text.trim().isEmpty ? null : _ufCtrl.text.trim().toUpperCase(),
        enderecoCep: _cepCtrl.text.trim().isEmpty ? null : _cepCtrl.text.replaceAll(RegExp(r'\D'), ''),
        criadoPor: sessao.email,
      );
      if (!mounted) return;
      ref.invalidate(clientesCrmListProvider);
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
      appBar: AppBar(title: const Text('Novo Cliente')),
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
          TextField(
            controller: _cnpjCpfCtrl,
            decoration: const InputDecoration(labelText: 'CNPJ ou CPF *', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _razaoSocialCtrl,
            decoration: const InputDecoration(labelText: 'Razão social / Nome *', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(controller: _ieCtrl, decoration: const InputDecoration(labelText: 'Inscrição estadual', border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 10),
          TextField(controller: _telefoneCtrl, decoration: const InputDecoration(labelText: 'Telefone', border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 10),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 16),
          const Text('Endereço', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 10),
          TextField(controller: _logradouroCtrl, decoration: const InputDecoration(labelText: 'Logradouro', border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 10),
          TextField(controller: _numeroCtrl, decoration: const InputDecoration(labelText: 'Número', border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 10),
          TextField(controller: _bairroCtrl, decoration: const InputDecoration(labelText: 'Bairro', border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 10),
          TextField(controller: _municipioCtrl, decoration: const InputDecoration(labelText: 'Município', border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextField(controller: _ufCtrl, maxLength: 2, decoration: const InputDecoration(labelText: 'UF', border: OutlineInputBorder(), isDense: true, counterText: ''))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: TextField(controller: _cepCtrl, decoration: const InputDecoration(labelText: 'CEP', border: OutlineInputBorder(), isDense: true))),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _salvando ? null : _salvar,
              child: Text(_salvando ? 'Salvando...' : 'Cadastrar Cliente'),
            ),
          ),
        ],
      ),
    );
  }
}
