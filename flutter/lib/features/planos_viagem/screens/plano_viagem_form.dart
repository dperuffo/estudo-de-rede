import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../../motoristas/providers/motoristas_provider.dart' show Motorista, motoristasClienteProvider, centrosCustoOpcoesProvider;
import '../../veiculos/providers/veiculos_provider.dart' show Veiculo, veiculosClienteProvider;
import '../../rotograma/providers/rotograma_provider.dart' show RotogramaResumo, rotogramasListaProvider;
import '../providers/planos_viagem_provider.dart';
import '../services/planos_viagem_service.dart';

final _moedaForm = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

// Fase FLT-3 — porta de PlanoViagemForm.tsx, compartilhado entre criar
// (plano_viagem_novo_screen.dart) e editar (plano_viagem_editar_screen.dart).
// Campos "calculados" (custo de combustível/diárias/manutenção/total,
// margem) são recomputados ao vivo aqui — só pra feedback visual imediato;
// quem grava de verdade o valor final é PlanosViagemService (mesmo
// espírito de nunca confiar só no client, igual à web).
class PlanoViagemForm extends ConsumerStatefulWidget {
  final PlanoViagem? existente;
  final List<Pedagio> pedagiosIniciais;
  const PlanoViagemForm({super.key, this.existente, this.pedagiosIniciais = const []});

  @override
  ConsumerState<PlanoViagemForm> createState() => _PlanoViagemFormState();
}

class _LinhaPedagio {
  final controllerPraca = TextEditingController();
  final controllerValor = TextEditingController();
  _LinhaPedagio();
  _LinhaPedagio.de(Pedagio p) {
    controllerPraca.text = p.pracaNome;
    controllerValor.text = p.valor == 0 ? '' : p.valor.toString();
  }
  double get valor => double.tryParse(controllerValor.text.replaceAll(',', '.')) ?? 0;
  Pedagio toPedagio() => Pedagio(pracaNome: controllerPraca.text.trim(), valor: valor);
  void dispose() {
    controllerPraca.dispose();
    controllerValor.dispose();
  }
}

class _PlanoViagemFormState extends ConsumerState<PlanoViagemForm> {
  late final _nomeCtrl = TextEditingController(text: widget.existente?.nome ?? '');
  late String _status = widget.existente?.status ?? 'rascunho';
  late String? _placa = widget.existente?.placa;
  late String? _motoristaId = widget.existente?.motoristaId;
  late String? _rotogramaId = widget.existente?.rotogramaId;
  late String? _centroCustoId = widget.existente?.centroCustoId;
  late String? _dataSaida = widget.existente?.dataSaida;
  late String? _retornoPrevisto = widget.existente?.retornoPrevisto;

  late final _kmEstimadoCtrl = TextEditingController(text: _fmtNum(widget.existente?.kmEstimado));
  late final _consumoKmLCtrl = TextEditingController(text: _fmtNum(widget.existente?.consumoKmL));
  late final _precoCombustivelCtrl = TextEditingController(text: _fmtNum(widget.existente?.precoCombustivel));

  late final _nDiariasCtrl = TextEditingController(text: _fmtNum(widget.existente?.nDiarias.toDouble()));
  late final _valorRefeicaoCtrl = TextEditingController(text: _fmtNum(widget.existente?.valorRefeicaoDia));
  late final _valorPernoiteCtrl = TextEditingController(text: _fmtNum(widget.existente?.valorPernoiteDia));
  late final _valorBanhoCtrl = TextEditingController(text: _fmtNum(widget.existente?.valorBanhoDia));
  late final _valorLavagemCtrl = TextEditingController(text: _fmtNum(widget.existente?.valorLavagemDia));

  late final _custoManutencaoKmCtrl = TextEditingController(text: _fmtNum(widget.existente?.custoManutencaoKm));

  late final _receitaViagemCtrl = TextEditingController(text: _fmtNum(widget.existente?.receitaViagem));
  late final _custoTotalRealCtrl = TextEditingController(text: widget.existente?.custoTotalReal?.toString() ?? '');

  late final _observacoesCtrl = TextEditingController(text: widget.existente?.observacoes ?? '');

  late List<_LinhaPedagio> _pedagios = widget.pedagiosIniciais.map((p) => _LinhaPedagio.de(p)).toList();

