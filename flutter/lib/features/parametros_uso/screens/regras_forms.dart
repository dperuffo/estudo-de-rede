import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../motoristas/providers/motoristas_provider.dart' show Motorista;
import '../../veiculos/providers/veiculos_provider.dart' show Veiculo;
import '../providers/parametros_uso_provider.dart';
import '../services/parametros_uso_service.dart';

// Fase FLT-3 — os 8 formulários "Nova Regra" (tudo que não é Vínculo, que
// tem tela própria — ver vinculo_novo_screen.dart). Cada um é mostrado via
// showModalBottomSheet a partir de parametros_uso_screen.dart, no mesmo
// espírito do ModalRegra inline da web. Todos compartilham o mesmo rodapé
// de erro/botão salvar — replicado em cada um (são formulários pequenos,
// não valeu a pena abstrair um wrapper genérico a mais).

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

Widget _folha({required String titulo, required Widget child}) {
  return Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(_ctxAtual!).viewInsets.bottom),
    child: DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          controller: scrollController,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    ),
  );
}

// Pequeno truque pra acessar o BuildContext dentro de _folha sem precisar
// passar em cada chamada — setado no início de cada show*Sheet abaixo.
BuildContext? _ctxAtual;

Future<void> mostrarFormIntervalo(BuildContext context, WidgetRef ref, String empresaId, List<Veiculo> veiculos, List<Motorista> motoristas) {
  _ctxAtual = context;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _folha(
      titulo: 'Nova Regra de Intervalo',
      child: _FormIntervalo(empresaId: empresaId, veiculos: veiculos, motoristas: motoristas, ref: ref),
    ),
  );
}

class _FormIntervalo extends StatefulWidget {
  final String empresaId;
  final List<Veiculo> veiculos;
  final List<Motorista> motoristas;
  final WidgetRef ref;
  const _FormIntervalo({required this.empresaId, required this.veiculos, required this.motoristas, required this.ref});

  @override
  State<_FormIntervalo> createState() => _FormIntervaloState();
}

class _FormIntervaloState extends State<_FormIntervalo> {
  String _tipo = 'Veiculo';
  String? _placa;
  String? _motoristaId;
  final _minimoCtrl = TextEditingController();
  String _unidade = 'Horas';
  final _obsCtrl = TextEditingController();
  bool _salvando = false;
  String? _erro;

  Future<void> _salvar() async {
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final erro = await ParametrosUsoService().criarIntervalo(
      empresaId: widget.empresaId,
      tipo: _tipo,
      placa: _placa,
      motoristaId: _motoristaId,
      intervaloMinimo: _paraNum(_minimoCtrl.text) ?? 0,
      unidade: _unidade,
      observacao: _obsCtrl.text,
    );
    if (!mounted) return;
    setState(() => _salvando = false);
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    widget.ref.invalidate(intervalosProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _erroBox(_erro),
        DropdownButtonFormField<String>(
          value: _tipo,
          decoration: const InputDecoration(labelText: 'Tipo de regra *', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'Veiculo', child: Text('Por Veículo')),
            DropdownMenuItem(value: 'Motorista', child: Text('Por Motorista')),
          ],
          onChanged: (v) => setState(() => _tipo = v ?? 'Veiculo'),
        ),
        const SizedBox(height: 10),
        if (_tipo == 'Veiculo')
          DropdownButtonFormField<String>(
            value: _placa,
            decoration: const InputDecoration(labelText: 'Veículo (placa)', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todos os veículos (regra geral)')),
              for (final v in widget.veiculos) DropdownMenuItem(value: v.placa, child: Text(v.placa)),
            ],
            onChanged: (v) => setState(() => _placa = v),
          )
        else
          DropdownButtonFormField<String>(
            value: _motoristaId,
            decoration: const InputDecoration(labelText: 'Motorista', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todos os motoristas (regra geral)')),
              for (final m in widget.motoristas) DropdownMenuItem(value: m.id, child: Text(m.nomeCompleto)),
            ],
            onChanged: (v) => setState(() => _motoristaId = v),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _minimoCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Intervalo mínimo *', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _unidade,
                decoration: const InputDecoration(labelText: 'Unidade', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Horas', child: Text('Horas')),
                  DropdownMenuItem(value: 'Dias', child: Text('Dias')),
                ],
                onChanged: (v) => setState(() => _unidade = v ?? 'Horas'),
              ),
            ),
          ],
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

