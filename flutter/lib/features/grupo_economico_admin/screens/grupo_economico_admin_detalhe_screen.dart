import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../grupo_economico/providers/grupo_economico_provider.dart' show GrupoEconomicoDetalhe;
import '../providers/grupo_economico_admin_provider.dart';
import '../services/grupo_economico_admin_service.dart';

// Fase FLT-4 — Grupo Econômico (admin): edição de um Grupo por id
// arbitrário + vínculos, porta de grupo-economico/[id]/page.tsx.
// Estruturalmente idêntica a rede_posto_admin_detalhe_screen.dart — só
// troca o service/provider por trás (GrupoEconomicoAdminService em vez
// de RedePostosService). Ver escopo completo em
// grupo_economico_admin_provider.dart.
class GrupoEconomicoAdminDetalheScreen extends ConsumerStatefulWidget {
  final String grupoId;
  const GrupoEconomicoAdminDetalheScreen({super.key, required this.grupoId});

  @override
  ConsumerState<GrupoEconomicoAdminDetalheScreen> createState() => _GrupoEconomicoAdminDetalheScreenState();
}

class _GrupoEconomicoAdminDetalheScreenState extends ConsumerState<GrupoEconomicoAdminDetalheScreen> {
  final _nomeCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();
  bool _ativo = true;
  bool _preenchido = false;
  bool _salvando = false;
  String? _erroEdicao;

  String? _empresaParaVincular;
  bool _vinculando = false;
  String? _erroVinculo;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cnpjCtrl.dispose();
    super.dispose();
  }

  void _preencherSeNecessario(GrupoEconomicoDetalhe grupo) {
    if (_preenchido) return;
    _preenchido = true;
    _nomeCtrl.text = grupo.nome;
    _cnpjCtrl.text = grupo.cnpjMatriz ?? '';
    _ativo = grupo.ativo;
  }

  Future<void> _salvarEdicao() async {
    setState(() {
      _salvando = true;
      _erroEdicao = null;
    });
    final erro = await GrupoEconomicoAdminService().atualizarGrupo(
      grupoId: widget.grupoId,
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
    ref.invalidate(grupoEconomicoAdminDetalheProvider(widget.grupoId));
    ref.invalidate(gruposEconomicosAdminListaProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Grupo atualizado.')));
    }
  }

  Future<void> _vincular() async {
    if (_empresaParaVincular == null) return;
    setState(() {
      _vinculando = true;
      _erroVinculo = null;
    });
    final erro = await GrupoEconomicoAdminService()
        .vincularEmpresa(grupoId: widget.grupoId, empresaId: _empresaParaVincular!);
    if (!mounted) return;
    setState(() => _vinculando = false);
    if (erro != null) {
      setState(() => _erroVinculo = erro);
      return;
    }
    _empresaParaVincular = null;
    ref.invalidate(grupoEconomicoAdminDetalheProvider(widget.grupoId));
    ref.invalidate(gruposEconomicosAdminListaProvider);
  }

  Future<void> _desvincular(String vinculoId) async {
    final erro = await GrupoEconomicoAdminService().desvincularEmpresa(vinculoId: vinculoId);
    if (!mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    ref.invalidate(grupoEconomicoAdminDetalheProvider(widget.grupoId));
    ref.invalidate(gruposEconomicosAdminListaProvider);
  }

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessaoProvider).valueOrNull;
    final ehAdmin = sessao?.ehAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Grupo Econômico')),
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
    final grupoAsync = ref.watch(grupoEconomicoAdminDetalheProvider(widget.grupoId));
    return grupoAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
      data: (grupo) {
        if (grupo == null) return const Center(child: Text('Grupo não encontrado.'));
        _preencherSeNecessario(grupo);
        return _buildDetalhe(grupo);
      },
    );
  }

  Widget _buildDetalhe(GrupoEconomicoDetalhe grupo) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dados do Grupo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                if (_erroEdicao != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_erroEdicao!, style: const TextStyle(color: Colors.red)),
                  ),
                const Text('Nome do Grupo', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                  title: const Text('Grupo ativo'),
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
                Text('Empresas vinculadas (${grupo.vinculos.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                if (grupo.vinculos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Nenhuma empresa vinculada ainda.', style: TextStyle(color: Colors.grey)),
                  )
                else
                  ...grupo.vinculos.map((v) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(v.nome),
                        trailing: TextButton(
                          onPressed: () => _desvincular(v.vinculoId),
                          child: const Text('Remover', style: TextStyle(color: Colors.red)),
                        ),
                      )),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Vincular nova empresa', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _buildSeletorVincular(grupo),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeletorVincular(GrupoEconomicoDetalhe grupo) {
    final empresasAsync = ref.watch(empresasFrotaTodasProvider);
    return empresasAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Erro: $e', style: const TextStyle(color: Colors.red)),
      data: (todas) {
        final jaVinculadas = grupo.vinculos.map((v) => v.empresaId).toSet();
        final disponiveis = todas.where((p) => !jaVinculadas.contains(p.id)).toList();
        if (disponiveis.isEmpty) {
          return const Text(
            'Nenhuma outra empresa do sistema disponível para vincular.',
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
              value: _empresaParaVincular,
              hint: const Text('Selecione uma empresa para vincular...'),
              items: disponiveis.map((p) => DropdownMenuItem(value: p.id, child: Text(p.nome))).toList(),
              onChanged: (v) => setState(() => _empresaParaVincular = v),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: (_vinculando || _empresaParaVincular == null) ? null : _vincular,
              child: Text(_vinculando ? 'Vinculando...' : 'Vincular'),
            ),
          ],
        );
      },
    );
  }
}
