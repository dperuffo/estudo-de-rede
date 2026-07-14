import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sessao_provider.dart';
import '../../motoristas/providers/motoristas_provider.dart' show Motorista, motoristasClienteProvider;
import '../../veiculos/providers/veiculos_provider.dart' show Veiculo, veiculosClienteProvider;
import '../providers/rotograma_provider.dart';
import '../services/rotograma_service.dart';

// Fase FLT-3 — porta de RotogramaForm.tsx, compartilhado entre criar
// (rotograma_novo_screen.dart) e editar (rotograma_editar_screen.dart).
class RotogramaForm extends ConsumerStatefulWidget {
  final RotogramaDetalhe? existente;
  const RotogramaForm({super.key, this.existente});

  @override
  ConsumerState<RotogramaForm> createState() => _RotogramaFormState();
}

class _LinhaRisco {
  final controllerLocal = TextEditingController();
  final controllerDescricao = TextEditingController();
  final controllerKm = TextEditingController();
  String categoria = 'perigo';
  _LinhaRisco();
  _LinhaRisco.deRisco(RotogramaRisco r) {
    controllerLocal.text = r.local;
    controllerDescricao.text = r.descricao;
    controllerKm.text = r.km?.toString() ?? '';
    categoria = r.categoria;
  }
  RotogramaRisco toRisco() => RotogramaRisco(
        local: controllerLocal.text.trim(),
        categoria: categoria,
        descricao: controllerDescricao.text.trim(),
        km: double.tryParse(controllerKm.text.replaceAll(',', '.')),
      );
  void dispose() {
    controllerLocal.dispose();
    controllerDescricao.dispose();
    controllerKm.dispose();
  }
}

class _LinhaParada {
  final controllerLocal = TextEditingController();
  final controllerDescricao = TextEditingController();
  final controllerKm = TextEditingController();
  String categoria = 'abastecimento';
  _LinhaParada();
  _LinhaParada.deParada(RotogramaParada p) {
    controllerLocal.text = p.local;
    controllerDescricao.text = p.descricao;
    controllerKm.text = p.km?.toString() ?? '';
    categoria = p.categoria;
  }
  RotogramaParada toParada() => RotogramaParada(
        local: controllerLocal.text.trim(),
        categoria: categoria,
        descricao: controllerDescricao.text.trim(),
        km: double.tryParse(controllerKm.text.replaceAll(',', '.')),
      );
  void dispose() {
    controllerLocal.dispose();
    controllerDescricao.dispose();
    controllerKm.dispose();
  }
}

class _RotogramaFormState extends ConsumerState<RotogramaForm> {
  late final _origemCtrl = TextEditingController(text: widget.existente?.origem ?? '');
  late final _destinoCtrl = TextEditingController(text: widget.existente?.destino ?? '');
  late final _veiculoCtrl = TextEditingController(text: widget.existente?.veiculo ?? '');
  late final _cargaCtrl = TextEditingController(text: widget.existente?.carga ?? '');
  late final _observacoesCtrl = TextEditingController(text: widget.existente?.observacoes ?? '');
  late String? _motorista = widget.existente?.motorista;
  late String? _placa = widget.existente?.placa;
  late String? _dataViagem = widget.existente?.dataViagem;

  late List<_LinhaRisco> _riscos = (widget.existente?.riscos ?? []).map((r) => _LinhaRisco.deRisco(r)).toList();
  late List<_LinhaParada> _paradas = (widget.existente?.paradas ?? []).map((p) => _LinhaParada.deParada(p)).toList();

  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _origemCtrl.dispose();
    _destinoCtrl.dispose();
    _veiculoCtrl.dispose();
    _cargaCtrl.dispose();
    _observacoesCtrl.dispose();
    for (final r in _riscos) {
      r.dispose();
    }
    for (final p in _paradas) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final atual = DateTime.tryParse(_dataViagem ?? '') ?? DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (escolhida != null) {
      setState(() => _dataViagem = escolhida.toIso8601String().substring(0, 10));
    }
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    if (_origemCtrl.text.trim().isEmpty || _destinoCtrl.text.trim().isEmpty) {
      setState(() => _erro = 'Origem e destino são obrigatórios.');
      return;
    }
    final sessao = await ref.read(sessaoProvider.future);
    final empresaId = sessao.empresaId;
    if (empresaId == null) {
      setState(() => _erro = 'Selecione uma empresa antes.');
      return;
    }