Future<void> mostrarFormValorDiario(BuildContext context, WidgetRef ref, String empresaId, List<Motorista> motoristas) {
  _ctxAtual = context;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _folha(
      titulo: 'Nova Regra — Valor Diário',
      child: _FormValorDiario(empresaId: empresaId, motoristas: motoristas, ref: ref),
    ),
  );
}

class _FormValorDiario extends StatefulWidget {
  final String empresaId;
  final List<Motorista> motoristas;
  final WidgetRef ref;
  const _FormValorDiario({required this.empresaId, required this.motoristas, required this.ref});
  @override
  State<_FormValorDiario> createState() => _FormValorDiarioState();
}

class _FormValorDiarioState extends State<_FormValorDiario> {
  String? _motoristaId;
  final _valorCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  bool _salvando = false;
  String? _erro;

  Future<void> _salvar() async {
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final erro = await ParametrosUsoService().criarValorDiario(
      empresaId: widget.empresaId,
      motoristaId: _motoristaId,
      valorMaximo: _paraNum(_valorCtrl.text) ?? 0,
      observacao: _obsCtrl.text,
    );
    if (!mounted) return;
    setState(() => _salvando = false);
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    widget.ref.invalidate(valoresDiariosProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _erroBox(_erro),
        DropdownButtonFormField<String>(
          value: _motoristaId,
          decoration: const InputDecoration(labelText: 'Motorista', border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem(value: null, child: Text('Todos os motoristas (regra geral)')),
            for (final m in widget.motoristas) DropdownMenuItem(value: m.id, child: Text(m.nomeCompleto)),
          ],
          onChanged: (v) => setState(() => _motoristaId = v),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _valorCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Valor máximo diário (R\$) *', border: OutlineInputBorder()),
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

Future<void> mostrarFormVolumeDiario(BuildContext context, WidgetRef ref, String empresaId, List<Veiculo> veiculos) {
  _ctxAtual = context;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _folha(
      titulo: 'Nova Regra — Volume Diário',
      child: _FormVolumeDiario(empresaId: empresaId, veiculos: veiculos, ref: ref),
    ),
  );
}

class _FormVolumeDiario extends StatefulWidget {
  final String empresaId;
  final List<Veiculo> veiculos;
  final WidgetRef ref;
  const _FormVolumeDiario({required this.empresaId, required this.veiculos, required this.ref});
  @override
  State<_FormVolumeDiario> createState() => _FormVolumeDiarioState();
}

class _FormVolumeDiarioState extends State<_FormVolumeDiario> {
  String? _placa;
  final _volumeCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  bool _salvando = false;
  String? _erro;

  Future<void> _salvar() async {
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final erro = await ParametrosUsoService().criarVolumeDiario(
      empresaId: widget.empresaId,
      placa: _placa,
      volumeMaximo: _paraNum(_volumeCtrl.text) ?? 0,
      observacao: _obsCtrl.text,
    );
    if (!mounted) return;
    setState(() => _salvando = false);
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    widget.ref.invalidate(volumesDiariosProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _erroBox(_erro),
        DropdownButtonFormField<String>(
          value: _placa,
          decoration: const InputDecoration(labelText: 'Veículo (placa)', border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem(value: null, child: Text('Todos os veículos (regra geral)')),
            for (final v in widget.veiculos) DropdownMenuItem(value: v.placa, child: Text(v.placa)),
          ],
          onChanged: (v) => setState(() => _placa = v),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _volumeCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Volume máximo diário (L) *', border: OutlineInputBorder()),
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

Future<void> mostrarFormProduto(BuildContext context, WidgetRef ref, String empresaId, List<Veiculo> veiculos) {
  _ctxAtual = context;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _folha(
      titulo: 'Nova Regra — Produto Abastecido',
      child: _FormProduto(empresaId: empresaId, veiculos: veiculos, ref: ref),
    ),
  );
}

class _FormProduto extends StatefulWidget {
  final String empresaId;
  final List<Veiculo> veiculos;
  final WidgetRef ref;
  const _FormProduto({required this.empresaId, required this.veiculos, required this.ref});
  @override
  State<_FormProduto> createState() => _FormProdutoState();
}

class _FormProdutoState extends State<_FormProduto> {
  String? _placa;
  final Set<String> _combustiveis = {};
  final _obsCtrl = TextEditingController();
  bool _salvando = false;
  String? _erro;

  Future<void> _salvar() async {
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final erro = await ParametrosUsoService().criarProduto(
      empresaId: widget.empresaId,
      placa: _placa,
      combustiveisPermitidos: _combustiveis.toList(),
      observacao: _obsCtrl.text,
    );
    if (!mounted) return;
    setState(() => _salvando = false);
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    widget.ref.invalidate(produtosProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _erroBox(_erro),
        DropdownButtonFormField<String>(
          value: _placa,
          decoration: const InputDecoration(labelText: 'Veículo (placa)', border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem(value: null, child: Text('Todos os veículos (regra geral)')),
            for (final v in widget.veiculos) DropdownMenuItem(value: v.placa, child: Text(v.placa)),
          ],
          onChanged: (v) => setState(() => _placa = v),
        ),
        const SizedBox(height: 10),
        const Text('Combustíveis permitidos', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Wrap(
          spacing: 6,
          children: [
            for (final c in combustiveisParametro)
              FilterChip(
                label: Text(c),
                selected: _combustiveis.contains(c),
                onSelected: (sel) => setState(() => sel ? _combustiveis.add(c) : _combustiveis.remove(c)),
              ),
          ],
        ),
        Text('Nenhum marcado = usa o combustível do cadastro do veículo.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
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

Future<void> mostrarFormHodometro(
    BuildContext context, WidgetRef ref, String empresaId, String classificacao, List<Veiculo> veiculos) {
  _ctxAtual = context;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _folha(
      titulo: 'Nova Regra — Hodômetro $classificacao',
      child: _FormHodometro(empresaId: empresaId, classificacao: classificacao, veiculos: veiculos, ref: ref),
    ),
  );
}

class _FormHodometro extends StatefulWidget {
  final String empresaId;
  final String classificacao;
  final List<Veiculo> veiculos;
  final WidgetRef ref;
  const _FormHodometro(
      {required this.empresaId, required this.classificacao, required this.veiculos, required this.ref});
  @override
  State<_FormHodometro> createState() => _FormHodometroState();
}

class _FormHodometroState extends State<_FormHodometro> {
  String? _placa;
  final _variacaoCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  bool _salvando = false;
  String? _erro;

  Future<void> _salvar() async {
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final erro = await ParametrosUsoService().criarVariacaoHodometro(
      empresaId: widget.empresaId,
      classificacao: widget.classificacao,
      placa: _placa,
      variacaoMaximaKm: _paraNum(_variacaoCtrl.text) ?? 0,
      observacao: _obsCtrl.text,
    );
    if (!mounted) return;
    setState(() => _salvando = false);
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    widget.ref.invalidate(variacoesHodometroProvider(widget.classificacao));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _erroBox(_erro),
        DropdownButtonFormField<String>(
          value: _placa,
          decoration: const InputDecoration(labelText: 'Veículo (placa)', border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem(value: null, child: Text('Todos os veículos (regra geral)')),
            for (final v in widget.veiculos) DropdownMenuItem(value: v.placa, child: Text(v.placa)),
          ],
          onChanged: (v) => setState(() => _placa = v),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _variacaoCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Variação máxima (km) *', border: OutlineInputBorder()),
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

Future<void> mostrarFormDiasHorarios(
    BuildContext context, WidgetRef ref, String empresaId, List<Veiculo> veiculos, List<Motorista> motoristas) {
  _ctxAtual = context;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _folha(
      titulo: 'Nova Restrição de Horário',
      child: _FormDiasHorarios(empresaId: empresaId, veiculos: veiculos, motoristas: motoristas, ref: ref),
    ),
  );
}

class _FormDiasHorarios extends StatefulWidget {
  final String empresaId;
  final List<Veiculo> veiculos;
  final List<Motorista> motoristas;
  final WidgetRef ref;
  const _FormDiasHorarios(
      {required this.empresaId, required this.veiculos, required this.motoristas, required this.ref});
  @override
  State<_FormDiasHorarios> createState() => _FormDiasHorariosState();
}

class _FormDiasHorariosState extends State<_FormDiasHorarios> {
  String? _classificacao;
  String? _placa;
  String? _motoristaId;
  final Set<String> _dias = {'Seg', 'Ter', 'Qua', 'Qui', 'Sex'};
  TimeOfDay _horaInicio = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _horaFim = const TimeOfDay(hour: 20, minute: 0);
  final _obsCtrl = TextEditingController();
  bool _salvando = false;
  String? _erro;

  String _fmtHora(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _salvar() async {
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final erro = await ParametrosUsoService().criarDiasHorarios(
      empresaId: widget.empresaId,
      classificacao: _classificacao,
      placa: _placa,
      motoristaId: _motoristaId,
      diasPermitidos: _dias.toList(),
      horaInicio: _fmtHora(_horaInicio),
      horaFim: _fmtHora(_horaFim),
      observacao: _obsCtrl.text,
    );
    if (!mounted) return;
    setState(() => _salvando = false);
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    widget.ref.invalidate(diasHorariosProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _erroBox(_erro),
        DropdownButtonFormField<String>(
          value: _classificacao,
          decoration: const InputDecoration(labelText: 'Classificação', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: null, child: Text('Todos')),
            DropdownMenuItem(value: 'Leve', child: Text('Leve')),
            DropdownMenuItem(value: 'Pesado', child: Text('Pesado')),
          ],
          onChanged: (v) => setState(() => _classificacao = v),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _placa,
          decoration: const InputDecoration(labelText: 'Veículo (placa)', border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem(value: null, child: Text('Todos os veículos')),
            for (final v in widget.veiculos) DropdownMenuItem(value: v.placa, child: Text(v.placa)),
          ],
          onChanged: (v) => setState(() => _placa = v),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _motoristaId,
          decoration: const InputDecoration(labelText: 'Motorista', border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem(value: null, child: Text('Todos os motoristas')),
            for (final m in widget.motoristas) DropdownMenuItem(value: m.id, child: Text(m.nomeCompleto)),
          ],
          onChanged: (v) => setState(() => _motoristaId = v),
        ),
        const SizedBox(height: 10),
        const Text('Dias permitidos *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Wrap(
          spacing: 6,
          children: [
            for (final d in diasSemanaParametro)
              FilterChip(
                label: Text(d),
                selected: _dias.contains(d),
                onSelected: (sel) => setState(() => sel ? _dias.add(d) : _dias.remove(d)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final t = await showTimePicker(context: context, initialTime: _horaInicio);
                  if (t != null) setState(() => _horaInicio = t);
                },
                child: Text('Início: ${_fmtHora(_horaInicio)}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final t = await showTimePicker(context: context, initialTime: _horaFim);
                  if (t != null) setState(() => _horaFim = t);
                },
                child: Text('Fim: ${_fmtHora(_horaFim)}'),
              ),
            ),
          ],
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
              : const Text('Salvar Restrição'),
        ),
      ],
    );
  }
}

Future<void> mostrarFormPostos(BuildContext context, WidgetRef ref, String empresaId, List<Veiculo> veiculos,
    List<Motorista> motoristas, List<PostoOpcao> postos) {
  _ctxAtual = context;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _folha(
      titulo: 'Nova Restrição de Posto',
      child: _FormPostos(empresaId: empresaId, veiculos: veiculos, motoristas: motoristas, postos: postos, ref: ref),
    ),
  );
}

class _FormPostos extends StatefulWidget {
  final String empresaId;
  final List<Veiculo> veiculos;
  final List<Motorista> motoristas;
  final List<PostoOpcao> postos;
  final WidgetRef ref;
  const _FormPostos(
      {required this.empresaId,
      required this.veiculos,
      required this.motoristas,
      required this.postos,
      required this.ref});
  @override
  State<_FormPostos> createState() => _FormPostosState();
}

class _FormPostosState extends State<_FormPostos> {
  String? _classificacao;
  String? _placa;
  String? _motoristaId;
  final Set<String> _postosCnpj = {};
  String _tipoLimite = 'Sem limite';
  final _valorCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  bool _salvando = false;
  String? _erro;

  Future<void> _salvar() async {
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final erro = await ParametrosUsoService().criarPostosPermitidos(
      empresaId: widget.empresaId,
      classificacao: _classificacao,
      placa: _placa,
      motoristaId: _motoristaId,
      postosCnpj: _postosCnpj.toList(),
      tipoLimite: _tipoLimite,
      valorMaximo: _paraNum(_valorCtrl.text),
      observacao: _obsCtrl.text,
    );
    if (!mounted) return;
    setState(() => _salvando = false);
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    widget.ref.invalidate(postosPermitidosProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _erroBox(_erro),
        DropdownButtonFormField<String>(
          value: _classificacao,
          decoration: const InputDecoration(labelText: 'Classificação', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: null, child: Text('Todos')),
            DropdownMenuItem(value: 'Leve', child: Text('Leve')),
            DropdownMenuItem(value: 'Pesado', child: Text('Pesado')),
          ],
          onChanged: (v) => setState(() => _classificacao = v),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _placa,
          decoration: const InputDecoration(labelText: 'Veículo (placa)', border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem(value: null, child: Text('Todos os veículos')),
            for (final v in widget.veiculos) DropdownMenuItem(value: v.placa, child: Text(v.placa)),
          ],
          onChanged: (v) => setState(() => _placa = v),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _motoristaId,
          decoration: const InputDecoration(labelText: 'Motorista', border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem(value: null, child: Text('Todos os motoristas')),
            for (final m in widget.motoristas) DropdownMenuItem(value: m.id, child: Text(m.nomeCompleto)),
          ],
          onChanged: (v) => setState(() => _motoristaId = v),
        ),
        const SizedBox(height: 10),
        const Text('Postos permitidos *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        if (widget.postos.isEmpty)
          Text('Nenhum posto negociado ainda — feche uma negociação em "Negociações com Postos" primeiro.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
        else
          Wrap(
            spacing: 6,
            children: [
              for (final p in widget.postos)
                FilterChip(
                  label: Text(p.nome),
                  selected: _postosCnpj.contains(p.cnpj),
                  onSelected: (sel) => setState(() => sel ? _postosCnpj.add(p.cnpj) : _postosCnpj.remove(p.cnpj)),
                ),
            ],
          ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _tipoLimite,
          decoration: const InputDecoration(labelText: 'Tipo de limite', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'Sem limite', child: Text('Sem limite')),
            DropdownMenuItem(value: 'Valor', child: Text('Valor máximo (R\$)')),
            DropdownMenuItem(value: 'Volume', child: Text('Volume máximo (L)')),
          ],
          onChanged: (v) => setState(() => _tipoLimite = v ?? 'Sem limite'),
        ),
        if (_tipoLimite != 'Sem limite') ...[
          const SizedBox(height: 10),
          TextField(
            controller: _valorCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Valor máximo', border: OutlineInputBorder()),
          ),
        ],
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
              : const Text('Salvar Restrição'),
        ),
      ],
    );
  }
}

Future<void> mostrarFormCota(BuildContext context, WidgetRef ref, String empresaId, List<Veiculo> veiculos) {
  _ctxAtual = context;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _folha(
      titulo: 'Nova Cota por Veículo',
      child: _FormCota(empresaId: empresaId, veiculos: veiculos, ref: ref),
    ),
  );
}

class _FormCota extends StatefulWidget {
  final String empresaId;
  final List<Veiculo> veiculos;
  final WidgetRef ref;
  const _FormCota({required this.empresaId, required this.veiculos, required this.ref});
  @override
  State<_FormCota> createState() => _FormCotaState();
}

class _FormCotaState extends State<_FormCota> {
  String? _placa;
  String _tipo = 'Valor';
  final _limiteCtrl = TextEditingController();
  String _periodicidade = 'Mes';
  final _obsCtrl = TextEditingController();
  bool _salvando = false;
  String? _erro;

  Future<void> _salvar() async {
    if (_placa == null) {
      setState(() => _erro = 'Veículo, tipo de cota (Valor/Volume) e limite são obrigatórios.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final erro = await ParametrosUsoService().criarCota(
      empresaId: widget.empresaId,
      placa: _placa!,
      tipo: _tipo,
      limite: _paraNum(_limiteCtrl.text) ?? 0,
      periodicidade: _periodicidade,
      observacao: _obsCtrl.text,
    );
    if (!mounted) return;
    setState(() => _salvando = false);
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    widget.ref.invalidate(cotasProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _erroBox(_erro),
        DropdownButtonFormField<String>(
          value: _placa,
          decoration: const InputDecoration(labelText: 'Veículo (placa) *', border: OutlineInputBorder()),
          items: [for (final v in widget.veiculos) DropdownMenuItem(value: v.placa, child: Text(v.placa))],
          onChanged: (v) => setState(() => _placa = v),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo de cota', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Valor', child: Text('Valor (R\$)')),
                  DropdownMenuItem(value: 'Volume', child: Text('Volume (L)')),
                ],
                onChanged: (v) => setState(() => _tipo = v ?? 'Valor'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _limiteCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Limite *', border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _periodicidade,
          decoration: const InputDecoration(labelText: 'Periodicidade', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'Abastecimento', child: Text('Por abastecimento')),
            DropdownMenuItem(value: 'Semana', child: Text('Por semana (7 dias)')),
            DropdownMenuItem(value: 'Quinzena', child: Text('Por quinzena (15 dias)')),
            DropdownMenuItem(value: 'Mes', child: Text('Por mês')),
          ],
          onChanged: (v) => setState(() => _periodicidade = v ?? 'Mes'),
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
              : const Text('Salvar Cota'),
        ),
      ],
    );
  }
}
