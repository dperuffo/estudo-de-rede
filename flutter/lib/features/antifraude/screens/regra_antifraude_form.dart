import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../motoristas/providers/motoristas_provider.dart' show Motorista;
import '../../veiculos/providers/veiculos_provider.dart' show Veiculo;
import '../providers/antifraude_provider.dart';
import '../services/antifraude_service.dart';

// Fase 27.15x — formulário único de criar/editar regra antifraude, cobrindo
// os tipos (troca os campos de "condições" conforme o tipo escolhido) —
// porta de RegraAntifraudeForm.tsx (web). Mesmo padrão de showModalBottomSheet
// já usado em regras_forms.dart (Parâmetros de Uso).
//
// Fase Antifraude→Ações-Sugeridas — o tipo "localizacao_posto" que existia
// aqui foi migrado pra Ações Sugeridas (ver features/acoes_sugeridas).

num? _paraNum(String s) => s.trim().isEmpty ? null : num.tryParse(s.trim().replaceAll(',', '.'));

Widget _erroBox(String? erro) {
  if (erro == null) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
      child: Text(erro, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
    ),
  );
}

Future<void> mostrarFormRegraAntifraude(
  BuildContext context,
  WidgetRef ref,
  String empresaId,
  String tipoInicial,
  List<Veiculo> veiculos,
  List<Motorista> motoristas, {
  RegraAntifraudeRow? regraExistente,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Text(regraExistente == null ? 'Nova Regra Antifraude' : 'Editar Regra',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              _FormRegraAntifraude(
                empresaId: empresaId,
                tipoInicial: tipoInicial,
                veiculos: veiculos,
                motoristas: motoristas,
                regraExistente: regraExistente,
                ref: ref,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FormRegraAntifraude extends StatefulWidget {
  final String empresaId;
  final String tipoInicial;
  final List<Veiculo> veiculos;
  final List<Motorista> motoristas;
  final RegraAntifraudeRow? regraExistente;
  final WidgetRef ref;
  const _FormRegraAntifraude({
    required this.empresaId,
    required this.tipoInicial,
    required this.veiculos,
    required this.motoristas,
    required this.regraExistente,
    required this.ref,
  });

  @override
  State<_FormRegraAntifraude> createState() => _FormRegraAntifraudeState();
}

class _FormRegraAntifraudeState extends State<_FormRegraAntifraude> {
  late final _nomeCtrl = TextEditingController(text: widget.regraExistente?.nome ?? '');
  late String _tipo = widget.regraExistente?.tipo ?? widget.tipoInicial;
  late String _escopo = widget.regraExistente?.escopo ?? 'empresa';
  String? _escopoReferencia;
  late DateTime _vigenciaInicio =
      widget.regraExistente != null ? DateTime.parse(widget.regraExistente!.vigenciaInicio) : DateTime.now();
  DateTime? _vigenciaFim;
  late bool _ativo = widget.regraExistente?.ativo ?? true;

  // Condições — controllers cobrindo os tipos (só os do tipo selecionado
  // são de fato usados/enviados).
  final _litrosMaxDiaCtrl = TextEditingController();
  final _valorMaxAbastecimentoCtrl = TextEditingController();
  final _intervaloMinimoHorasCtrl = TextEditingController();
  final _horarioInicioCtrl = TextEditingController();
  final _horarioFimCtrl = TextEditingController();

  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final r = widget.regraExistente;
    if (r != null) {
      _escopoReferencia = r.escopoReferencia;
      if (r.vigenciaFim != null) _vigenciaFim = DateTime.parse(r.vigenciaFim!);
      final c = r.condicoes;
      _litrosMaxDiaCtrl.text = c['litros_max_dia']?.toString() ?? '';
      _valorMaxAbastecimentoCtrl.text = c['valor_max_abastecimento']?.toString() ?? '';
      _intervaloMinimoHorasCtrl.text = c['intervalo_minimo_horas']?.toString() ?? '';
      final horario = c['horario_permitido'] as Map?;
      _horarioInicioCtrl.text = horario?['inicio']?.toString() ?? '';
      _horarioFimCtrl.text = horario?['fim']?.toString() ?? '';
    }
  }

  Future<void> _salvar() async {
    setState(() {
      _salvando = true;
      _erro = null;
    });

    final service = AntifraudeService();
    final erro = widget.regraExistente == null
        ? await service.criar(
            empresaId: widget.empresaId,
            nome: _nomeCtrl.text,
            tipo: _tipo,
            escopo: _escopo,
            escopoReferencia: _escopoReferencia,
            vigenciaInicio: _vigenciaInicio.toIso8601String().substring(0, 10),
            vigenciaFim: _vigenciaFim?.toIso8601String().substring(0, 10),
            litrosMaxDia: _paraNum(_litrosMaxDiaCtrl.text),
            valorMaxAbastecimento: _paraNum(_valorMaxAbastecimentoCtrl.text),
            intervaloMinimoHoras: _paraNum(_intervaloMinimoHorasCtrl.text),
            horarioInicio: _horarioInicioCtrl.text.trim().isEmpty ? null : _horarioInicioCtrl.text.trim(),
            horarioFim: _horarioFimCtrl.text.trim().isEmpty ? null : _horarioFimCtrl.text.trim(),
          )
        : await service.atualizar(
            id: widget.regraExistente!.id,
            nome: _nomeCtrl.text,
            tipo: _tipo,
            escopo: _escopo,
            escopoReferencia: _escopoReferencia,
            vigenciaInicio: _vigenciaInicio.toIso8601String().substring(0, 10),
            vigenciaFim: _vigenciaFim?.toIso8601String().substring(0, 10),
            ativo: _ativo,
            litrosMaxDia: _paraNum(_litrosMaxDiaCtrl.text),
            valorMaxAbastecimento: _paraNum(_valorMaxAbastecimentoCtrl.text),
            intervaloMinimoHoras: _paraNum(_intervaloMinimoHorasCtrl.text),
            horarioInicio: _horarioInicioCtrl.text.trim().isEmpty ? null : _horarioInicioCtrl.text.trim(),
            horarioFim: _horarioFimCtrl.text.trim().isEmpty ? null : _horarioFimCtrl.text.trim(),
          );

    if (!mounted) return;
    setState(() => _salvando = false);
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    widget.ref.invalidate(regrasAntifraudeProvider(_tipo));
    if (widget.regraExistente != null && widget.regraExistente!.tipo != _tipo) {
      widget.ref.invalidate(regrasAntifraudeProvider(widget.regraExistente!.tipo));
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _escolherData({required bool inicio}) async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: inicio ? _vigenciaInicio : (_vigenciaFim ?? DateTime.now()),
      firstDate: DateTime(2020),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _erroBox(_erro),
        TextField(
          controller: _nomeCtrl,
          decoration: const InputDecoration(labelText: 'Nome *', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _tipo,
          decoration: const InputDecoration(labelText: 'Tipo de regra *', border: OutlineInputBorder()),
          items: [for (final t in tiposRegraAntifraude) DropdownMenuItem(value: t.$1, child: Text(t.$2))],
          onChanged: (v) => setState(() => _tipo = v ?? _tipo),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _escopo,
          decoration: const InputDecoration(labelText: 'Escopo *', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'empresa', child: Text('Empresa toda')),
            DropdownMenuItem(value: 'motorista', child: Text('Um motorista específico')),
            DropdownMenuItem(value: 'veiculo', child: Text('Um veículo específico')),
          ],
          onChanged: (v) => setState(() {
            _escopo = v ?? 'empresa';
            _escopoReferencia = null;
          }),
        ),
        const SizedBox(height: 10),
        if (_escopo == 'motorista')
          DropdownButtonFormField<String>(
            value: _escopoReferencia,
            decoration: const InputDecoration(labelText: 'Motorista *', border: OutlineInputBorder()),
            items: [for (final m in widget.motoristas) DropdownMenuItem(value: m.cpf, child: Text(m.nomeCompleto))],
            onChanged: (v) => setState(() => _escopoReferencia = v),
          ),
        if (_escopo == 'veiculo')
          DropdownButtonFormField<String>(
            value: _escopoReferencia,
            decoration: const InputDecoration(labelText: 'Veículo (placa) *', border: OutlineInputBorder()),
            items: [for (final v in widget.veiculos) DropdownMenuItem(value: v.placa, child: Text(v.placa))],
            onChanged: (v) => setState(() => _escopoReferencia = v),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _escolherData(inicio: true),
                child: Text('Início: ${_vigenciaInicio.toIso8601String().substring(0, 10)}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _escolherData(inicio: false),
                child: Text(_vigenciaFim == null ? 'Fim: sem prazo' : 'Fim: ${_vigenciaFim!.toIso8601String().substring(0, 10)}'),
              ),
            ),
          ],
        ),
        if (widget.regraExistente != null) ...[
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Regra ativa'),
            value: _ativo,
            onChanged: (v) => setState(() => _ativo = v),
          ),
        ],
        const Divider(height: 24),
        Text('Condições', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ..._camposCondicoes(),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _salvando ? null : _salvar,
            child: Text(_salvando ? 'Salvando...' : 'Salvar'),
          ),
        ),
      ],
    );
  }

  List<Widget> _camposCondicoes() {
    if (_tipo == 'limite_valor_quantidade') {
      return [
        TextField(
          controller: _litrosMaxDiaCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Litros máximos por dia', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _valorMaxAbastecimentoCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              const InputDecoration(labelText: 'Valor máximo por abastecimento (R\$)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 6),
        const Text('Preencha ao menos um dos dois campos acima.', style: TextStyle(fontSize: 11, color: Colors.grey)),
      ];
    }
    // janela_tempo_frequencia
    return [
      TextField(
        controller: _intervaloMinimoHorasCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
            labelText: 'Intervalo mínimo entre abastecimentos (horas)', border: OutlineInputBorder()),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _horarioInicioCtrl,
              decoration: const InputDecoration(labelText: 'Início (HH:MM)', border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _horarioFimCtrl,
              decoration: const InputDecoration(labelText: 'Fim (HH:MM)', border: OutlineInputBorder()),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      const Text('Preencha o intervalo mínimo, o horário permitido, ou os dois.',
          style: TextStyle(fontSize: 11, color: Colors.grey)),
    ];
  }
}
