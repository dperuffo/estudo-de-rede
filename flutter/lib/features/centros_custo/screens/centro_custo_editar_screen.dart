import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../motoristas/providers/motoristas_provider.dart';
import '../providers/centros_custo_provider.dart';
import '../services/centros_custo_service.dart';

// Fase FLT-3 — edição do centro de custo + alocação de motoristas. A web
// também permite alocar/desalocar VEÍCULOS aqui (fora do escopo, ver
// comentário em centros_custo_provider.dart).
class CentroCustoEditarScreen extends ConsumerStatefulWidget {
  final String id;
  const CentroCustoEditarScreen({super.key, required this.id});

  @override
  ConsumerState<CentroCustoEditarScreen> createState() => _CentroCustoEditarScreenState();
}

class _CentroCustoEditarScreenState extends ConsumerState<CentroCustoEditarScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _responsavelCtrl = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  bool _ativo = true;
  bool _salvando = false;
  bool _preenchido = false;
  final Set<String> _selecionados = {};

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _codigoCtrl.dispose();
    _responsavelCtrl.dispose();
    _descricaoCtrl.dispose();
    super.dispose();
  }

  void _preencher(CentroCusto c) {
    _nomeCtrl.text = c.nome;
    _codigoCtrl.text = c.codigo ?? '';
    _responsavelCtrl.text = c.responsavel ?? '';
    _descricaoCtrl.text = c.descricao ?? '';
    _ativo = c.ativo;
    _preenchido = true;
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    final erro = await CentrosCustoService().atualizarCentroCusto(
      id: widget.id,
      nome: _nomeCtrl.text,
      codigo: _codigoCtrl.text,
      responsavel: _responsavelCtrl.text,
      descricao: _descricaoCtrl.text,
      ativo: _ativo,
    );
    if (!mounted) return;
    setState(() => _salvando = false);
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    ref.invalidate(centrosCustoClienteProvider);
    ref.invalidate(centroCustoDetalheProvider(widget.id));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alterações salvas.')));
    }
  }

  Future<void> _alocarSelecionados() async {
    if (_selecionados.isEmpty) return;
    final erro = await CentrosCustoService()
        .alocarMotoristas(centroCustoId: widget.id, motoristaIds: _selecionados.toList());
    if (!mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    setState(() => _selecionados.clear());
    ref.invalidate(motoristasClienteProvider);
    ref.invalidate(centrosCustoClienteProvider);
  }

  Future<void> _desalocar(String motoristaId) async {
    final erro = await CentrosCustoService().desalocarMotoristas(motoristaIds: [motoristaId]);
    if (!mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    ref.invalidate(motoristasClienteProvider);
    ref.invalidate(centrosCustoClienteProvider);
  }

  @override
  Widget build(BuildContext context) {
    final detalheAsync = ref.watch(centroCustoDetalheProvider(widget.id));
    final motoristasAsync = ref.watch(motoristasClienteProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Centro de Custo')),
      body: detalheAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (c) {
          if (c == null) return const Center(child: Text('Centro de custo não encontrado.'));
          if (!_preenchido) _preencher(c);

          return Form(
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
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ativo'),
                  value: _ativo,
                  onChanged: (v) => setState(() => _ativo = v),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _salvando ? null : _salvar,
                  child: _salvando
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Salvar alterações'),
                ),
                const Divider(height: 40),
                Text('Motoristas alocados', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                motoristasAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('Erro ao carregar motoristas: $e'),
                  data: (motoristas) {
                    final alocados = motoristas.where((m) => m.centroCustoId == widget.id).toList();
                    final disponiveis =
                        motoristas.where((m) => m.centroCustoId != widget.id && m.ativo).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (alocados.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Nenhum motorista alocado ainda.', style: TextStyle(color: Colors.grey)),
                          )
                        else
                          ...alocados.map((m) => Card(
                                margin: const EdgeInsets.only(bottom: 6),
                                child: ListTile(
                                  dense: true,
                                  title: Text(m.nomeCompleto),
                                  subtitle: Text('CPF ${m.cpf}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.link_off, size: 20),
                                    tooltip: 'Remover deste centro de custo',
                                    onPressed: () => _desalocar(m.id),
                                  ),
                                ),
                              )),
                        const SizedBox(height: 16),
                        if (disponiveis.isNotEmpty) ...[
                          Text('Alocar motoristas', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 4),
                          ...disponiveis.map((m) => CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(m.nomeCompleto),
                                subtitle: Text(m.centroCustoNome == null
                                    ? 'Sem centro de custo'
                                    : 'Atualmente em ${m.centroCustoNome}'),
                                value: _selecionados.contains(m.id),
                                onChanged: (v) => setState(() {
                                  if (v == true) {
                                    _selecionados.add(m.id);
                                  } else {
                                    _selecionados.remove(m.id);
                                  }
                                }),
                              )),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _selecionados.isEmpty ? null : _alocarSelecionados,
                            child: Text(_selecionados.isEmpty
                                ? 'Selecione motoristas para alocar'
                                : 'Alocar ${_selecionados.length} motorista(s)'),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
