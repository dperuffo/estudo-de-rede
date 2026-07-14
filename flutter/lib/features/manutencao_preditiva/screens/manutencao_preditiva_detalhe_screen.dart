import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/manutencao_preditiva_provider.dart';
import '../services/manutencao_preditiva_service.dart';

// Fase FLT-3 — Manutenção Preditiva (cliente): detalhe do veículo, porta
// de manutencao-preditiva/[placa]/page.tsx (+ ComponenteCard,
// RegistrarManutencaoForm, HistoricoManutencoes).
class ManutencaoPreditivaDetalheScreen extends ConsumerStatefulWidget {
  final String placa;
  const ManutencaoPreditivaDetalheScreen({super.key, required this.placa});

  @override
  ConsumerState<ManutencaoPreditivaDetalheScreen> createState() => _ManutencaoPreditivaDetalheScreenState();
}

class _ManutencaoPreditivaDetalheScreenState extends ConsumerState<ManutencaoPreditivaDetalheScreen> {
  final _dataCtrl = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
  final _hodometroCtrl = TextEditingController();
  final _custoCtrl = TextEditingController();
  final _tecnicoCtrl = TextEditingController();
  final _oficinaCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  final _itensSelecionados = <String>{};
  bool _salvando = false;
  String? _erroForm;
  bool _sucessoForm = false;

  @override
  void dispose() {
    _dataCtrl.dispose();
    _hodometroCtrl.dispose();
    _custoCtrl.dispose();
    _tecnicoCtrl.dispose();
    _oficinaCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final atual = DateTime.tryParse(_dataCtrl.text) ?? DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (escolhida != null) {
      _dataCtrl.text = escolhida.toIso8601String().substring(0, 10);
    }
  }

