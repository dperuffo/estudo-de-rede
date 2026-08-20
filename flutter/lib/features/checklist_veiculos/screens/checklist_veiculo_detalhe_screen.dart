import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/checklist_veiculos_provider.dart';
import '../services/checklist_veiculos_service.dart';

import '../../../core/theme/app_theme.dart';

// Fase Indicadores-da-Frota C (30/07/2026) — porta de checklist-veiculos/
// [placa]/page.tsx: formulário de nova inspeção + histórico com pendências
// abertas (itens não conformes ainda sem resolvido_em).
class ChecklistVeiculoDetalheScreen extends ConsumerStatefulWidget {
  final String placa;
  const ChecklistVeiculoDetalheScreen({super.key, required this.placa});

  @override
  ConsumerState<ChecklistVeiculoDetalheScreen> createState() =>
      _ChecklistVeiculoDetalheScreenState();
}

class _ChecklistVeiculoDetalheScreenState
    extends ConsumerState<ChecklistVeiculoDetalheScreen> {
  final _dataCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10));
  final _hodometroCtrl = TextEditingController();
  final _responsavelCtrl = TextEditingController();
  final Map<String, bool> _conforme = {for (final i in itensInspecao) i: true};
  final Map<String, TextEditingController> _obsCtrls = {
    for (final i in itensInspecao) i: TextEditingController()
  };
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _dataCtrl.dispose();
    _hodometroCtrl.dispose();
    _responsavelCtrl.dispose();
    for (final c in _obsCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final atual = DateTime.tryParse(_dataCtrl.text) ?? DateTime.now();
    final escolhida = await showDatePicker(
        context: context,
        initialDate: atual,
        firstDate: DateTime(2015),
        lastDate: DateTime.now());
    if (escolhida != null)
      _dataCtrl.text = escolhida.toIso8601String().substring(0, 10);
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    if (_dataCtrl.text.trim().isEmpty) {
      setState(() => _erro = 'Data da inspeção é obrigatória.');
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
      await ChecklistVeiculosService().registrarInspecao(
        empresaId: empresaId,
        placa: widget.placa,
        dataInspecao: _dataCtrl.text.trim(),
        hodometro: double.tryParse(_hodometroCtrl.text.replaceAll(',', '.')),
        responsavel: _responsavelCtrl.text.trim().isEmpty
            ? null
            : _responsavelCtrl.text.trim(),
        itensConforme: _conforme,
        itensObservacao: {
          for (final e in _obsCtrls.entries)
            e.key: e.value.text.trim().isEmpty ? null : e.value.text.trim()
        },
        criadoPor: sessao.email,
      );
      if (!mounted) return;
      ref.invalidate(inspecoesVeiculoProvider(widget.placa));
      ref.invalidate(checklistVeiculosListProvider);
      setState(() {
        _salvando = false;
        _conforme.updateAll((_, __) => true);
        for (final c in _obsCtrls.values) {
          c.clear();
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inspeção registrada com sucesso.')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível registrar: $e';
        _salvando = false;
      });
    }
  }

  Future<void> _resolver(int id) async {
    final sessao = await ref.read(sessaoProvider.future);
    try {
      await ChecklistVeiculosService().resolverItem(id, sessao.email);
      ref.invalidate(inspecoesVeiculoProvider(widget.placa));
      ref.invalidate(checklistVeiculosListProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao marcar como resolvida: $e')));
    }
  }

  String _fmtData(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final inspecoesAsync = ref.watch(inspecoesVeiculoProvider(widget.placa));

    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: Text(widget.placa)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Registrar Nova Inspeção',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (_erro != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_erro!,
                  style:
                      const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dataCtrl,
                  readOnly: true,
                  onTap: _selecionarData,
                  decoration: const InputDecoration(
                      labelText: 'Data *',
                      border: OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: Icon(Icons.calendar_today, size: 16)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _hodometroCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Hodômetro (km)',
                      border: OutlineInputBorder(),
                      isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
              controller: _responsavelCtrl,
              decoration: const InputDecoration(
                  labelText: 'Responsável',
                  border: OutlineInputBorder(),
                  isDense: true)),
          const SizedBox(height: 14),
          const Text('Itens verificados',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ...itensInspecao.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                    child: Text(item,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600))),
                                if (itensCriticos.contains(item))
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFFFFBEB),
                                        borderRadius: BorderRadius.circular(8)),
                                    child: const Text('crítico',
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: Color(0xFF92400E))),
                                  ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _conforme[item] ?? true,
                            onChanged: (v) =>
                                setState(() => _conforme[item] = v),
                            activeColor: Colors.green,
                          ),
                          Text(
                              _conforme[item] == true
                                  ? 'Conforme'
                                  : 'Não conforme',
                              style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                      TextField(
                        controller: _obsCtrls[item],
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                            hintText: 'Observação (opcional)',
                            isDense: true,
                            border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _salvando ? null : _salvar,
              child: Text(_salvando ? 'Registrando...' : 'Registrar Inspeção'),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          Text('Histórico de Inspeções',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          inspecoesAsync.when(
            data: (inspecoes) {
              if (inspecoes.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                      child: Text('Nenhuma inspeção registrada ainda.',
                          style: TextStyle(color: Colors.grey))),
                );
              }
              final pendencias = inspecoes
                  .expand((insp) => insp.itens
                      .where((it) => !it.conforme && it.resolvidoEm == null)
                      .map((it) => (item: it, dataInspecao: insp.dataInspecao)))
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pendencias.isNotEmpty) ...[
                    Text('⚠️ Pendências abertas (${pendencias.length})',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB91C1C))),
                    const SizedBox(height: 6),
                    ...pendencias.map((p) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '${p.item.item} · desde ${_fmtData(p.dataInspecao)}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF991B1B))),
                                    if (p.item.observacao != null)
                                      Text(p.item.observacao!,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF991B1B))),
                                  ],
                                ),
                              ),
                              TextButton(
                                  onPressed: () => _resolver(p.item.id),
                                  child: const Text('Resolver',
                                      style: TextStyle(fontSize: 11))),
                            ],
                          ),
                        )),
                    const SizedBox(height: 12),
                  ],
                  ...inspecoes.map((insp) {
                    final naoConformes =
                        insp.itens.where((it) => !it.conforme).length;
                    // Fase Inspeção-pelo-Motorista (30/07/2026) — pedido do
                    // Daniel: "manutenção do histórico na visao do cliente"
                    // mostrando se a inspeção veio do motorista (app Estrada
                    // que Cuida) ou do gestor (aqui/painel web).
                    final ehMotorista = insp.origem == 'motorista';
                    return ExpansionTile(
                      title: Text(
                        '${_fmtData(insp.dataInspecao)}${insp.hodometro != null ? ' · ${insp.hodometro!.round()} km' : ''}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        ehMotorista
                            ? 'Motorista${insp.motoristaNome != null ? ' · ${insp.motoristaNome}' : ''}'
                            : 'Gestor${insp.responsavel != null ? ' · ${insp.responsavel}' : ''}',
                        style: TextStyle(
                            fontSize: 11,
                            color: ehMotorista
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFF64748B)),
                      ),
                      trailing: naoConformes > 0
                          ? Text('$naoConformes não conforme(s)',
                              style: const TextStyle(
                                  fontSize: 10, color: Color(0xFF991B1B)))
                          : const Text('Tudo conforme',
                              style: TextStyle(
                                  fontSize: 10, color: Color(0xFF166534))),
                      children: insp.itens
                          .map((it) => ListTile(
                                dense: true,
                                leading: Icon(
                                    it.conforme
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    size: 18,
                                    color: it.conforme
                                        ? Colors.green
                                        : Colors.red),
                                title: Text(it.item,
                                    style: const TextStyle(fontSize: 12)),
                                subtitle: it.observacao != null
                                    ? Text(it.observacao!,
                                        style: const TextStyle(fontSize: 11))
                                    : null,
                              ))
                          .toList(),
                    );
                  }),
                ],
              );
            },
            loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('Erro ao carregar histórico: $e',
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
