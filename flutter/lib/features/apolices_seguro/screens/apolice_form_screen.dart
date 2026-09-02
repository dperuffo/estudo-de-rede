import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/apolices_seguro_provider.dart';
import '../services/apolices_seguro_service.dart';

// Fase FLT-Apólices-Seguro (02/09/2026) — porta de ApoliceForm.tsx (nova e
// [id]/editar da web, unificadas aqui: `id == null` = criação). Mesmo
// padrão de PneuFormScreen: recebe só o id da rota e busca o registro via
// provider (apoliceSeguroDetalheProvider), preenchendo os controllers uma
// única vez (`_preenchido`) quando o Future resolver.
class ApoliceFormScreen extends ConsumerStatefulWidget {
  final String? id;
  const ApoliceFormScreen({super.key, this.id});

  @override
  ConsumerState<ApoliceFormScreen> createState() => _ApoliceFormScreenState();
}

class _ApoliceFormScreenState extends ConsumerState<ApoliceFormScreen> {
  final _service = ApolicesSeguroService();
  final _placaCtrl = TextEditingController();
  final _seguradoraCtrl = TextEditingController();
  final _numeroApoliceCtrl = TextEditingController();
  final _coberturaCtrl = TextEditingController();
  final _franquiaCtrl = TextEditingController();
  final _premioCtrl = TextEditingController();
  final _observacoesCtrl = TextEditingController();
  DateTime? _vigenciaInicio;
  DateTime? _vigenciaFim;
  bool _salvando = false;
  bool _preenchido = false;
  String? _erro;
  String? _apoliceId;

  bool get _editando => widget.id != null;

  void _preencher(ApoliceSeguro a) {
    _apoliceId = a.id;
    _placaCtrl.text = a.placa ?? '';
    _seguradoraCtrl.text = a.seguradora;
    _numeroApoliceCtrl.text = a.numeroApolice;
    _coberturaCtrl.text = a.cobertura ?? '';
    _franquiaCtrl.text = a.valorFranquia?.toString() ?? '';
    _premioCtrl.text = a.valorPremio?.toString() ?? '';
    _observacoesCtrl.text = a.observacoes ?? '';
    _vigenciaInicio = DateTime.tryParse(a.vigenciaInicio);
    _vigenciaFim = DateTime.tryParse(a.vigenciaFim);
    _preenchido = true;
  }

  @override
  void dispose() {
    _placaCtrl.dispose();
    _seguradoraCtrl.dispose();
    _numeroApoliceCtrl.dispose();
    _coberturaCtrl.dispose();
    _franquiaCtrl.dispose();
    _premioCtrl.dispose();
    _observacoesCtrl.dispose();
    super.dispose();
  }

  Future<void> _selecionarData({required bool inicio}) async {
    final atual = inicio ? _vigenciaInicio : _vigenciaFim;
    final escolhida = await showDatePicker(
      context: context,
      initialDate: atual ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (escolhida == null) return;
    setState(() {
      if (inicio) {
        _vigenciaInicio = escolhida;
      } else {
        _vigenciaFim = escolhida;
      }
    });
  }

  double? _numOuNull(String texto) {
    final t = texto.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  String _iso(DateTime? d) => d == null
      ? ''
      : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _salvar() async {
    setState(() {
      _salvando = true;
      _erro = null;
    });

    final vigenciaInicioIso = _iso(_vigenciaInicio);
    final vigenciaFimIso = _iso(_vigenciaFim);

    String? erro;
    if (_editando) {
      erro = await _service.atualizar(
        id: _apoliceId ?? widget.id!,
        placa: _placaCtrl.text,
        seguradora: _seguradoraCtrl.text,
        numeroApolice: _numeroApoliceCtrl.text,
        vigenciaInicio: vigenciaInicioIso,
        vigenciaFim: vigenciaFimIso,
        cobertura: _coberturaCtrl.text,
        valorFranquia: _numOuNull(_franquiaCtrl.text),
        valorPremio: _numOuNull(_premioCtrl.text),
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
        seguradora: _seguradoraCtrl.text,
        numeroApolice: _numeroApoliceCtrl.text,
        vigenciaInicio: vigenciaInicioIso,
        vigenciaFim: vigenciaFimIso,
        cobertura: _coberturaCtrl.text,
        valorFranquia: _numOuNull(_franquiaCtrl.text),
        valorPremio: _numOuNull(_premioCtrl.text),
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
    if (_editando && !_preenchido) {
      final async = ref.watch(apoliceSeguroDetalheProvider(widget.id!));
      if (async.isLoading) {
        return Scaffold(
          appBar: AppBar(title: const Text('Editar Apólice')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      final apolice = async.valueOrNull;
      if (apolice == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Editar Apólice')),
          body: const Center(child: Text('Apólice não encontrada.')),
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_preenchido) setState(() => _preencher(apolice));
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
          title: Text(_editando ? 'Editar Apólice' : 'Nova Apólice')),
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
          TextField(
            controller: _seguradoraCtrl,
            decoration: const InputDecoration(
                labelText: 'Seguradora *',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _numeroApoliceCtrl,
            decoration: const InputDecoration(
                labelText: 'Número da apólice *',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _placaCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
                labelText: 'Placa',
                hintText: 'ABC1D23 (vazio = cobre a frota)',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_vigenciaInicio == null
                      ? 'Vigência início *'
                      : '${_vigenciaInicio!.day.toString().padLeft(2, '0')}/${_vigenciaInicio!.month.toString().padLeft(2, '0')}/${_vigenciaInicio!.year}'),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(color: Colors.grey.shade400)),
                  onTap: () => _selecionarData(inicio: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_vigenciaFim == null
                      ? 'Vigência fim *'
                      : '${_vigenciaFim!.day.toString().padLeft(2, '0')}/${_vigenciaFim!.month.toString().padLeft(2, '0')}/${_vigenciaFim!.year}'),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(color: Colors.grey.shade400)),
                  onTap: () => _selecionarData(inicio: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _coberturaCtrl,
            decoration: const InputDecoration(
                labelText: 'Cobertura',
                hintText: 'Compreensiva, RCF, Roubo/Furto...',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _franquiaCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Franquia (R\$)',
                      border: OutlineInputBorder(),
                      isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _premioCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Prêmio anual (R\$)',
                      border: OutlineInputBorder(),
                      isDense: true),
                ),
              ),
            ],
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
                : Text(_editando ? 'Salvar alterações' : 'Cadastrar apólice'),
          ),
        ],
      ),
    );
  }
}