  double? _combustivelRealLitros;
  double? _combustivelRealValor;
  bool _revisandoCombustivel = false;
  String? _erroRevisao;

  bool _salvando = false;
  String? _erro;

  static String _fmtNum(double? v) => (v == null || v == 0) ? '' : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());
  double _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  @override
  void initState() {
    super.initState();
    _combustivelRealLitros = widget.existente?.combustivelRealLitros;
    _combustivelRealValor = widget.existente?.custoCombustivelReal;
    for (final c in [
      _kmEstimadoCtrl,
      _consumoKmLCtrl,
      _precoCombustivelCtrl,
      _nDiariasCtrl,
      _valorRefeicaoCtrl,
      _valorPernoiteCtrl,
      _valorBanhoCtrl,
      _valorLavagemCtrl,
      _custoManutencaoKmCtrl,
      _receitaViagemCtrl,
      _custoTotalRealCtrl,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _kmEstimadoCtrl.dispose();
    _consumoKmLCtrl.dispose();
    _precoCombustivelCtrl.dispose();
    _nDiariasCtrl.dispose();
    _valorRefeicaoCtrl.dispose();
    _valorPernoiteCtrl.dispose();
    _valorBanhoCtrl.dispose();
    _valorLavagemCtrl.dispose();
    _custoManutencaoKmCtrl.dispose();
    _receitaViagemCtrl.dispose();
    _custoTotalRealCtrl.dispose();
    _observacoesCtrl.dispose();
    for (final p in _pedagios) {
      p.dispose();
    }
    super.dispose();
  }

  double get _custoCombustivelEstimado {
    final consumo = _num(_consumoKmLCtrl);
    return consumo > 0 ? (_num(_kmEstimadoCtrl) / consumo) * _num(_precoCombustivelCtrl) : 0;
  }

  double get _pedagiosTotal => _pedagios.fold<double>(0, (s, p) => s + p.valor);

  double get _custoDiarias =>
      _num(_nDiariasCtrl) * (_num(_valorRefeicaoCtrl) + _num(_valorPernoiteCtrl) + _num(_valorBanhoCtrl) + _num(_valorLavagemCtrl));

  double get _custoManutencaoEstimado => _num(_kmEstimadoCtrl) * _num(_custoManutencaoKmCtrl);

  double get _custoTotalEstimado => _custoCombustivelEstimado + _pedagiosTotal + _custoDiarias + _custoManutencaoEstimado;

  double? get _custoTotalRealNum => _custoTotalRealCtrl.text.trim().isEmpty ? null : _num(_custoTotalRealCtrl);

  double get _margemEstimada => _num(_receitaViagemCtrl) - _custoTotalEstimado;
  double? get _margemReal => _custoTotalRealNum != null ? _num(_receitaViagemCtrl) - _custoTotalRealNum! : null;

  void _onPlacaChange(String? novaPlaca, List<Veiculo> veiculos) {
    setState(() {
      _placa = novaPlaca;
      Veiculo? veiculo;
      for (final v in veiculos) {
        if (v.placa == novaPlaca) {
          veiculo = v;
          break;
        }
      }
      if (veiculo?.autonomia != null && _num(_consumoKmLCtrl) == 0) {
        _consumoKmLCtrl.text = _fmtNum(veiculo!.autonomia);
      }
    });
  }

  Future<void> _selecionarData({required bool saida}) async {
    final atual = DateTime.tryParse((saida ? _dataSaida : _retornoPrevisto) ?? '') ?? DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (escolhida != null) {
      setState(() {
        final iso = escolhida.toIso8601String().substring(0, 10);
        if (saida) {
          _dataSaida = iso;
        } else {
          _retornoPrevisto = iso;
        }
      });
    }
  }

  Future<void> _revisarCombustivel() async {
    final existente = widget.existente;
    if (existente == null) return;
    setState(() {
      _erroRevisao = null;
      _revisandoCombustivel = true;
    });
    try {
      final resultado = await PlanosViagemService().revisarCombustivelReal(
        planoId: existente.id,
        empresaId: existente.empresaId,
        placa: existente.placa ?? '',
        dataSaida: existente.dataSaida ?? '',
      );
      if (!mounted) return;
      setState(() {
        _combustivelRealLitros = resultado.litros;
        _combustivelRealValor = resultado.valor;
      });
      ref.invalidate(planoViagemDetalheProvider(existente.id));
    } catch (e) {
      if (!mounted) return;
      setState(() => _erroRevisao = 'Não foi possível buscar os abastecimentos reais: $e');
    } finally {
      if (mounted) setState(() => _revisandoCombustivel = false);
    }
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    if (_nomeCtrl.text.trim().isEmpty) {
      setState(() => _erro = 'O nome do plano é obrigatório.');
      return;
    }
    final sessao = await ref.read(sessaoProvider.future);
    final empresaId = sessao.empresaId;
    if (empresaId == null) {
      setState(() => _erro = 'Não foi possível identificar o cliente da sessão.');
      return;
    }

    setState(() => _salvando = true);
    final pedagios = _pedagios.map((p) => p.toPedagio()).toList();
    try {
      if (widget.existente == null) {
        final id = await PlanosViagemService().criar(
          empresaId: empresaId,
          criadoPor: sessao.email,
          nome: _nomeCtrl.text,
          status: _status,
          placa: _placa,
          motoristaId: _motoristaId,
          rotogramaId: _rotogramaId,
          centroCustoId: _centroCustoId,
          dataSaida: _dataSaida,
          retornoPrevisto: _retornoPrevisto,
          kmEstimado: _num(_kmEstimadoCtrl),
          consumoKmL: _num(_consumoKmLCtrl),
          precoCombustivel: _num(_precoCombustivelCtrl),
          nDiarias: _num(_nDiariasCtrl).round(),
          valorRefeicaoDia: _num(_valorRefeicaoCtrl),
          valorPernoiteDia: _num(_valorPernoiteCtrl),
          valorBanhoDia: _num(_valorBanhoCtrl),
          valorLavagemDia: _num(_valorLavagemCtrl),
          custoManutencaoKm: _num(_custoManutencaoKmCtrl),
          receitaViagem: _num(_receitaViagemCtrl),
          custoTotalReal: _custoTotalRealNum,
          observacoes: _observacoesCtrl.text,
          pedagios: pedagios,
        );
        ref.invalidate(planosViagemListaProvider);
        if (!mounted) return;
        context.go('/planos-viagem/$id/editar');
      } else {
        await PlanosViagemService().atualizar(
          id: widget.existente!.id,
          nome: _nomeCtrl.text,
          status: _status,
          placa: _placa,
          motoristaId: _motoristaId,
          rotogramaId: _rotogramaId,
          centroCustoId: _centroCustoId,
          dataSaida: _dataSaida,
          retornoPrevisto: _retornoPrevisto,
          kmEstimado: _num(_kmEstimadoCtrl),
          consumoKmL: _num(_consumoKmLCtrl),
          precoCombustivel: _num(_precoCombustivelCtrl),
          nDiarias: _num(_nDiariasCtrl).round(),
          valorRefeicaoDia: _num(_valorRefeicaoCtrl),
          valorPernoiteDia: _num(_valorPernoiteCtrl),
          valorBanhoDia: _num(_valorBanhoCtrl),
          valorLavagemDia: _num(_valorLavagemCtrl),
          custoManutencaoKm: _num(_custoManutencaoKmCtrl),
          receitaViagem: _num(_receitaViagemCtrl),
          custoTotalReal: _custoTotalRealNum,
          observacoes: _observacoesCtrl.text,
          pedagios: pedagios,
        );
        ref.invalidate(planosViagemListaProvider);
        ref.invalidate(planoViagemDetalheProvider(widget.existente!.id));
        ref.invalidate(pedagiosPlanoProvider(widget.existente!.id));
        if (!mounted) return;
        setState(() => _salvando = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plano salvo.')));
        return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = 'Não foi possível salvar: $e');
    } finally {
      if (mounted && widget.existente == null) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final veiculosAsync = ref.watch(veiculosClienteProvider);
    final motoristasAsync = ref.watch(motoristasClienteProvider);
    final rotogramasAsync = ref.watch(rotogramasListaProvider);
    final centrosCustoAsync = ref.watch(centrosCustoOpcoesProvider);

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

        const Text('Identificação', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 10),
        TextField(
          controller: _nomeCtrl,
          decoration: const InputDecoration(labelText: 'Nome do Plano *', hintText: 'Ex: SP → Curitiba — Abril/2026', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _status,
          decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), isDense: true),
          items: [for (final s in statusPlanoViagem) DropdownMenuItem(value: s, child: Text(statusPlanoViagemLabel[s] ?? s))],
          onChanged: (v) => setState(() => _status = v ?? _status),
        ),
        const SizedBox(height: 10),
        veiculosAsync.when(
          data: (lista) {
            final ativos = lista.where((v) => v.ativo).toList();
            return DropdownButtonFormField<String?>(
              value: _placa,
              decoration: const InputDecoration(labelText: 'Veículo (placa)', border: OutlineInputBorder(), isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('— Selecione —')),
                if (_placa != null && !ativos.any((v) => v.placa == _placa)) DropdownMenuItem(value: _placa, child: Text(_placa!)),
                for (final v in ativos)
                  DropdownMenuItem(
                    value: v.placa,
                    child: Text('${v.placa}${[v.marca, v.modelo].where((s) => s != null && s.isNotEmpty).isNotEmpty ? ' — ${[v.marca, v.modelo].where((s) => s != null && s.isNotEmpty).join(' ')}' : ''}'),
                  ),
              ],
              onChanged: (v) => _onPlacaChange(v, ativos),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox(),
        ),
        const SizedBox(height: 10),
        motoristasAsync.when(
          data: (lista) {
            final ativos = lista.where((m) => m.ativo).toList();
            return DropdownButtonFormField<String?>(
              value: _motoristaId,
              decoration: const InputDecoration(labelText: 'Motorista', border: OutlineInputBorder(), isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('— Selecione —')),
                if (_motoristaId != null && !ativos.any((m) => m.id == _motoristaId))
                  DropdownMenuItem(value: _motoristaId, child: Text('(motorista atual)')),
                for (final m in ativos) DropdownMenuItem(value: m.id, child: Text(m.nomeCompleto)),
              ],
              onChanged: (v) => setState(() => _motoristaId = v),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox(),
        ),
        const SizedBox(height: 10),
        rotogramasAsync.when(
          data: (lista) => DropdownButtonFormField<String?>(
            value: _rotogramaId,
            decoration: const InputDecoration(labelText: 'Rotograma (opcional)', border: OutlineInputBorder(), isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('— Nenhum —')),
              for (final r in lista) DropdownMenuItem(value: r.id, child: Text('#${r.numero} ${r.origem ?? '?'} → ${r.destino ?? '?'}', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _rotogramaId = v),
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                readOnly: true,
                onTap: () => _selecionarData(saida: true),
                controller: TextEditingController(text: _dataSaida ?? ''),
                decoration: const InputDecoration(labelText: 'Data de Saída', border: OutlineInputBorder(), isDense: true, suffixIcon: Icon(Icons.calendar_today, size: 16)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                readOnly: true,
                onTap: () => _selecionarData(saida: false),
                controller: TextEditingController(text: _retornoPrevisto ?? ''),
                decoration: const InputDecoration(labelText: 'Retorno Previsto', border: OutlineInputBorder(), isDense: true, suffixIcon: Icon(Icons.calendar_today, size: 16)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _kmEstimadoCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'KM Estimado', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 20),

        const Text('Combustível', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _consumoKmLCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Consumo (km/L)', border: OutlineInputBorder(), isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _precoCombustivelCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Preço (R\$/L)', border: OutlineInputBorder(), isDense: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _campoCalculado('Custo combustível estimado', _moedaForm.format(_custoCombustivelEstimado)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Combustível real (do Controle de Custos)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
                    const SizedBox(height: 4),
                    Text(
                      _combustivelRealValor != null
                          ? '${_moedaForm.format(_combustivelRealValor)} — ${_combustivelRealLitros?.toStringAsFixed(0) ?? 0} L'
                          : (widget.existente != null ? 'Ainda não revisado.' : 'Disponível depois de salvar o plano.'),
                      style: TextStyle(fontSize: 12, color: _combustivelRealValor != null ? Colors.black87 : Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
              if (widget.existente != null)
                OutlinedButton(
                  onPressed: _revisandoCombustivel ? null : _revisarCombustivel,
                  child: Text(_revisandoCombustivel ? 'Revisando...' : 'Revisar', style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
        if (_erroRevisao != null) ...[
          const SizedBox(height: 6),
          Text(_erroRevisao!, style: const TextStyle(fontSize: 11, color: Colors.red)),
        ],
        const SizedBox(height: 20),

        _secaoPedagios(),
        const SizedBox(height: 20),

        const Text('Diárias / Pernoites', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nDiariasCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Nº de diárias', border: OutlineInputBorder(), isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _valorRefeicaoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Refeição (R\$/dia)', border: OutlineInputBorder(), isDense: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _valorPernoiteCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Pernoite (R\$/dia)', border: OutlineInputBorder(), isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _valorBanhoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Banho (R\$/dia)', border: OutlineInputBorder(), isDense: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _valorLavagemCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Lavagem de roupas (R\$/dia)', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 8),
        _campoCalculado('Custo diárias', _moedaForm.format(_custoDiarias)),
        const SizedBox(height: 20),

        const Text('Manutenção + Pneus', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 10),
        TextField(
          controller: _custoManutencaoKmCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Custo por km (R\$/km)', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 8),
        _campoCalculado('Custo manutenção', _moedaForm.format(_custoManutencaoEstimado)),
        const SizedBox(height: 20),

        const Text('Receita e Totais', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 10),
        TextField(
          controller: _receitaViagemCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Receita da viagem (R\$)', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 8),
        _campoCalculado('Custo total estimado', _moedaForm.format(_custoTotalEstimado)),
        const SizedBox(height: 8),
        TextField(
          controller: _custoTotalRealCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Custo total real (R\$)', hintText: 'Preencher após a viagem', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 8),
        _campoCalculado('Margem estimada (receita − custo estimado)', _moedaForm.format(_margemEstimada), cor: _margemEstimada >= 0 ? const Color(0xFF15803D) : const Color(0xFFDC2626)),
        if (_margemReal != null) ...[
          const SizedBox(height: 8),
          _campoCalculado('Margem real (receita − custo real)', _moedaForm.format(_margemReal), cor: _margemReal! >= 0 ? const Color(0xFF15803D) : const Color(0xFFDC2626)),
        ],
        const SizedBox(height: 20),

        const Text('Centro de Custo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 10),
        centrosCustoAsync.when(
          data: (lista) => DropdownButtonFormField<String?>(
            value: _centroCustoId,
            decoration: const InputDecoration(labelText: 'Centro de Custo (opcional)', border: OutlineInputBorder(), isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('— Nenhum (sem lançamento automático) —')),
              for (final c in lista) DropdownMenuItem(value: c.id, child: Text(c.nome, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _centroCustoId = v),
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox(),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _observacoesCtrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Observações', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _salvando ? null : _salvar,
            child: Text(_salvando ? 'Salvando...' : 'Salvar Plano'),
          ),
        ),
      ],
    );
  }

  Widget _campoCalculado(String label, String valor, {Color? cor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          const SizedBox(height: 2),
          Text(valor, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cor ?? Colors.black87)),
        ],
      ),
    );
  }

  Widget _secaoPedagios() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(child: Text('Pedágios', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
            OutlinedButton(
              onPressed: () => setState(() => _pedagios = [..._pedagios, _LinhaPedagio()]),
              child: const Text('+ Praça', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_pedagios.isEmpty)
          const Text('Nenhuma praça de pedágio adicionada. Toque em "+ Praça" para adicionar.', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic))
        else
          ..._pedagios.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: e.value.controllerPraca,
                        decoration: const InputDecoration(labelText: 'Nome da praça', border: OutlineInputBorder(), isDense: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: e.value.controllerValor,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Valor', border: OutlineInputBorder(), isDense: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.red),
                      onPressed: () => setState(() {
                        e.value.dispose();
                        _pedagios = List.of(_pedagios)..removeAt(e.key);
                      }),
                    ),
                  ],
                ),
              )),
        Align(
          alignment: Alignment.centerRight,
          child: Text('Total Pedágios: ${_moedaForm.format(_pedagiosTotal)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
