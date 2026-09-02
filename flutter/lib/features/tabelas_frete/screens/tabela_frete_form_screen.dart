import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/tabelas_frete_provider.dart';
import '../services/tabelas_frete_service.dart';

// Fase FLT-Tabelas-Frete (02/09/2026) — porta de TabelaFreteForm.tsx.
// `id == null` = criação. Faixas de peso são uma lista editável em
// memória (igual à web: delete+insert de tudo a cada save, sem update
// linha a linha). Mesmo padrão id-based de fetch-and-fill usado em
// PneuFormScreen/ApoliceFormScreen.
class TabelaFreteFormScreen extends ConsumerStatefulWidget {
  final String? id;
  const TabelaFreteFormScreen({super.key, this.id});

  @override
  ConsumerState<TabelaFreteFormScreen> createState() =>
      _TabelaFreteFormScreenState();
}

class _TabelaFreteFormScreenState
    extends ConsumerState<TabelaFreteFormScreen> {
  final _service = TabelasFreteService();
  final _nomeCtrl = TextEditingController();
  final _ufOrigemCtrl = TextEditingController();
  final _cidadeOrigemCtrl = TextEditingController();
  final _ufDestinoCtrl = TextEditingController();
  final _cidadeDestinoCtrl = TextEditingController();
  final _adValoremCtrl = TextEditingController(text: '0');
  final _grisCtrl = TextEditingController(text: '0');
  final _tdeCtrl = TextEditingController(text: '0');
  final _tdaCtrl = TextEditingController(text: '0');
  final _despachoCtrl = TextEditingController(text: '0');
  final _pedagioCtrl = TextEditingController(text: '0');
  final _icmsCtrl = TextEditingController(text: '0');
  String? _clienteTomadorId;
  List<ParceiroTomador> _parceiros = [];
  final List<_FaixaControllers> _faixas = [];
  bool _salvando = false;
  bool _preenchido = false;
  String? _erro;

  bool get _editando => widget.id != null;

  @override
  void initState() {
    super.initState();
    if (!_editando) _faixas.add(_FaixaControllers());
    _carregarParceiros();
    if (_editando) _carregarDetalhe();
  }

  Future<void> _carregarParceiros() async {
    final empresaId = ref.read(sessaoProvider).valueOrNull?.empresaId;
    if (empresaId == null) return;
    final lista = await _service.buscarParceirosTomadores(empresaId);
    if (mounted) setState(() => _parceiros = lista);
  }

  Future<void> _carregarDetalhe() async {
    final detalhe = await _service.buscarDetalhe(widget.id!);
    if (detalhe == null) {
      if (mounted) setState(() => _erro = 'Tabela não encontrada.');
      return;
    }
    final faixas = await _service.buscarFaixas(widget.id!);
    if (!mounted) return;
    setState(() {
      _nomeCtrl.text = detalhe.nome;
      _clienteTomadorId = detalhe.clienteTomadorId;
      _ufOrigemCtrl.text = detalhe.ufOrigem ?? '';
      _cidadeOrigemCtrl.text = detalhe.cidadeOrigem ?? '';
      _ufDestinoCtrl.text = detalhe.ufDestino ?? '';
      _cidadeDestinoCtrl.text = detalhe.cidadeDestino ?? '';
      _adValoremCtrl.text = detalhe.percentualAdValorem.toString();
      _grisCtrl.text = detalhe.percentualGris.toString();
      _tdeCtrl.text = detalhe.valorTde.toString();
      _tdaCtrl.text = detalhe.valorTda.toString();
      _despachoCtrl.text = detalhe.valorDespacho.toString();
      _pedagioCtrl.text = detalhe.valorPedagio.toString();
      _icmsCtrl.text = detalhe.percentualIcms.toString();
      _faixas.clear();
      if (faixas.isEmpty) {
        _faixas.add(_FaixaControllers());
      } else {
        for (final f in faixas) {
          _faixas.add(_FaixaControllers.fromFaixa(f));
        }
      }
      _preenchido = true;
    });
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _ufOrigemCtrl.dispose();
    _cidadeOrigemCtrl.dispose();
    _ufDestinoCtrl.dispose();
    _cidadeDestinoCtrl.dispose();
    _adValoremCtrl.dispose();
    _grisCtrl.dispose();
    _tdeCtrl.dispose();
    _tdaCtrl.dispose();
    _despachoCtrl.dispose();
    _pedagioCtrl.dispose();
    _icmsCtrl.dispose();
    for (final f in _faixas) {
      f.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _salvar() async {
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final faixas = _faixas.map((f) => f.paraModelo()).toList();
    String? erro;
    if (_editando) {
      erro = await _service.atualizar(
        id: widget.id!,
        nome: _nomeCtrl.text,
        clienteTomadorId: _clienteTomadorId,
        ufOrigem: _ufOrigemCtrl.text,
        cidadeOrigem: _cidadeOrigemCtrl.text,
        ufDestino: _ufDestinoCtrl.text,
        cidadeDestino: _cidadeDestinoCtrl.text,
        percentualAdValorem: _num(_adValoremCtrl),
        percentualGris: _num(_grisCtrl),
        valorTde: _num(_tdeCtrl),
        valorTda: _num(_tdaCtrl),
        valorDespacho: _num(_despachoCtrl),
        valorPedagio: _num(_pedagioCtrl),
        percentualIcms: _num(_icmsCtrl),
        faixas: faixas,
      );
    } else {
      final empresaId = ref.read(sessaoProvider).valueOrNull?.empresaId;
      if (empresaId == null) {
        setState(() {
          _salvando = false;
          _erro = 'Não foi possível identificar sua empresa na sessão atual.';
        });
        return;
      }
      final resultado = await _service.criar(
        empresaId: empresaId,
        nome: _nomeCtrl.text,
        clienteTomadorId: _clienteTomadorId,
        ufOrigem: _ufOrigemCtrl.text,
        cidadeOrigem: _cidadeOrigemCtrl.text,
        ufDestino: _ufDestinoCtrl.text,
        cidadeDestino: _cidadeDestinoCtrl.text,
        percentualAdValorem: _num(_adValoremCtrl),
        percentualGris: _num(_grisCtrl),
        valorTde: _num(_tdeCtrl),
        valorTda: _num(_tdaCtrl),
        valorDespacho: _num(_despachoCtrl),
        valorPedagio: _num(_pedagioCtrl),
        percentualIcms: _num(_icmsCtrl),
        faixas: faixas,
      );
      erro = resultado.erro;
    }

    if (!mounted) return;
    setState(() => _salvando = false);
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    ref.invalidate(tabelasFreteClienteProvider);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_editando && !_preenchido && _erro == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar Tabela de Frete')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title:
              Text(_editando ? 'Editar Tabela de Frete' : 'Nova Tabela de Frete')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_erro != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_erro!,
                  style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
            ),
            const SizedBox(height: 12),
          ],
          const Text('Identificação',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _nomeCtrl,
            decoration: const InputDecoration(
                labelText: 'Nome *',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            initialValue: _clienteTomadorId,
            decoration: const InputDecoration(
                labelText: 'Cliente tomador',
                border: OutlineInputBorder(),
                isDense: true),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('Geral (qualquer cliente)')),
              ..._parceiros.map((p) => DropdownMenuItem<String?>(
                  value: p.id,
                  child: Text(
                      '${p.razaoSocial}${p.cnpjCpf != null ? ' — ${p.cnpjCpf}' : ''}',
                      overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (v) => setState(() => _clienteTomadorId = v),
          ),
          const SizedBox(height: 16),
          const Text('Rota (opcional)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _cidadeOrigemCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Cidade origem',
                      border: OutlineInputBorder(),
                      isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ufOrigemCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                      labelText: 'UF',
                      border: OutlineInputBorder(),
                      isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _cidadeDestinoCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Cidade destino',
                      border: OutlineInputBorder(),
                      isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ufDestinoCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                      labelText: 'UF',
                      border: OutlineInputBorder(),
                      isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Faixas de peso *',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () => setState(() => _faixas.add(_FaixaControllers())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Faixa'),
              ),
            ],
          ),
          ..._faixas.asMap().entries.map((entry) {
            final i = entry.key;
            final f = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: f.pesoMinCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Peso mín (kg)',
                                border: OutlineInputBorder(),
                                isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: f.pesoMaxCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Peso máx (kg)',
                                hintText: 'Sem limite',
                                border: OutlineInputBorder(),
                                isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: f.valorPorKgCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Valor por kg (R\$)',
                                border: OutlineInputBorder(),
                                isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: f.valorMinimoCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Valor mínimo (R\$)',
                                border: OutlineInputBorder(),
                                isDense: true),
                          ),
                        ),
                      ],
                    ),
                    if (_faixas.length > 1)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setState(() {
                            _faixas[i].dispose();
                            _faixas.removeAt(i);
                          }),
                          child: const Text('Remover'),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          const Text('Adicionais',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _adValoremCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Ad valorem (%)',
                      border: OutlineInputBorder(),
                      isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _grisCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'GRIS (%)',
                      border: OutlineInputBorder(),
                      isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tdeCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'TDE (R\$)',
                      border: OutlineInputBorder(),
                      isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _tdaCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'TDA (R\$)',
                      border: OutlineInputBorder(),
                      isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _despachoCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Despacho (R\$)',
                      border: OutlineInputBorder(),
                      isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _pedagioCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Pedágio (R\$)',
                      border: OutlineInputBorder(),
                      isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _icmsCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'ICMS (% — cálculo "por dentro")',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _salvando ? null : _salvar,
            child: _salvando
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_editando ? 'Salvar alterações' : 'Cadastrar tabela'),
          ),
        ],
      ),
    );
  }
}

