import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/grupo_economico_admin_provider.dart';
import '../services/grupo_economico_admin_service.dart';

// Fase FLT-4 — Grupo Econômico (admin): criar Grupo, porta de
// grupo-economico/novo/page.tsx. Diferente de Nova Rede de Postos, não
// há "fundador" obrigatório — o Grupo é criado vazio (INSERT direto, sem
// RPC) e as empresas são vinculadas depois na tela de detalhe.
class NovoGrupoEconomicoAdminScreen extends ConsumerStatefulWidget {
  const NovoGrupoEconomicoAdminScreen({super.key});

  @override
  ConsumerState<NovoGrupoEconomicoAdminScreen> createState() => _NovoGrupoEconomicoAdminScreenState();
}

class _NovoGrupoEconomicoAdminScreenState extends ConsumerState<NovoGrupoEconomicoAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cnpjCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });

    final resultado = await GrupoEconomicoAdminService().criarGrupo(
      nome: _nomeCtrl.text,
      cnpjMatriz: _cnpjCtrl.text,
    );

    if (!mounted) return;
    if (resultado.erro != null) {
      setState(() {
        _salvando = false;
        _erro = resultado.erro;
      });
      return;
    }

    ref.invalidate(gruposEconomicosAdminListaProvider);
    context.pushReplacement('/grupos-economicos/${resultado.id}');
  }

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessaoProvider).valueOrNull;
    final ehAdmin = sessao?.ehAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Novo Grupo Econômico')),
      body: !ehAdmin ? _acessoRestrito() : _conteudo(),
    );
  }

  Widget _acessoRestrito() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Esta tela é exclusiva do time interno (perfil administrador).', style: TextStyle(fontSize: 13, color: Colors.grey)),
        ),
      ),
    );
  }

  Widget _conteudo() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_erro != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
              child: Text(_erro!, style: const TextStyle(color: Color(0xFFB91C1C))),
            ),
          const Text('Nome do Grupo *', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nomeCtrl,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
          ),
          const SizedBox(height: 16),
          const Text('CNPJ da Matriz (opcional)', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _cnpjCtrl,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 4),
          const Text(
            'Você poderá vincular as empresas clientes depois de criar o Grupo.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _salvando ? null : _salvar,
              child: Text(_salvando ? 'Salvando...' : 'Salvar Grupo'),
            ),
          ),
        ],
      ),
    );
  }
}
