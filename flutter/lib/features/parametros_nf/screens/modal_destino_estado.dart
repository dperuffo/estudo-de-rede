import 'package:flutter/material.dart';
import '../../postos/providers/postos_provider.dart' show ufsBrasil;
import '../providers/parametros_nf_provider.dart';

// Fase FLT-Parametros-NF-Estado — porta de ModalDestinoEstado.tsx (mockup
// do Daniel "Configuração de Envio de Nota Personalizado por Estado"):
// quando o cliente escolhe "Personalizado CNPJ por Estado" em Parâmetros
// de NF, abre esta tela pra escolher um CNPJ padrão +, opcionalmente,
// exceções por UF (um grupo de estados apontando pra um CNPJ diferente do
// padrão). Devolve o plano (via Navigator.pop) pro form principal
// (parametros_nf_screen.dart) guardar em estado e usar ao salvar.
Future<PlanoDestinoEstado?> mostrarModalDestinoEstado(
  BuildContext context, {
  required List<String> cnpjsFrota,
  PlanoDestinoEstado? valorInicial,
}) {
  return showModalBottomSheet<PlanoDestinoEstado>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _ConteudoModalDestinoEstado(
          cnpjsFrota: cnpjsFrota,
          valorInicial: valorInicial,
          scrollController: scrollController,
        ),
      ),
    ),
  );
}

class _ConteudoModalDestinoEstado extends StatefulWidget {
  final List<String> cnpjsFrota;
  final PlanoDestinoEstado? valorInicial;
  final ScrollController scrollController;
  const _ConteudoModalDestinoEstado({required this.cnpjsFrota, this.valorInicial, required this.scrollController});

  @override
  State<_ConteudoModalDestinoEstado> createState() => _ConteudoModalDestinoEstadoState();
}

class _ConteudoModalDestinoEstadoState extends State<_ConteudoModalDestinoEstado> {
  late final _cnpjPadraoCtrl = TextEditingController(text: widget.valorInicial?.cnpjPadrao ?? '');
  late bool _adicionarExcecoes = (widget.valorInicial?.grupos.isNotEmpty ?? false);
  late List<GrupoUf> _grupos = List.of(widget.valorInicial?.grupos ?? const []);
  final Set<String> _ufsSelecionadas = {};
  final _cnpjGrupoCtrl = TextEditingController();
  String? _erro;

  Set<String> get _ufsJaUsadas => _grupos.expand((g) => g.ufs).toSet();

  void _adicionarGrupo() {
    if (_ufsSelecionadas.isEmpty || _cnpjGrupoCtrl.text.trim().isEmpty) {
      setState(() => _erro = 'Selecione ao menos um estado e o CNPJ de destino para adicionar a exceção.');
      return;
    }
    setState(() {
      _erro = null;
      _grupos = [..._grupos, GrupoUf(ufs: _ufsSelecionadas.toList(), cnpj: _cnpjGrupoCtrl.text.trim())];
      _ufsSelecionadas.clear();
      _cnpjGrupoCtrl.clear();
    });
  }

  void _confirmar() {
    if (_cnpjPadraoCtrl.text.trim().isEmpty) {
      setState(() => _erro = 'Informe o CNPJ padrão para recebimento de NFs.');
      return;
    }
    Navigator.of(context).pop(PlanoDestinoEstado(
      cnpjPadrao: _cnpjPadraoCtrl.text.trim(),
      grupos: _adicionarExcecoes ? _grupos : [],
    ));
  }

  @override
  void dispose() {
    _cnpjPadraoCtrl.dispose();
    _cnpjGrupoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        controller: widget.scrollController,
        children: [
          Text('Configuração de Envio de Nota Personalizado por Estado',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Selecione o CNPJ/empresa que receberá as notas fiscais de abastecimentos.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          if (_erro != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
              child: Text(_erro!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
            ),
          Autocomplete<String>(
            optionsBuilder: (v) => v.text.isEmpty
                ? widget.cnpjsFrota
                : widget.cnpjsFrota.where((c) => c.contains(v.text)),
            onSelected: (v) => _cnpjPadraoCtrl.text = v,
            fieldViewBuilder: (context, controller, focusNode, onSubmit) {
              controller.text = _cnpjPadraoCtrl.text;
              return TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: (v) => _cnpjPadraoCtrl.text = v,
                decoration: const InputDecoration(
                  labelText: 'CNPJ padrão para recebimento de NFs *',
                  hintText: '00.000.000/0000-00',
                  border: OutlineInputBorder(),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Adicionar Exceções', style: TextStyle(fontSize: 14)),
            value: _adicionarExcecoes,
            onChanged: (v) => setState(() => _adicionarExcecoes = v ?? false),
          ),
          if (_adicionarExcecoes) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Estados', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final uf in ufsBrasil)
                        FilterChip(
                          label: Text(uf, style: const TextStyle(fontSize: 12)),
                          selected: _ufsSelecionadas.contains(uf),
                          onSelected: _ufsJaUsadas.contains(uf)
                              ? null
                              : (sel) => setState(() => sel ? _ufsSelecionadas.add(uf) : _ufsSelecionadas.remove(uf)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _cnpjGrupoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'CNPJ/Razão Social - Frota/Unidade',
                      hintText: '00.000.000/0000-00',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(onPressed: _adicionarGrupo, child: const Text('+ Adicionar exceção')),
                  ),
                  if (_grupos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ..._grupos.asMap().entries.map((e) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text.rich(
                                  TextSpan(children: [
                                    TextSpan(text: e.value.ufs.join(', '), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                    TextSpan(text: ' → ${e.value.cnpj}', style: const TextStyle(fontSize: 12)),
                                  ]),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                onPressed: () => setState(() => _grupos = List.of(_grupos)..removeAt(e.key)),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(onPressed: _confirmar, child: const Text('Confirmar')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
