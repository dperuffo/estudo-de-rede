import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/rede_posto_provider.dart';
import '../services/rede_postos_service.dart';

// Fase FLT-2 — porta de src/app/(dashboard)/rede-postos/page.tsx (lista,
// aqui não se aplica — visão admin) + rede-postos/[id]/page.tsx (edição +
// vínculos, que É o que o posto vê). Escopo reduzido: só mostra/gerencia a
// Rede da PRÓPRIA empresa atual (nunca a lista global de todas as Redes,
// que é admin-only na web).
class RedePostosScreen extends ConsumerStatefulWidget {
  const RedePostosScreen({super.key});

  @override
  ConsumerState<RedePostosScreen> createState() => _RedePostosScreenState();
}

class _RedePostosScreenState extends ConsumerState<RedePostosScreen> {
  final _nomeCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();
  bool _ativo = true;
  String? _redeIdCarregada;
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
    if (_redeIdCarregada == rede.id) return;
    _redeIdCarregada = rede.id;
    _nomeCtrl.text = rede.nome;
    _cnpjCtrl.text = rede.cnpjMatriz ?? '';
    _ativo = rede.ativo;
  }

  Future<void> _salvarEdicao(String redeId) async {
    setState(() {
      _salvando = true;
      _erroEdicao = null;
    });
    final erro = await RedePostosService().atualizarRede(
      redeId: redeId,
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
    ref.invalidate(redePostoProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rede atualizada.')));
    }
  }

  Future<void> _vincular(String redeId) async {
    if (_postoParaVincular == null) return;
    setState(() {
      _vinculando = true;
      _erroVinculo = null;
    });
    final erro = await RedePostosService().vincularPosto(redeId: redeId, empresaId: _postoParaVincular!);
    if (!mounted) return;
    setState(() => _vinculando = false);
    if (erro != null) {
      setState(() => _erroVinculo = erro);
      return;
    }
    _postoParaVincular = null;
    ref.invalidate(redePostoProvider);
  }

  Future<void> _desvincular(String vinculoId) async {
    final erro = await RedePostosService().desvincularPosto(vinculoId: vinculoId);
    if (!mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    ref.invalidate(redePostoProvider);
  }

  @override
  Widget build(BuildContext context) {
    final redeAsync = ref.watch(redePostoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Rede de Postos')),
      body: redeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (rede) {
          if (rede == null) return _buildVazio(context);
          _preencherSeNecessario(rede);
          return _buildDetalhe(context, rede);
        },
      ),
    );
  }

  Widget _buildVazio(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hub_outlined, size: 56, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Seu posto ainda não faz parte de uma Rede de Postos.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Uma Rede agrupa postos sob a mesma bandeira/grupo — usuários vinculados a um '
            'posto da Rede passam a ver os postos irmãos nas telas do sistema.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.push('/posto/rede-postos/nova'),
            icon: const Icon(Icons.add),
            label: const Text('Criar Rede de Postos'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalhe(BuildContext context, RedePostoDetalhe rede) {
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
                    onPressed: _salvando ? null : () => _salvarEdicao(rede.id),
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
    final postosAsync = ref.watch(postosProprioProvider);
    return postosAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Erro: $e', style: const TextStyle(color: Colors.red)),
      data: (todos) {
        final jaVinculados = rede.vinculos.map((v) => v.empresaId).toSet();
        final disponiveis = todos.where((p) => !jaVinculados.contains(p.id)).toList();
        if (disponiveis.isEmpty) {
          return const Text(
            'Nenhum outro posto seu disponível para vincular.',
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
              onPressed: (_vinculando || _postoParaVincular == null) ? null : () => _vincular(rede.id),
              child: Text(_vinculando ? 'Vinculando...' : 'Vincular'),
            ),
          ],
        );
      },
    );
  }
}
