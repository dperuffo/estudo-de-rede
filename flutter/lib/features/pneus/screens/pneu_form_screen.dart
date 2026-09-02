import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../veiculos/providers/veiculos_provider.dart';
import '../providers/pneus_provider.dart';
import '../services/pneus_service.dart';

// Fase FLT-Gestão-Pneus (02/09/2026) — porta de PneuForm.tsx (pneus/novo e
// pneus/[id]/editar da web, unificadas aqui num único form: `id == null` =
// criação). Mesmo padrão de VeiculoEditarScreen: recebe só o id da rota e
// busca o registro via provider (pneuDetalheProvider), preenchendo os
// controllers uma única vez (`_preenchido`) quando o Future resolver.
// Placas sugeridas via veiculosClienteProvider (mesma fonte da web, RPC
// veiculos_da_empresa).
class PneuFormScreen extends ConsumerStatefulWidget {
  final String? id;
  const PneuFormScreen({super.key, this.id});

  @override
  ConsumerState<PneuFormScreen> createState() => _PneuFormScreenState();
}

class _PneuFormScreenState extends ConsumerState<PneuFormScreen> {
  final _service = PneusService();
  final _placaCtrl = TextEditingController();
  final _posicaoCtrl = TextEditingController();
  final _numeroFogoCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _medidaCtrl = TextEditingController();
  final _hodometroCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  final _observacoesCtrl = TextEditingController();
  DateTime? _dataInstalacao = DateTime.now();
  bool _salvando = false;
  bool _preenchido = false;
  String? _erro;
  String? _pneuId;

  bool get _editando => widget.id != null;

  void _preencher(Pneu p) {
    _pneuId = p.id;
    _placaCtrl.text = p.placa;
    _posicaoCtrl.text = p.posicao;
    _numeroFogoCtrl.text = p.numeroFogo ?? '';
    _marcaCtrl.text = p.marca ?? '';
    _modeloCtrl.text = p.modelo ?? '';
    _medidaCtrl.text = p.medida ?? '';
    _hodometroCtrl.text = p.hodometroInstalacao.toStringAsFixed(0);
    _valorCtrl.text = p.valorAquisicao?.toString() ?? '';
    _observacoesCtrl.text = p.observacoes ?? '';
    _dataInstalacao = DateTime.tryParse(p.dataInstalacao) ?? DateTime.now();
    _preenchido = true;
  }

  @override
  void dispose() {
    _placaCtrl.dispose();
    _posicaoCtrl.dispose();
    _numeroFogoCtrl.dispose();
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _medidaCtrl.dispose();
    _hodometroCtrl.dispose();
    _valorCtrl.dispose();
    _observacoesCtrl.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _dataInstalacao ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (escolhida != null) setState(() => _dataInstalacao = escolhida);
  }

