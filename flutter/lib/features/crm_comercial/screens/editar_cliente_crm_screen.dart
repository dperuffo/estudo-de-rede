import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/crm_provider.dart';
import '../services/crm_service.dart';

// Fase Grupo 2 (Rodopar/Datapar, item 5, 03/08/2026) — edição de dados
// cadastrais do cliente, porta do formulário "Dados cadastrais" de
// crm-comercial/clientes/[id]/page.tsx (modo editar do ClienteForm.tsx).
class EditarClienteCrmScreen extends ConsumerStatefulWidget {
  final String clienteId;
  const EditarClienteCrmScreen({super.key, required this.clienteId});

  @override
  ConsumerState<EditarClienteCrmScreen> createState() => _EditarClienteCrmScreenState();
}

class _EditarClienteCrmScreenState extends ConsumerState<EditarClienteCrmScreen> {
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
  bool _preenchido = false;
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
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

  void _preencher(ClienteCrm c) {
    if (_preenchido) return;
    _razaoSocialCtrl.text = c.razaoSocial;
    _ieCtrl.text = c.ie ?? '';
    _telefoneCtrl.text = c.telefone ?? '';
    _emailCtrl.text = c.email ?? '';
    _logradouroCtrl.text = c.enderecoLogradouro ?? '';
    _numeroCtrl.text = c.enderecoNumero ?? '';
    _bairroCtrl.text = c.enderecoBairro ?? '';
    _municipioCtrl.text = c.enderecoMunicipio ?? '';
    _ufCtrl.text = c.enderecoUf ?? '';
    _cepCtrl.text = c.enderecoCep ?? '';
    _preenchido = true;
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    if (_razaoSocialCtrl.text.trim().isEmpty) {
      setState(() => _erro = 'Informe a razão social ou nome do cliente.');
      return;
    }
    setState(() => _salvando = true);
    try {
      await CrmService().editarCliente(
        clienteId: widget.clienteId,
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
      );
      if (!mounted) return;
      ref.invalidate(clienteCrmDetalheProvider(widget.clienteId));
      ref.invalidate(clientesCrmListProvider);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível salvar: $e';
        _salvando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final clienteAsync = ref.watch(clienteCrmDetalheProvider(widget.clienteId));

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Cliente')),
      body: clienteAsync.when(
        data: (c) {
          if (c == null) return const Center(child: Text('Cliente não encontrado.'));
          _preencher(c);
          return ListView(
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
                  child: Text(_salvando ? 'Salvando...' : 'Salvar Alterações'),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
      ),
    );
  }
}
