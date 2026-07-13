import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/financeiro_posto_provider.dart';
import '../services/financeiro_posto_service.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

const _corMeioPagamento = <String, Color>{
  'profrotas': Color(0xFFDBEAFE),
  'Valecard': Color(0xFFEDE9FE),
  'RedeFrota': Color(0xFFFFEDD5),
  'TicketLog': Color(0xFFCCFBF1),
  'Veloe': Color(0xFFFCE7F3),
};

String _nomeProvedor(String p) => p == 'profrotas' ? 'PróFrotas' : p;

String _dataBr(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// Fase FLT-2 — porta reduzida de financeiro-posto/page.tsx (ver escopo
// completo no comentário de financeiro_posto_provider.dart).
class FinanceiroPostoScreen extends ConsumerStatefulWidget {
  const FinanceiroPostoScreen({super.key});

  @override
  ConsumerState<FinanceiroPostoScreen> createState() => _FinanceiroPostoScreenState();
}

class _FinanceiroPostoScreenState extends ConsumerState<FinanceiroPostoScreen> {
  PeriodoFinanceiro _periodo = PeriodoFinanceiro.quinzeDias;
  bool _formularioAberto = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(financeiroPostoProvider(_periodo));
    final sessaoAsync = ref.watch(sessaoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Financeiro')),
      floatingActionButton: sessaoAsync.maybeWhen(
        data: (sessao) => sessao.empresaId == null
            ? null
            : FloatingActionButton.extended(
                onPressed: () => setState(() => _formularioAberto = !_formularioAberto),
                icon: Icon(_formularioAberto ? Icons.close : Icons.add),
                label: Text(_formularioAberto ? 'Fechar' : 'Lançar despesa'),
              ),
        orElse: () => null,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (dados) {
          if (dados == null) return const Center(child: Text('Nenhuma empresa selecionada.'));
          final empresaPostoId = sessaoAsync.value?.empresaId;
          return _buildConteudo(context, dados, empresaPostoId);
        },
      ),
    );
  }

  Widget _buildConteudo(BuildContext context, FinanceiroPostoDetalhe dados, String? empresaPostoId) {
    final hojeIso = DateTime.now().toIso8601String().substring(0, 10);
    final janela = resolverPeriodo(_periodo);
    final janelaPrevista = resolverJanelaPrevista(_periodo, janela.inicio, janela.fim, hojeIso);

    final aReceberAberto = dados.faturas.where((f) => f.status == 'aberta').fold<double>(0, (s, f) => s + f.valorTotal) +
        dados.cicloAbertoValorTotal;
    final vencido = dados.faturas
        .where((f) => f.status == 'aberta' && f.vencimento.compareTo(hojeIso) < 0)
        .fold<double>(0, (s, f) => s + f.valorTotal);
    final recebidoNoPeriodo = dados.faturas
        .where((f) =>
            f.status == 'paga' &&
            f.pagoEm != null &&
            f.pagoEm!.substring(0, 10).compareTo(janela.inicio) >= 0 &&
            f.pagoEm!.substring(0, 10).compareTo(janela.fim) <= 0)
        .fold<double>(0, (s, f) => s + f.valorTotal);
    final aPagarAberto = dados.despesas.where((d) => d.status == 'aberta').fold<double>(0, (s, d) => s + d.valor);
    final pagoNoPeriodo = dados.despesas
        .where((d) =>
            d.status == 'paga' &&
            d.pagoEm != null &&
            d.pagoEm!.substring(0, 10).compareTo(janela.inicio) >= 0 &&
            d.pagoEm!.substring(0, 10).compareTo(janela.fim) <= 0)
        .fold<double>(0, (s, d) => s + d.valor);
    final aReceberVencendo = dados.faturas
        .where((f) =>
            f.status == 'aberta' &&
            f.vencimento.compareTo(janelaPrevista.inicio) >= 0 &&
            f.vencimento.compareTo(janelaPrevista.fim) <= 0)
        .fold<double>(0, (s, f) => s + f.valorTotal);
    final aPagarVencendo = dados.despesas
        .where((d) =>
            d.status == 'aberta' &&
            d.vencimento.compareTo(janelaPrevista.inicio) >= 0 &&
            d.vencimento.compareTo(janelaPrevista.fim) <= 0)
        .fold<double>(0, (s, d) => s + d.valor);
    final saldoPrevisto = aReceberVencendo - aPagarVencendo;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        const Text('Contas a receber (faturas dos clientes) e contas a pagar (despesas do posto).',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: PeriodoFinanceiro.values
              .map((p) => ChoiceChip(
                    label: Text(periodoFinanceiroLabel[p]!),
                    selected: _periodo == p,
                    onSelected: (_) => setState(() => _periodo = p),
                  ))
              .toList(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Período: ${_dataBr(janela.inicio)} – ${_dataBr(janela.fim)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.9,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _indicador('A receber (aberto)', _moeda.format(aReceberAberto)),
            _indicador('Vencido', _moeda.format(vencido), cor: const Color(0xFFDC2626)),
            _indicador('Recebido no período', _moeda.format(recebidoNoPeriodo), cor: const Color(0xFF16A34A)),
            _indicador('A pagar (aberto)', _moeda.format(aPagarAberto)),
            _indicador('Pago no período', _moeda.format(pagoNoPeriodo), cor: const Color(0xFF16A34A)),
            _indicador('Saldo previsto', _moeda.format(saldoPrevisto),
                cor: saldoPrevisto < 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
          ],
        ),
        if (dados.indicadoresPorProvedor.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Consolidado por meio de pagamento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('Abastecimentos que você forneceu no período, por meio de pagamento usado pelo cliente.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 10),
          ...dados.indicadoresPorProvedor.map((p) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _corMeioPagamento[p.provedor] ?? const Color(0xFFF1F5F9),
                    child: Text(_nomeProvedor(p.provedor).substring(0, 1),
                        style: const TextStyle(color: Colors.black87, fontSize: 13)),
                  ),
                  title: Text(_nomeProvedor(p.provedor)),
                  subtitle: Text('${p.qtdAbastecimentos} abastecimento(s) · ${p.litros.toStringAsFixed(0)} L'),
                  trailing: Text(_moeda.format(p.valorTotal), style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              )),
        ],
        const SizedBox(height: 20),
        if (_formularioAberto && empresaPostoId != null) ...[
          _FormularioDespesa(
            empresaPostoId: empresaPostoId,
            onSalvo: () {
              setState(() => _formularioAberto = false);
              ref.invalidate(financeiroPostoProvider(_periodo));
            },
          ),
          const SizedBox(height: 20),
        ],
        const Text('Contas a pagar (despesas do posto)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
        if (dados.despesas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Nenhuma despesa lançada ainda.', style: TextStyle(color: Colors.grey)),
          )
        else
          ...dados.despesas.map((d) => _linhaDespesa(d)),
      ],
    );
  }

  Widget _linhaDespesa(DespesaFinanceiro d) {
    final hojeIso = DateTime.now().toIso8601String().substring(0, 10);
    final vencida = d.status == 'aberta' && d.vencimento.compareTo(hojeIso) < 0;
    final statusLabel = d.status == 'paga' ? 'Paga' : (vencida ? 'Vencida' : 'Em aberto');
    final statusCor = d.status == 'paga'
        ? const Color(0xFF16A34A)
        : (vencida ? const Color(0xFFDC2626) : const Color(0xFF64748B));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(tipoDespesaPostoLabel[d.tipo] ?? d.tipo,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                Text(_moeda.format(d.valor), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            if (d.descricao != null && d.descricao!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(d.descricao!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('Vence ${_dataBr(d.vencimento)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusCor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(statusLabel, style: TextStyle(fontSize: 11, color: statusCor, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            if (d.status == 'aberta') ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () async {
                      final erro = await FinanceiroPostoService().marcarDespesaPaga(d.id);
                      if (!mounted) return;
                      if (erro != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
                      } else {
                        ref.invalidate(financeiroPostoProvider(_periodo));
                      }
                    },
                    child: const Text('Marcar como paga'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final erro = await FinanceiroPostoService().excluirDespesa(d.id);
                      if (!mounted) return;
                      if (erro != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
                      } else {
                        ref.invalidate(financeiroPostoProvider(_periodo));
                      }
                    },
                    child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _indicador(String label, String valor, {Color? cor}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(valor,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cor),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// Formulário "Lançar despesa" — mesmos campos de LancarDespesaForm (web),
// menos o campo de anexo/comprovante (fora do escopo desta versão).
class _FormularioDespesa extends StatefulWidget {
  final String empresaPostoId;
  final VoidCallback onSalvo;
  const _FormularioDespesa({required this.empresaPostoId, required this.onSalvo});

  @override
  State<_FormularioDespesa> createState() => _FormularioDespesaState();
}

class _FormularioDespesaState extends State<_FormularioDespesa> {
  String? _tipo;
  final _valorCtrl = TextEditingController();
  final _competenciaCtrl = TextEditingController();
  final _vencimentoCtrl = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  bool _recorrente = false;
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _valorCtrl.dispose();
    _competenciaCtrl.dispose();
    _vencimentoCtrl.dispose();
    _descricaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _selecionarData(TextEditingController controller) async {
    final atual = DateTime.tryParse(controller.text) ?? DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (escolhida != null) {
      setState(() => controller.text = DateFormat('yyyy-MM-dd').format(escolhida));
    }
  }

  Future<void> _salvar() async {
    final valor = double.tryParse(_valorCtrl.text.trim().replaceAll(',', '.'));
    if (_tipo == null) {
      setState(() => _erro = 'Selecione o tipo.');
      return;
    }
    if (valor == null || valor <= 0) {
      setState(() => _erro = 'Valor inválido.');
      return;
    }
    if (_competenciaCtrl.text.trim().isEmpty) {
      setState(() => _erro = 'Informe a competência.');
      return;
    }
    if (_vencimentoCtrl.text.trim().isEmpty) {
      setState(() => _erro = 'Informe o vencimento.');
      return;
    }

    setState(() {
      _salvando = true;
      _erro = null;
    });

    final erro = await FinanceiroPostoService().lancarDespesa(
      empresaPostoId: widget.empresaPostoId,
      tipo: _tipo!,
      valor: valor,
      competencia: _competenciaCtrl.text.trim(),
      vencimento: _vencimentoCtrl.text.trim(),
      descricao: _descricaoCtrl.text,
      recorrente: _recorrente,
    );

    if (!mounted) return;
    if (erro != null) {
      setState(() {
        _salvando = false;
        _erro = erro;
      });
      return;
    }
    widget.onSalvo();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lançar despesa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
              items: tiposDespesaPosto
                  .map((t) => DropdownMenuItem(value: t, child: Text(tipoDespesaPostoLabel[t] ?? t)))
                  .toList(),
              onChanged: (v) => setState(() => _tipo = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _valorCtrl,
              decoration: const InputDecoration(labelText: 'Valor (R\$)', border: OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _competenciaCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Competência (mês da despesa)',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: () => _selecionarData(_competenciaCtrl),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _vencimentoCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Vencimento',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: () => _selecionarData(_vencimentoCtrl),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descricaoCtrl,
              decoration: const InputDecoration(labelText: 'Descrição (opcional)', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 6),
            CheckboxListTile(
              value: _recorrente,
              onChanged: (v) => setState(() => _recorrente = v ?? false),
              title: const Text('Despesa recorrente (todo mês)'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_erro!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                child: Text(_salvando ? 'Salvando...' : 'Salvar despesa'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
