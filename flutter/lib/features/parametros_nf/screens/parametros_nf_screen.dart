import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../veiculos/providers/veiculos_provider.dart' show veiculosClienteProvider;
import '../providers/parametros_nf_provider.dart';
import '../services/parametros_nf_service.dart';
import 'modal_destino_estado.dart';

// Fase FLT-Parametros-NF — porta de parametros-nf/page.tsx +
// SecaoParametrosNF.tsx. Pedido do Daniel: preferências de emissão de nota
// fiscal por CNPJ da frota, que o cliente configura pelo PWA e ERPs/postos
// consultam depois via API (mesmo dado da web, ver /api/integracoes/
// parametros-nf no Next.js).
class ParametrosNFScreen extends ConsumerStatefulWidget {
  const ParametrosNFScreen({super.key});

  @override
  ConsumerState<ParametrosNFScreen> createState() => _ParametrosNFScreenState();
}

class _ParametrosNFScreenState extends ConsumerState<ParametrosNFScreen> {
  Future<void> _confirmarExcluir(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir regra?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;
    await ParametrosNFService().excluir(id: id);
    ref.invalidate(parametrosNFProvider);
  }

  Future<void> _alternarStatus(String id, bool ativo) async {
    await ParametrosNFService().alternarStatus(id: id, ativo: ativo);
    ref.invalidate(parametrosNFProvider);
  }

  Future<void> _abrirForm() async {
    final sessao = await ref.read(sessaoProvider.future);
    final empresaId = sessao.empresaId;
    if (empresaId == null || !mounted) return;
    final veiculos = await ref.read(veiculosClienteProvider.future);
    if (!mounted) return;
    final cnpjsFrota = {for (final v in veiculos) if (v.cnpjFrota.trim().isNotEmpty) v.cnpjFrota}.toList()..sort();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              controller: scrollController,
              children: [
                Text('Nova Regra — Parâmetros de NF', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _FormParametroNF(empresaId: empresaId, cnpjsFrota: cnpjsFrota, ref: ref),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parâmetros de NF')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirForm,
        icon: const Icon(Icons.add),
        label: const Text('Nova Regra'),
      ),
      body: _lista(),
    );
  }

