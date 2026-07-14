import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../posto/providers/rede_posto_provider.dart' show RedePostoDetalhe;
import '../../posto/services/rede_postos_service.dart';
import '../providers/rede_postos_admin_provider.dart';

// Fase FLT-4 — Rede de Postos (admin): edição de uma Rede por id
// arbitrário + vínculos, porta de rede-postos/[id]/page.tsx (caminho
// ehAdmin). Reaproveita o RedePostosService inteiro (Fase FLT-2) — as
// mesmas atualizarRede/vincularPosto/desvincularPosto que o posto usa,
// sem nenhuma mudança, porque já operam por redeId/empresaId explícitos.
// Ver escopo completo em rede_postos_admin_provider.dart.
class RedePostoAdminDetalheScreen extends ConsumerStatefulWidget {
  final String redeId;
  const RedePostoAdminDetalheScreen({super.key, required this.redeId});

  @override
  ConsumerState<RedePostoAdminDetalheScreen> createState() => _RedePostoAdminDetalheScreenState();
}

class _RedePostoAdminDetalheScreenState extends ConsumerState<RedePostoAdminDetalheScreen> {
  final _nomeCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();
  bool _ativo = true;
  bool _preenchido = false;
  bool _salvando = false;
  String? _erroEdicao;

  String? _postoParaVincular;
  bool _vinculando = false;
  String? _erroVinculo;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cnpjCtrl.dispose();
    super.dispose();
  }

  void _preencherSeNecessario(RedePostoDetalhe rede) {
    if (_preenchido) return;
    _preenchido = true;
    _nomeCtrl.text = rede.nome;
    _cnpjCtrl.text = rede.cnpjMatriz ?? '';
    _ativo = rede.ativo;
  }

  Future<void> _salvarEdicao() async {
    setState(() {
      _salvando = true;
      _erroEdicao = null;
    });
    final erro = await RedePostosService().atualizarRede(
      redeId: widget.redeId,
      nome: _nomeCtrl.text,
      cnpjMatriz: _cnpjCtrl.text,
      ativo: _ativo,
    );
    if (!mounted) return;
    setState(() => _salvando = false);
    if (erro != null) {
      setState(() => _erroEdicao = erro);
      return;
    }
    ref.invalidate(redePostoAdminDetalheProvider(widget.redeId));
    ref.invalidate(redesPostosAdminListaProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rede atualizada.')));
    }
  }

  Future<void> _vincular() async {
    if (_postoParaVincular == null) return;
    setState(() {
      _vinculando = true;
      _erroVinculo = null;
    });
    final erro = await RedePostosService().vincularPosto(redeId: widget.redeId, empresaId: _postoParaVincular!);
    if (!mounted) return;
    setState(() => _vinculando = false);
    if (erro != null) {
      setState(() => _erroVinculo = erro);
      return;
    }
    _postoParaVincular = null;
    ref.invalidate(redePostoAdminDetalheProvider(widget.redeId));
    ref.invalidate(redesPostosAdminListaProvider);
  }

  Future<void> _desvincular(String vinculoId) async {
    final erro = await RedePostosService().desvincularPosto(vinculoId: vinculoId);
    if (!mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    ref.invalidate(redePostoAdminDetalheProvider(widget.redeId));
    ref.invalidate(redesPostosAdminListaProvider);
  }

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessaoProvider).valueOrNull;
    final ehAdmin = sessao?.ehAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Rede de Postos')),
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
    final redeAsync = ref.watch(redePostoAdminDetalheProvider(widget.redeId));
    return redeAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
      data: (rede) {
        if (rede == null) return const Center(child: Text('Rede não encontrada.'));
        _preencherSeNecessario(rede);
        return _buildDetalhe(rede);
      },
    );
  }

  Widget _buildDetalhe(RedePostoDetalhe rede) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dados da Rede', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                if (_erroEdicao != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_erroEdicao!, style: const TextStyle(color: Colors.red)),
                  ),
                const Text('Nome da Rede', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                TextField(controller: _nomeCtrl, decoration: const InputDecoration(border: OutlineInputBorder())),
                const SizedBox(height: 12),
                const Text('CNPJ da Matriz', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                TextField(controller: _cnpjCtrl, decoration: const InputDecoration(border: OutlineInputBorder())),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _ativo,
                  onChanged: (v) => setState(() => _ativo = v),
                  title: const Text('Rede ativa'),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _salvando ? null : _salvarEdicao,
                    child: Text(_salvando ? 'Salvando...' : 'Salvar alterações'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Postos vinculados (${rede.vinculos.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                if (rede.vinculos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Nenhum posto vinculado ainda.', style: TextStyle(color: Colors.grey)),
                  )
                else
                  ...rede.vinculos.map((v) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(v.nome),
                        trailing: TextButton(
                          onPressed: () => _desvincular(v.vinculoId),
                          child: const Text('Remover', style: TextStyle(color: Colors.red)),
                        ),
                      )),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Vincular novo posto', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _buildSeletorVincular(rede),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeletorVincular(RedePostoDetalhe rede) {
    final postosAsync = ref.watch(postosTodosProvider);
    return postosAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Erro: $e', style: const TextStyle(color: Colors.red)),
      data: (todos) {
        final jaVinculados = rede.vinculos.map((v) => v.empresaId).toSet();
        final disponiveis = todos.where((p) => !jaVinculados.contains(p.id)).toList();
        if (disponiveis.isEmpty) {
          return const Text(
            'Nenhum outro posto do sistema disponível para vincular.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_erroVinculo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_erroVinculo!, style: const TextStyle(color: Colors.red)),
              ),
            DropdownButtonFormField<String>(
              value: _postoParaVincular,
              hint: const Text('Selecione um posto para vincular...'),
              items: disponiveis.map((p) => DropdownMenuItem(value: p.id, child: Text(p.nome))).toList(),
              onChanged: (v) => setState(() => _postoParaVincular = v),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: (_vinculando || _postoParaVincular == null) ? null : _vincular,
              child: Text(_vinculando ? 'Vinculando...' : 'Vincular'),
            ),
          ],
        );
      },
    );
  }
}