  double? _numOuNull(String texto) {
    final t = texto.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _salvar() async {
    setState(() {
      _salvando = true;
      _erro = null;
    });

    final dataIso = _dataInstalacao != null
        ? '${_dataInstalacao!.year.toString().padLeft(4, '0')}-${_dataInstalacao!.month.toString().padLeft(2, '0')}-${_dataInstalacao!.day.toString().padLeft(2, '0')}'
        : '';

    String? erro;
    if (_editando) {
      erro = await _service.atualizar(
        id: _pneuId ?? widget.id!,
        placa: _placaCtrl.text,
        posicao: _posicaoCtrl.text,
        numeroFogo: _numeroFogoCtrl.text,
        marca: _marcaCtrl.text,
        modelo: _modeloCtrl.text,
        medida: _medidaCtrl.text,
        dataInstalacao: dataIso,
        hodometroInstalacao: _numOuNull(_hodometroCtrl.text),
        valorAquisicao: _numOuNull(_valorCtrl.text),
        observacoes: _observacoesCtrl.text,
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
      erro = await _service.criar(
        empresaId: empresaId,
        placa: _placaCtrl.text,
        posicao: _posicaoCtrl.text,
        numeroFogo: _numeroFogoCtrl.text,
        marca: _marcaCtrl.text,
        modelo: _modeloCtrl.text,
        medida: _medidaCtrl.text,
        dataInstalacao: dataIso,
        hodometroInstalacao: _numOuNull(_hodometroCtrl.text),
        valorAquisicao: _numOuNull(_valorCtrl.text),
        observacoes: _observacoesCtrl.text,
      );
    }

    if (!mounted) return;
    setState(() => _salvando = false);
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final placasSugeridas = (ref.watch(veiculosClienteProvider).valueOrNull ??
            const [])
        .map((v) => v.placa)
        .toSet()
        .toList()
      ..sort();

    if (_editando && !_preenchido) {
      final async = ref.watch(pneuDetalheProvider(widget.id!));
      if (async.isLoading) {
        return Scaffold(
          appBar: AppBar(title: const Text('Editar Pneu')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      final pneu = async.valueOrNull;
      if (pneu == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Editar Pneu')),
          body: const Center(child: Text('Pneu não encontrado.')),
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_preenchido) setState(() => _preencher(pneu));
      });
    }

    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: Text(_editando ? 'Editar Pneu' : 'Novo Pneu')),
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
          Autocomplete<String>(
            initialValue: TextEditingValue(text: _placaCtrl.text),
            optionsBuilder: (v) => v.text.isEmpty
                ? placasSugeridas
                : placasSugeridas.where((p) =>
                    p.toUpperCase().contains(v.text.toUpperCase())),
            onSelected: (v) => _placaCtrl.text = v,
            fieldViewBuilder: (context, ctrl, focus, onSubmit) {
              ctrl.text = _placaCtrl.text;
              ctrl.addListener(() => _placaCtrl.text = ctrl.text);
              return TextField(
                controller: ctrl,
                focusNode: focus,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                    labelText: 'Placa *',
                    border: OutlineInputBorder(),
                    isDense: true),
              );
            },
          ),
          const SizedBox(height: 10),
          Autocomplete<String>(
            initialValue: TextEditingValue(text: _posicaoCtrl.text),
            optionsBuilder: (v) => v.text.isEmpty
                ? posicoesSugeridasPneu
                : posicoesSugeridasPneu.where((p) =>
                    p.toLowerCase().contains(v.text.toLowerCase())),
            onSelected: (v) => _posicaoCtrl.text = v,
            fieldViewBuilder: (context, ctrl, focus, onSubmit) {
              ctrl.text = _posicaoCtrl.text;
              ctrl.addListener(() => _posicaoCtrl.text = ctrl.text);
              return TextField(
                controller: ctrl,
                focusNode: focus,
                decoration: const InputDecoration(
                    labelText: 'Posição no veículo *',
                    border: OutlineInputBorder(),
                    isDense: true),
              );
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _numeroFogoCtrl,
            decoration: const InputDecoration(
                labelText: 'Número de fogo',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _marcaCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Marca',
                      border: OutlineInputBorder(),
                      isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _modeloCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Modelo',
                      border: OutlineInputBorder(),
                      isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _medidaCtrl,
            decoration: const InputDecoration(
                labelText: 'Medida',
                hintText: '295/80R22.5',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_dataInstalacao == null
                ? 'Data de instalação *'
                : '${_dataInstalacao!.day.toString().padLeft(2, '0')}/${_dataInstalacao!.month.toString().padLeft(2, '0')}/${_dataInstalacao!.year}'),
            trailing: const Icon(Icons.calendar_today, size: 18),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: Colors.grey.shade400)),
            onTap: _selecionarData,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _hodometroCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Hodômetro na instalação (km)',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _valorCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Valor de aquisição (R\$)',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _observacoesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Observações',
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
                : Text(_editando ? 'Salvar alterações' : 'Cadastrar pneu'),
          ),
        ],
      ),
    );
  }
}