  Widget _lista() {
    final async = ref.watch(parametrosNFProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
      data: (lista) => ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
        children: [
          const Text(
            'Preferências de emissão de nota fiscal por CNPJ da frota. Sem uma regra específica para o CNPJ, o '
            'posto ou sistema de automação segue a regra padrão (sem CNPJ preenchido), quando existir.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Card(
            color: const Color(0xFFFFFBEB),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Atenção', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF92400E))),
                  SizedBox(height: 4),
                  Text('• A emissão da nota fiscal está sempre sujeita às regras da SEFAZ e à legislação vigente.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E))),
                  Text('• Nem todos os postos têm suporte à opção "Nota no ato do abastecimento".',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E))),
                  Text('• Alterações nestes parâmetros só valem a partir do próximo ciclo de faturamento.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (lista.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Nenhuma regra cadastrada.', style: TextStyle(color: Colors.grey.shade600)),
              ),
            ),
          ...lista.map((r) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.cnpjFrota ?? 'Todos os CNPJs (regra padrão)',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('Exige NF: ${r.exigeNotaFiscal} · Separa NF combustível: ${r.separarNfCombustivel}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      Text('Emissão: ${r.formaEmissao}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      Text(
                          'Destino: ${r.localDestino}${r.cnpjDestinoPersonalizado != null ? ' (${r.cnpjDestinoPersonalizado})' : ''}'
                          '${r.destinoPorUf.isNotEmpty ? ' — ${r.destinoPorUf.length} exceção(ões) por UF' : ''}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      if (r.observacao != null)
                        Text(r.observacao!, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (r.ativo ? const Color(0xFF16A34A) : const Color(0xFF64748B)).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(r.status,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: r.ativo ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                    fontWeight: FontWeight.w600)),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => _alternarStatus(r.id, !r.ativo),
                            child: Text(r.ativo ? 'Inativar' : 'Ativar'),
                          ),
                          TextButton(onPressed: () => _confirmarExcluir(r.id), child: const Text('Excluir')),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _FormParametroNF extends StatefulWidget {
  final String empresaId;
  final List<String> cnpjsFrota;
  final WidgetRef ref;
  const _FormParametroNF({required this.empresaId, required this.cnpjsFrota, required this.ref});

  @override
  State<_FormParametroNF> createState() => _FormParametroNFState();
}

class _FormParametroNFState extends State<_FormParametroNF> {
  final _cnpjCtrl = TextEditingController();
  String _exigeNotaFiscal = opcoesSimNaoNF.first;
  String _separarNfCombustivel = opcoesSimNaoNF.first;
  String _formaEmissao = opcoesFormaEmissaoNF.first;
  String _localDestino = opcoesLocalDestinoNF.first;
  final _cnpjPersonalizadoCtrl = TextEditingController();
  final _dadosAdicionaisCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  // Fase FLT-Parametros-NF-Estado — plano montado pelo sub-modal
  // mostrarModalDestinoEstado, usado só quando _localDestino ==
  // "Personalizado CNPJ por Estado".
  PlanoDestinoEstado? _planoEstado;
  bool _salvando = false;
  String? _erro;

  Future<void> _configurarDestinoEstado() async {
    final plano = await mostrarModalDestinoEstado(
      context,
      cnpjsFrota: widget.cnpjsFrota,
      valorInicial: _planoEstado,
    );
    if (plano != null && mounted) setState(() => _planoEstado = plano);
  }

  Future<void> _salvar() async {
    if (_localDestino == 'Personalizado CNPJ por Estado' && _planoEstado == null) {
      setState(() => _erro = 'Toque em "Configurar destino por Estado" para escolher o CNPJ padrão.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final excecoesUf = _localDestino == 'Personalizado CNPJ por Estado'
        ? [
            for (final g in _planoEstado!.grupos)
              for (final uf in g.ufs) (uf: uf, cnpj: g.cnpj),
          ]
        : const <({String uf, String cnpj})>[];
    final erro = await ParametrosNFService().criar(
      empresaId: widget.empresaId,
      cnpjFrota: _cnpjCtrl.text,
      exigeNotaFiscal: _exigeNotaFiscal,
      separarNfCombustivel: _separarNfCombustivel,
      formaEmissao: _formaEmissao,
      localDestino: _localDestino,
      cnpjDestinoPersonalizado:
          _localDestino == 'Personalizado CNPJ por Estado' ? _planoEstado!.cnpjPadrao : _cnpjPersonalizadoCtrl.text,
      dadosAdicionais: _dadosAdicionaisCtrl.text,
      observacao: _obsCtrl.text,
      excecoesUf: excecoesUf,
    );
    if (!mounted) return;
    setState(() => _salvando = false);
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    widget.ref.invalidate(parametrosNFProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_erro != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
              child: Text(_erro!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
            ),
          ),
        Autocomplete<String>(
          optionsBuilder: (v) {
            if (v.text.isEmpty) return widget.cnpjsFrota;
            return widget.cnpjsFrota.where((c) => c.contains(v.text));
          },
          onSelected: (v) => _cnpjCtrl.text = v,
          fieldViewBuilder: (context, controller, focusNode, onSubmit) {
            controller.text = _cnpjCtrl.text;
            return TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: (v) => _cnpjCtrl.text = v,
              decoration: const InputDecoration(
                labelText: 'CNPJ da Frota',
                hintText: 'Todos os CNPJs (regra padrão)',
                border: OutlineInputBorder(),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _exigeNotaFiscal,
          decoration: const InputDecoration(labelText: 'Exige Nota Fiscal', border: OutlineInputBorder()),
          items: [for (final o in opcoesSimNaoNF) DropdownMenuItem(value: o, child: Text(o))],
          onChanged: (v) => setState(() => _exigeNotaFiscal = v ?? opcoesSimNaoNF.first),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _separarNfCombustivel,
          decoration: const InputDecoration(
              labelText: 'Separar NF de combustível dos produtos e serviços', border: OutlineInputBorder()),
          items: [for (final o in opcoesSimNaoNF) DropdownMenuItem(value: o, child: Text(o))],
          onChanged: (v) => setState(() => _separarNfCombustivel = v ?? opcoesSimNaoNF.first),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _formaEmissao,
          decoration: const InputDecoration(labelText: 'Forma de emissão da nota', border: OutlineInputBorder()),
          items: [for (final o in opcoesFormaEmissaoNF) DropdownMenuItem(value: o, child: Text(o))],
          onChanged: (v) => setState(() => _formaEmissao = v ?? opcoesFormaEmissaoNF.first),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _localDestino,
          decoration: const InputDecoration(labelText: 'Local de destino da Nota Fiscal', border: OutlineInputBorder()),
          items: [for (final o in opcoesLocalDestinoNF) DropdownMenuItem(value: o, child: Text(o))],
          onChanged: (v) => setState(() {
            _localDestino = v ?? opcoesLocalDestinoNF.first;
            _planoEstado = null;
          }),
        ),
        if (_localDestino == 'Personalizado CNPJ por Estado') ...[
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _configurarDestinoEstado,
            child: Text(
              _planoEstado != null
                  ? 'Padrão: ${_planoEstado!.cnpjPadrao} · ${_planoEstado!.grupos.length} exceção(ões)'
                  : 'Configurar destino por Estado',
            ),
          ),
        ] else if (_localDestino.startsWith('Personalizado')) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _cnpjPersonalizadoCtrl,
            decoration: const InputDecoration(labelText: 'CNPJ de destino personalizado', border: OutlineInputBorder()),
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _dadosAdicionaisCtrl,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Dados adicionais para a nota fiscal', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _obsCtrl,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Observação', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _salvando ? null : _salvar,
          child: _salvando
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salvar Regra'),
        ),
      ],
    );
  }
}