  Future<void> _registrar() async {
    setState(() {
      _erroForm = null;
      _sucessoForm = false;
    });
    if (_dataCtrl.text.trim().isEmpty) {
      setState(() => _erroForm = 'Data da manutenção é obrigatória.');
      return;
    }
    if (_itensSelecionados.isEmpty) {
      setState(() => _erroForm = 'Selecione ao menos um item realizado.');
      return;
    }
    final sessao = await ref.read(sessaoProvider.future);
    final empresaId = sessao.empresaId;
    if (empresaId == null) {
      setState(() => _erroForm = 'Selecione uma empresa antes.');
      return;
    }

    setState(() => _salvando = true);
    try {
      await ManutencaoPreditivaService().registrar(
        empresaId: empresaId,
        placa: widget.placa,
        dataManutencao: _dataCtrl.text.trim(),
        hodometro: double.tryParse(_hodometroCtrl.text.replaceAll(',', '.')),
        tecnico: _tecnicoCtrl.text.trim(),
        oficina: _oficinaCtrl.text.trim(),
        custoTotal: double.tryParse(_custoCtrl.text.replaceAll(',', '.')),
        itensRealizados: _itensSelecionados.toList(),
        obsGerais: _obsCtrl.text.trim(),
        criadoPor: sessao.email,
      );
      if (!mounted) return;
      _hodometroCtrl.clear();
      _custoCtrl.clear();
      _tecnicoCtrl.clear();
      _oficinaCtrl.clear();
      _obsCtrl.clear();
      setState(() {
        _itensSelecionados.clear();
        _sucessoForm = true;
        _salvando = false;
      });
      ref.invalidate(manutencaoDetalheProvider(widget.placa));
      ref.invalidate(historicoManutencaoProvider(widget.placa));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erroForm = 'Não foi possível registrar: $e';
        _salvando = false;
      });
    }
  }

  Future<void> _excluir(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir registro?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;
    await ManutencaoPreditivaService().excluir(id);
    ref.invalidate(historicoManutencaoProvider(widget.placa));
    ref.invalidate(manutencaoDetalheProvider(widget.placa));
  }

  @override
  Widget build(BuildContext context) {
    final detalheAsync = ref.watch(manutencaoDetalheProvider(widget.placa));
    return Scaffold(
      appBar: AppBar(title: Text(widget.placa)),
      body: detalheAsync.when(
        data: (v) {
          if (v == null) {
            return const Center(child: Text('Veículo não encontrado.'));
          }
          return _conteudo(v);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
      ),
    );
  }

  Widget _conteudo(VeiculoDetalheManutencao v) {
    final historicoAsync = ref.watch(historicoManutencaoProvider(widget.placa));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [v.marca, v.modelo].where((s) => s != null && s.isNotEmpty).join(' ').isEmpty
                        ? 'Sem marca/modelo cadastrado'
                        : [v.marca, v.modelo].where((s) => s != null && s.isNotEmpty).join(' '),
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  Text(
                    '${v.tipoVeiculo != null ? '${v.tipoVeiculo} · ' : ''}${v.idadeAnos > 0 ? '${v.idadeAnos} anos' : ''}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: corStatusFundo(v.status), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    '${v.status == 'critico' ? '🔴' : v.status == 'alerta' ? '🟡' : '🟢'} ${labelStatus[v.status] ?? v.status}',
                    style: TextStyle(fontSize: 11, color: corStatusTexto(v.status), fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 4),
                Text('${v.scoreGeral}/100', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const Text('score geral', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            _indicador('Km atual', v.kmAtual > 0 ? '${_milhar(v.kmAtual.round())} km' : '—'),
            _indicador('Consumo atual', v.consumoAtual != null ? '${v.consumoAtual!.toStringAsFixed(2)} km/L' : '—'),
            _indicador('Degradação de consumo', v.degradacao != null && v.degradacao! > 0 ? '${(v.degradacao! * 100).round()}%' : '—'),
            _indicador('Centro de custo', v.centroCustoNome ?? '—'),
          ],
        ),
        const SizedBox(height: 16),

        if (v.recomendacoes.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡 Recomendações', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  ...v.recomendacoes.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(r, style: const TextStyle(fontSize: 13)),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Detalhamento por componente', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: v.componentes.map(_componenteCard).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📝 Registrar Manutenção Realizada', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                const Text('Registre manutenções realizadas para melhorar a precisão da análise preditiva.',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 12),
                _formRegistrar(v),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📋 Histórico de Manutenções', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                historicoAsync.when(
                  data: (registros) => _historico(registros),
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
                  error: (e, _) => Text('Erro: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _milhar(int v) => v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

  Widget _indicador(String label, String valor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _componenteCard(ComponenteResultado c) {
    final cor = corBarraScore(c.score.toDouble());
    final fundo = corStatusFundo(c.urgencia);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(8), border: Border.all(color: corStatusTexto(c.urgencia).withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('${c.componenteIcone} ${c.componenteLabel}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              ),
              Text('${c.score}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cor)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (c.score.clamp(0, 100)) / 100,
              minHeight: 6,
              backgroundColor: Colors.white70,
              valueColor: AlwaysStoppedAnimation(cor),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(c.urgencia == 'critico' ? 'Vencido' : '~${_milhar(c.kmNext.round())} km', style: const TextStyle(fontSize: 10)),
              Text(c.fonte == 'real' ? '✅ registro real' : '📐 estimado', style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _formRegistrar(VeiculoDetalheManutencao v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_erroForm != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
            child: Text(_erroForm!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
          ),
        if (_sucessoForm)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
            child: const Text('Manutenção registrada com sucesso.', style: TextStyle(color: Color(0xFF047857), fontSize: 12)),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _dataCtrl,
                readOnly: true,
                onTap: _selecionarData,
                decoration: const InputDecoration(labelText: 'Data *', border: OutlineInputBorder(), isDense: true, suffixIcon: Icon(Icons.calendar_today, size: 16)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _hodometroCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Hodômetro (km)', border: OutlineInputBorder(), isDense: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _custoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Custo total (R\$)', border: OutlineInputBorder(), isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _tecnicoCtrl,
                decoration: const InputDecoration(labelText: 'Técnico', border: OutlineInputBorder(), isDense: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _oficinaCtrl,
          decoration: const InputDecoration(labelText: 'Oficina', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 14),
        const Text('Itens realizados *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        StatefulBuilder(
          builder: (ctx, setStateLocal) => Wrap(
            spacing: 6,
            runSpacing: 6,
            children: itensManutencao.map((item) {
              final sel = _itensSelecionados.contains(item);
              return FilterChip(
                label: Text(item, style: const TextStyle(fontSize: 11)),
                selected: sel,
                onSelected: (v2) => setStateLocal(() => v2 ? _itensSelecionados.add(item) : _itensSelecionados.remove(item)),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _obsCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Observações',
            hintText: 'Condições, peças substituídas, pendências...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _salvando ? null : _registrar,
            child: Text(_salvando ? 'Registrando...' : 'Registrar Manutenção'),
          ),
        ),
      ],
    );
  }

  Widget _historico(List<RegistroManutencao> registros) {
    if (registros.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('Nenhuma manutenção registrada ainda.', style: TextStyle(color: Colors.grey, fontSize: 12))),
      );
    }
    return Column(
      children: registros.map((r) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(r.dataManutencao ?? '—', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  Row(
                    children: [
                      if (r.custoTotal != null) Text('R\$ ${r.custoTotal!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _excluir(r.id),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${r.hodometro != null ? '${_milhar(r.hodometro!.round())} km · ' : ''}${r.oficina ?? '—'}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              if (r.itensRealizados.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(r.itensRealizados.join(', '), style: const TextStyle(fontSize: 11)),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