class _FaixaControllers {
  final pesoMinCtrl = TextEditingController();
  final pesoMaxCtrl = TextEditingController();
  final valorPorKgCtrl = TextEditingController();
  final valorMinimoCtrl = TextEditingController();

  _FaixaControllers();

  factory _FaixaControllers.fromFaixa(FaixaPesoEditavel f) {
    final c = _FaixaControllers();
    c.pesoMinCtrl.text = f.pesoMinKg?.toString() ?? '';
    c.pesoMaxCtrl.text = f.pesoMaxKg?.toString() ?? '';
    c.valorPorKgCtrl.text = f.valorPorKg?.toString() ?? '';
    c.valorMinimoCtrl.text = f.valorMinimo?.toString() ?? '';
    return c;
  }

  FaixaPesoEditavel paraModelo() => FaixaPesoEditavel(
        pesoMinKg: double.tryParse(pesoMinCtrl.text.trim().replaceAll(',', '.')),
        pesoMaxKg: double.tryParse(pesoMaxCtrl.text.trim().replaceAll(',', '.')),
        valorPorKg:
            double.tryParse(valorPorKgCtrl.text.trim().replaceAll(',', '.')),
        valorMinimo:
            double.tryParse(valorMinimoCtrl.text.trim().replaceAll(',', '.')),
      );

  void dispose() {
    pesoMinCtrl.dispose();
    pesoMaxCtrl.dispose();
    valorPorKgCtrl.dispose();
    valorMinimoCtrl.dispose();
  }
}
