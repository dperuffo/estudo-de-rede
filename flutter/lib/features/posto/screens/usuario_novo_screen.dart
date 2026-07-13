import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/usuarios_provider.dart';
import '../services/usuarios_service.dart';

// Fase FLT-2 — convidar novo usuário pro time do posto. Sem o seletor de
// "Cliente"/perfil da web — aqui é sempre um convite pro time do posto
// atual (perfil 'posto', segmento 'Revenda' fixos, ver comentário em
// usuarios_service.dart). Convite de verdade passa pela rota
// /api/usuarios/convidar (site Next.js) — ver comentário completo lá.
class UsuarioNovoScreen extends ConsumerStatefulWidget {
  const UsuarioNovoScreen({super.key});

  @override
  ConsumerState<UsuarioNovoScreen> createState() => _UsuarioNovoScreenState();
}

class _UsuarioNovoScreenState extends ConsumerState<UsuarioNovoScreen> {
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _cpfCtrl.dispose();
    _telefoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _convidar() async {
    final sessao = await ref.read(sessaoProvider.future);
    final empresaId = sessao.empresaId;
    if (empresaId == null) return;

    setState(() {
      _enviando = true;
      _erro = null;
    });

    final erro = await UsuariosService().convidarUsuario(
      empresaId: empresaId,
      nome: _nomeCtrl.text,
      email: _emailCtrl.text,
      cpf: _cpfCtrl.text,
      telefone: _telefoneCtrl.text,
    );

    if (!mounted) return;
    if (erro != null) {
      setState(() {
        _enviando = false;
        _erro = erro;
      });
      return;
    }

    ref.invalidate(usuariosPostoProvider);
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Convidar usuário')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'O convidado recebe um e-mail com um link para criar a própria senha e passa a ter acesso ao painel deste posto.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nomeCtrl,
            decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _emailCtrl,
            decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _cpfCtrl,
            decoration: const InputDecoration(labelText: 'CPF (opcional)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _telefoneCtrl,
            decoration: const InputDecoration(labelText: 'Telefone (opcional)', border: OutlineInputBorder()),
          ),
          if (_erro != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
              child: Text(_erro!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _enviando ? null : _convidar,
              child: Text(_enviando ? 'Convidando...' : 'Convidar'),
            ),
          ),
        ],
      ),
    );
  }
}
