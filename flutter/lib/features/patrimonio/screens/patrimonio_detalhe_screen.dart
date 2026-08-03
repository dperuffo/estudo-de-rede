import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../providers/patrimonio_provider.dart';
import '../services/patrimonio_service.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _dataBr = DateFormat('dd/MM/yyyy');

const Map<String, String> _tipoAjusteLabel = {
  'reavaliacao': 'Reavaliação',
  'melhoria': 'Melhoria (capitalização)',
  'baixa': 'Baixa (venda/perda total)',
};

// Fase Grupo 2 (Rodopar/Datapar, item 6, 03/08/2026) — detalhe do veículo,
// porta de patrimonio/[placa]/page.tsx.
class PatrimonioDetalheScreen extends ConsumerStatefulWidget {
  final String placa;
  const PatrimonioDetalheScreen({super.key, required this.placa});

  @override
  ConsumerState<PatrimonioDetalheScreen> createState() => _PatrimonioDetalheScreenState();
}

class _PatrimonioDetalheScreenState extends ConsumerState<PatrimonioDetalheScreen> {
  bool _processando = false;
  String? _erro;

  Future<void> _registrarAjuste(String empresaId, String veiculoId, String tipo, double valor, String dataAjuste, String? motivo) async {
    setState(() {
      _erro = null;
      _processando = true;
    });
    try {
      await PatrimonioService().criarAjuste(
        empresaId: empresaId,
        veiculoId: veiculoId,
        tipo: tipo,
        valor: valor,
        dataAjuste: dataAjuste,
        motivo: motivo,
        criadoPor: SupabaseService.client.auth.currentUser?.id,
      );
      ref.invalidate(ajustesPatrimonioProvider(veiculoId));
      ref.invalidate(patrimonioVeiculoProvider(widget.placa));
    } catch (e) {
      setState(() => _erro = 'Não foi possível registrar: $e');
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _excluirAjuste(String ajusteId, String veiculoId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir ajuste?'),
        content: const Text('Este ajuste do patrimônio será removido.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _processando = true);
    try {
      await PatrimonioService().excluirAjuste(ajusteId);
      ref.invalidate(ajustesPatrimonioProvider(veiculoId));
      ref.invalidate(patrimonioVeiculoProvider(widget.placa));
    } catch (e) {
      setState(() => _erro = 'Não foi possível excluir: $e');
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detalheAsync = ref.watch(patrimonioVeiculoProvider(widget.placa));
    return Scaffold(
      appBar: AppBar(title: Text(widget.placa)),
      body: detalheAsync.when(
        data: (v) {
          if (v == null) return const Center(child: Text('Veículo não encontrado.'));
          return _conteudo(v);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
      ),
    );
  }

  Widget _conteudo(VeiculoPatrimonio v) {
    final sessaoAsync = ref.watch(sessaoProvider);
    final veiculoIdAsync = ref.watch(patrimonioVeiculoIdProvider(widget.placa));

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
                    '${v.centroCustoNome ?? 'Sem centro de custo'}${v.anoFabricacao != null ? ' · ${v.anoFabricacao}' : ''}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  v.valorContabilLiquido != null ? _moeda.format(v.valorContabilLiquido!) : '—',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                Text(
                  v.baixado
                      ? 'Baixado em ${v.dataBaixa != null ? _dataBr.format(DateTime.parse(v.dataBaixa!)) : '—'}'
                      : v.percentualDepreciado != null
                          ? '${v.percentualDepreciado}% depreciado'
                          : '',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (!v.patrimonioCompleto)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFDE68A))),
            child: const Text(
              '⚠️ Este veículo não tem valor de aquisição cadastrado — não é possível calcular a depreciação '
              'contábil. Complete o cadastro em Veículos pra ver o patrimônio completo.',
              style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Resumo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                _linhaDado('Valor de aquisição', v.valorAquisicao != null ? _moeda.format(v.valorAquisicao!) : '—'),
                _linhaDado('Data de aquisição', v.dataAquisicao != null ? _dataBr.format(DateTime.parse(v.dataAquisicao!)) : '—'),
                _linhaDado('Vida útil', '${v.vidaUtilAnos.toStringAsFixed(0)} ano(s) (${v.mesesVidaUtil} meses)'),
                _linhaDado('Idade', v.mesesDecorridos != null ? '${v.mesesDecorridos} mês(es)' : '—'),
                _linhaDado('Valor residual estimado', v.valorResidualEstimado != null ? _moeda.format(v.valorResidualEstimado!) : '—'),
                _linhaDado('Melhorias capitalizadas', _moeda.format(v.valorMelhorias)),
                _linhaDado('Reavaliações acumuladas', _moeda.format(v.valorReavaliacoes)),
                _linhaDado('Depreciação acumulada', v.depreciacaoAcumulada != null ? _moeda.format(v.depreciacaoAcumulada!) : '—'),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => context.push('/veiculos'),
                  child: const Text('Editar valor de aquisição, data e vida útil em Veículos →', style: TextStyle(fontSize: 12)),
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
                const Text('Correções do ativo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                const Text(
                  'Reavaliação (ajusta o valor contábil pra cima/baixo), melhoria (capitalização que aumenta a '
                  'base depreciável, ex.: baú novo) ou baixa (venda, perda total, sinistro — encerra a '
                  'depreciação na data informada).',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                if (_erro != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_erro!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
                  ),
                sessaoAsync.when(
                  data: (sessao) => veiculoIdAsync.when(
                    data: (veiculoId) {
                      final empresaId = sessao.empresaId;
                      if (empresaId == null || veiculoId == null) return const SizedBox();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ref.watch(ajustesPatrimonioProvider(veiculoId)).when(
                                data: (lista) {
                                  if (lista.isEmpty) {
                                    return const Padding(
                                      padding: EdgeInsets.only(bottom: 10),
                                      child: Text('Nenhum ajuste registrado ainda.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    );
                                  }
                                  return Column(children: lista.map((a) => _linhaAjuste(a, veiculoId)).toList());
                                },
                                loading: () => const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator())),
                                error: (e, _) => Text('Erro: $e', style: const TextStyle(fontSize: 12, color: Colors.red)),
                              ),
                          const Divider(),
                          const SizedBox(height: 4),
                          _FormAjuste(
                            processando: _processando,
                            onRegistrar: (tipo, valor, dataAjuste, motivo) => _registrarAjuste(empresaId, veiculoId, tipo, valor, dataAjuste, motivo),
                          ),
                        ],
                      );
                    },
                    loading: () => const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
                    error: (e, _) => Text('Erro: $e', style: const TextStyle(fontSize: 12, color: Colors.red)),
                  ),
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
                  error: (e, _) => Text('Erro: $e', style: const TextStyle(fontSize: 12, color: Colors.red)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _linhaDado(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Text(valor, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _linhaAjuste(AjustePatrimonio a, String veiculoId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_tipoAjusteLabel[a.tipo] ?? a.tipo} · ${_moeda.format(a.valor)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                Text(_dataBr.format(DateTime.parse(a.dataAjuste)), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (a.motivo != null) ...[
                  const SizedBox(height: 4),
                  Text(a.motivo!, style: const TextStyle(fontSize: 11)),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: _processando ? null : () => _excluirAjuste(a.id, veiculoId),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
            child: const Text('Excluir', style: TextStyle(fontSize: 11, color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _FormAjuste extends StatefulWidget {
  final bool processando;
  final Future<void> Function(String tipo, double valor, String dataAjuste, String? motivo) onRegistrar;
  const _FormAjuste({required this.processando, required this.onRegistrar});

  @override
  State<_FormAjuste> createState() => _FormAjusteState();
}

class _FormAjusteState extends State<_FormAjuste> {
  String? _tipo;
  final _valorCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  DateTime? _data;
  String? _erroLocal;

  @override
  void dispose() {
    _valorCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final agora = DateTime.now();
    final escolhida = await showDatePicker(context: context, initialDate: _data ?? agora, firstDate: DateTime(2000), lastDate: agora.add(const Duration(days: 1)));
    if (escolhida != null) setState(() => _data = escolhida);
  }

  Future<void> _enviar() async {
    setState(() => _erroLocal = null);
    if (_tipo == null) {
      setState(() => _erroLocal = 'Escolha o tipo de ajuste.');
      return;
    }
    final valor = double.tryParse(_valorCtrl.text.trim().replaceAll(',', '.'));
    if (valor == null) {
      setState(() => _erroLocal = 'Informe um valor válido.');
      return;
    }
    if (_data == null) {
      setState(() => _erroLocal = 'Informe a data do ajuste.');
      return;
    }
    final dataIso = '${_data!.year.toString().padLeft(4, '0')}-${_data!.month.toString().padLeft(2, '0')}-${_data!.day.toString().padLeft(2, '0')}';
    await widget.onRegistrar(_tipo!, valor, dataIso, _motivoCtrl.text.trim().isEmpty ? null : _motivoCtrl.text.trim());
    _valorCtrl.clear();
    _motivoCtrl.clear();
    setState(() {
      _tipo = null;
      _data = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_erroLocal != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_erroLocal!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
          ),
        DropdownButtonFormField<String>(
          value: _tipo,
          decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder(), isDense: true),
          items: _tipoAjusteLabel.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: (v) => setState(() => _tipo = v),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _valorCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Valor (R\$)', border: OutlineInputBorder(), isDense: true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: _selecionarData,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Data', border: OutlineInputBorder(), isDense: true, suffixIcon: Icon(Icons.calendar_today, size: 16)),
                  child: Text(_data == null ? 'Selecionar' : _dataBr.format(_data!), style: const TextStyle(fontSize: 12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _motivoCtrl,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Motivo (opcional)', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: widget.processando ? null : _enviar,
          child: Text(widget.processando ? 'Registrando...' : 'Registrar ajuste'),
        ),
      ],
    );
  }
}