    setState(() => _salvando = true);
    try {
      final riscos = _riscos.map((r) => r.toRisco()).where((r) => r.local.isNotEmpty || r.descricao.isNotEmpty).toList();
      final paradas = _paradas.map((p) => p.toParada()).where((p) => p.local.isNotEmpty || p.descricao.isNotEmpty).toList();

      if (widget.existente == null) {
        final id = await RotogramaService().criar(
          empresaId: empresaId,
          userEmail: sessao.email ?? '',
          origem: _origemCtrl.text,
          destino: _destinoCtrl.text,
          veiculo: _veiculoCtrl.text,
          motorista: _motorista,
          placa: _placa,
          dataViagem: _dataViagem,
          carga: _cargaCtrl.text,
          observacoes: _observacoesCtrl.text,
          riscos: riscos,
          paradas: paradas,
        );
        if (!mounted) return;
        context.go('/rotograma/$id');
      } else {
        await RotogramaService().atualizar(
          id: widget.existente!.id,
          origem: _origemCtrl.text,
          destino: _destinoCtrl.text,
          veiculo: _veiculoCtrl.text,
          motorista: _motorista,
          placa: _placa,
          dataViagem: _dataViagem,
          carga: _cargaCtrl.text,
          observacoes: _observacoesCtrl.text,
          riscos: riscos,
          paradas: paradas,
        );
        ref.invalidate(rotogramaDetalheProvider(widget.existente!.id));
        if (!mounted) return;
        context.go('/rotograma/${widget.existente!.id}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível salvar: $e';
        _salvando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final motoristasAsync = ref.watch(motoristasClienteProvider);
    final veiculosAsync = ref.watch(veiculosClienteProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_erro != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
            child: Text(_erro!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
          ),
          const SizedBox(height: 12),
        ],

        const Text('Dados da viagem', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 10),
        TextField(
          controller: _origemCtrl,
          decoration: const InputDecoration(labelText: 'Origem *', hintText: 'Ex.: São Paulo/SP', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _destinoCtrl,
          decoration: const InputDecoration(labelText: 'Destino *', hintText: 'Ex.: Belo Horizonte/MG', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 10),
        motoristasAsync.when(
          data: (lista) {
            final ativos = lista.where((m) => m.ativo).toList();
            return DropdownButtonFormField<String?>(
              value: _motorista,
              decoration: const InputDecoration(labelText: 'Motorista', border: OutlineInputBorder(), isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('Selecione...')),
                if (_motorista != null && !ativos.any((m) => m.nomeCompleto == _motorista))
                  DropdownMenuItem(value: _motorista, child: Text(_motorista!)),
                for (final m in ativos) DropdownMenuItem(value: m.nomeCompleto, child: Text(m.nomeCompleto)),
              ],
              onChanged: (v) => setState(() => _motorista = v),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox(),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _veiculoCtrl,
          decoration: const InputDecoration(labelText: 'Veículo', hintText: 'Ex.: Caminhão baú', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 10),
        veiculosAsync.when(
          data: (lista) {
            final ativos = lista.where((v) => v.ativo).toList();
            return DropdownButtonFormField<String?>(
              value: _placa,
              decoration: const InputDecoration(labelText: 'Placa', border: OutlineInputBorder(), isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('Selecione...')),
                if (_placa != null && !ativos.any((v) => v.placa == _placa)) DropdownMenuItem(value: _placa, child: Text(_placa!)),
                for (final v in ativos)
                  DropdownMenuItem(
                    value: v.placa,
                    child: Text('${v.placa}${[v.marca, v.modelo].where((s) => s != null && s.isNotEmpty).isNotEmpty ? ' — ${[v.marca, v.modelo].where((s) => s != null && s.isNotEmpty).join(' ')}' : ''}'),
                  ),
              ],
              onChanged: (v) => setState(() => _placa = v),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox(),
        ),
        const SizedBox(height: 10),
        TextField(
          readOnly: true,
          onTap: _selecionarData,
          controller: TextEditingController(text: _dataViagem ?? ''),
          decoration: const InputDecoration(labelText: 'Data da viagem', border: OutlineInputBorder(), isDense: true, suffixIcon: Icon(Icons.calendar_today, size: 16)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _cargaCtrl,
          decoration: const InputDecoration(labelText: 'Carga', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _observacoesCtrl,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Observações', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 20),

        _secaoRiscos(),
        const SizedBox(height: 20),
        _secaoParadas(),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _salvando ? null : _salvar,
            child: Text(_salvando ? 'Salvando...' : (widget.existente != null ? 'Salvar alterações' : 'Criar Rotograma')),
          ),
        ),
      ],
    );
  }

  Widget _secaoRiscos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text('⚠️ Pontos de risco', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
            OutlinedButton(
              onPressed: () => setState(() => _riscos = [..._riscos, _LinhaRisco()]),
              child: const Text('+ Adicionar', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const Text('Trechos perigosos, zonas de crime, radares e lombadas na rota.', style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 8),
        if (_riscos.isEmpty) const Text('Nenhum ponto de risco adicionado.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ..._riscos.asMap().entries.map((e) => _linhaEditavel(
              km: e.value.controllerKm,
              local: e.value.controllerLocal,
              descricao: e.value.controllerDescricao,
              categoriaAtual: e.value.categoria,
              opcoesCategoria: categoriasRisco.map((c) => (valor: c.valor, label: '${c.icone} ${c.label}')).toList(),
              onCategoria: (v) => setState(() => e.value.categoria = v ?? e.value.categoria),
              onRemover: () => setState(() {
                e.value.dispose();
                _riscos = List.of(_riscos)..removeAt(e.key);
              }),
              hintLocal: 'Ex.: BR-381 km 120 — Itatiaia/MG',
              hintDescricao: 'Ex.: Vel. máx 60 km/h',
            )),
      ],
    );
  }

  Widget _secaoParadas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text('📍 Pontos de parada', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
            OutlinedButton(
              onPressed: () => setState(() => _paradas = [..._paradas, _LinhaParada()]),
              child: const Text('+ Adicionar', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const Text('Postos, restaurantes e locais seguros para pernoite na rota.', style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 8),
        if (_paradas.isEmpty) const Text('Nenhuma parada adicionada.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ..._paradas.asMap().entries.map((e) => _linhaEditavel(
              km: e.value.controllerKm,
              local: e.value.controllerLocal,
              descricao: e.value.controllerDescricao,
              categoriaAtual: e.value.categoria,
              opcoesCategoria: categoriasParada.map((c) => (valor: c.valor, label: '${c.icone} ${c.label}')).toList(),
              onCategoria: (v) => setState(() => e.value.categoria = v ?? e.value.categoria),
              onRemover: () => setState(() {
                e.value.dispose();
                _paradas = List.of(_paradas)..removeAt(e.key);
              }),
              hintLocal: 'Ex.: Posto Ipiranga — km 210',
              hintDescricao: 'Ex.: R\$ 6,05/L · Aberto 24h',
            )),
      ],
    );
  }

  Widget _linhaEditavel({
    required TextEditingController km,
    required TextEditingController local,
    required TextEditingController descricao,
    required String categoriaAtual,
    required List<({String valor, String label})> opcoesCategoria,
    required void Function(String?) onCategoria,
    required VoidCallback onRemover,
    required String hintLocal,
    required String hintDescricao,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 80,
                child: TextField(
                  controller: km,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Km', border: OutlineInputBorder(), isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: categoriaAtual,
                  decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder(), isDense: true),
                  items: opcoesCategoria.map((o) => DropdownMenuItem(value: o.valor, child: Text(o.label, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: onCategoria,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: local,
            decoration: InputDecoration(labelText: 'Local', hintText: hintLocal, border: const OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: descricao,
            decoration: InputDecoration(labelText: 'Descrição', hintText: hintDescricao, border: const OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onRemover, child: const Text('Remover', style: TextStyle(color: Colors.red, fontSize: 12))),
          ),
        ],
      ),
    );
  }
}
