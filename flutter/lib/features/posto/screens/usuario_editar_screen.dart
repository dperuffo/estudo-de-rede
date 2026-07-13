import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/usuarios_provider.dart';
import '../services/usuarios_service.dart';

// Fase FLT-2 — editar usuário existente + ativar/inativar, porta de
// usuarios/[email]/page.tsx (UsuarioForm.tsx em modo edição). Sem edição
// de perfil/segmento (fixos como 'posto'/'Revenda' desde o convite — ver
// usuarios_service.dart) nem de vínculo de empresa ("gerenciado em outra
// tela", mesmo texto da web). MFA aparece só como leitura — não existe
// resetar MFA de terceiros nem na web.
class UsuarioEditarScreen extends ConsumerStatefulWidget {
  final String email;
  const UsuarioEditarScreen({super.key, required this.email});

  @override
  ConsumerState<UsuarioEditarScreen> createState() => _UsuarioEditarScreenState();
}

class _UsuarioEditarScreenState extends ConsumerState<UsuarioEditarScreen> {
  final _nomeCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  bool _ativo = true;
  bool _inicializado = false;
  bool _salvando = false;
  String? _erro;
  String? _sucesso;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cpfCtrl.dispose();
    _telefoneCtrl.dispose();
    super.dispose();
  }

  void _inicializar(UsuarioDoPosto u) {
    if (_inicializado) return;
    _inicializado = true;
    _nomeCtrl.text = u.nome ?? '';
    _cpfCtrl.text = u.cpf ?? '';
    _telefoneCtrl.text = u.telefone ?? '';
    _ativo = u.ativo;
  }

  Future<void> _salvar() async {
    setState(() {
      _salvando = true;
      _erro = null;
      _sucesso = null;
    });
    final erro = await UsuariosService().atualizarUsuario(
      email: widget.email,
      nome: _nomeCtrl.text,
      cpf: _cpfCtrl.text,
      telefone: _telefoneCtrl.text,
      ativo: _ativo,
    );
    if (!mounted) return;
    setState(() {
      _salvando = false;
      if (erro != null) {
        _erro = erro;
      } else {
        _sucesso = 'Salvo.';
      }
    });
    if (erro == null) ref.invalidate(usuariosPostoProvider);
  }

  Future<void> _alternarAtivo(bool novoValor) async {
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final erro = await UsuariosService().alternarAtivo(email: widget.email, ativo: novoValor);
    if (!mounted) return;
    setState(() {
      _salvando = false;
      if (erro != null) {
        _erro = erro;
      } else {
        _ativo = novoValor;
      }
    });
    if (erro == null) ref.invalidate(usuariosPostoProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(usuarioDetalheProvider(widget.email));

    return Scaffold(
      appBar: AppBar(title: const Text('Editar usuário')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (u) {
          if (u == null) return const Center(child: Text('Usuário não encontrado.'));
          _inicializar(u);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(u.email, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _cpfCtrl,
                decoration: const InputDecoration(labelText: 'CPF', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _telefoneCtrl,
                decoration: const InputDecoration(labelText: 'Telefone', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                value: _ativo,
                onChanged: _salvando ? null : _alternarAtivo,
                title: const Text('Usuário ativo'),
                contentPadding: EdgeInsets.zero,
              ),
              Row(
                children: [
                  const Text('MFA: ', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  Text(u.mfaHabilitado ? 'Habilitado' : 'Pendente',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: u.mfaHabilitado ? const Color(0xFF16A34A) : const Color(0xFFB45309),
                      )),
                ],
              ),
              const Text(
                'A ativação do segundo fator (MFA) é feita pelo próprio usuário no primeiro acesso.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              if (_erro != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                  child: Text(_erro!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
                ),
              ],
              if (_sucesso != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
                  child: Text(_sucesso!, style: const TextStyle(color: Color(0xFF15803D), fontSize: 13)),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _salvando ? null : _salvar,
                  child: Text(_salvando ? 'Salvando...' : 'Salvar'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
