import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/estoque_pecas_provider.dart';
import '../services/estoque_pecas_service.dart';

import '../../../core/theme/app_theme.dart';

// Fase Grupo 1 Rodopar item 2 (03/08/2026) — detalhe da peça, porta de
// estoque-pecas/[id]/page.tsx + EstoquePecasAcoes.tsx: situação do estoque,
// histórico de movimentos (ledger) e form de registrar entrada/saída com
// vínculo opcional à OS de manutenção.
class PecaDetalheScreen extends ConsumerStatefulWidget {
  final String id;
  const PecaDetalheScreen({super.key, required this.id});

  @override
  ConsumerState<PecaDetalheScreen> createState() => _PecaDetalheScreenState();
}

class _PecaDetalheScreenState extends ConsumerState<PecaDetalheScreen> {
  bool _processando = false;
  String? _erro;

  String _fmtMoeda(double? v) {
    if (v == null) return '—';
    return 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _fmtDataHora(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final local = d.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _registrarMovimento({
    required String pecaId,
    required String empresaId,
    required String tipoMovimento,
    required double quantidade,
    double? custoUnitario,
    String? placa,
    int? manutencaoId,
    String? motivo,
  }) async {
    setState(() {
      _erro = null;
      _processando = true;
    });
    try {
      final sessao = await ref.read(sessaoProvider.future);
      await EstoquePecasService().registrarMovimento(
        pecaId: pecaId,
        empresaId: empresaId,
        tipoMovimento: tipoMovimento,
        quantidade: quantidade,
        custoUnitario: custoUnitario,
        placa: placa,
        manutencaoId: manutencaoId,
        motivo: motivo,
        criadoPor: sessao.email,
      );
      ref.invalidate(pecaEstoqueDetalheProvider(pecaId));
      ref.invalidate(movimentosEstoqueProvider(pecaId));
      ref.invalidate(pecasEstoqueListProvider);
    } catch (e) {
      setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _alternarAtiva(String pecaId, bool ativaAtual) async {
    final mensagem = ativaAtual
        ? 'Desativar esta peça? Ela deixa de aparecer no cadastro ativo (o histórico é mantido).'
        : 'Reativar esta peça?';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ativaAtual ? 'Desativar peça?' : 'Reativar peça?'),
        content: Text(mensagem),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ativaAtual ? 'Desativar' : 'Reativar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _processando = true);
    try {
      await EstoquePecasService().alterarAtiva(pecaId, !ativaAtual);
      ref.invalidate(pecaEstoqueDetalheProvider(pecaId));
      ref.invalidate(pecasEstoqueListProvider);
    } catch (e) {
      setState(() => _erro = 'Não foi possível atualizar: $e');
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pecaAsync = ref.watch(pecaEstoqueDetalheProvider(widget.id));

    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Peça')),
      body: pecaAsync.when(
        data: (p) {
          if (p == null)
            return const Center(child: Text('Peça não encontrada.'));
          return _conteudo(p);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
      ),
    );
  }

  Widget _conteudo(PecaEstoque p) {
    final movimentosAsync = ref.watch(movimentosEstoqueProvider(p.id));
    final manutencoesAsync = ref.watch(manutencoesRecentesProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_erro != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8)),
            child: Text(_erro!,
                style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                p.nome + (p.codigo != null ? ' · ${p.codigo}' : ''),
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            if (!p.ativa)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12)),
                child: const Text('Inativa',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Situação do estoque',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _campoEstoque('Saldo atual',
                        '${p.quantidadeAtual} ${p.unidadeMedida}',
                        destaque: p.abaixoDoMinimo),
                    _campoEstoque(
                        'Mínimo', '${p.quantidadeMinima} ${p.unidadeMedida}'),
                    _campoEstoque(
                        'Custo médio', _fmtMoeda(p.custoUnitarioMedio)),
                  ],
                ),
                if (p.abaixoDoMinimo) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text(
                        'Saldo abaixo (ou igual) ao estoque mínimo definido. Considere repor.',
                        style:
                            TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
                  ),
                ],
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed:
                      _processando ? null : () => _alternarAtiva(p.id, p.ativa),
                  icon: Icon(p.ativa ? Icons.block : Icons.check_circle_outline,
                      size: 18, color: p.ativa ? Colors.red : Colors.green),
                  label: Text(p.ativa ? 'Desativar peça' : 'Reativar peça',
                      style: TextStyle(
                          color: p.ativa ? Colors.red : Colors.green)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Registrar movimento',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                manutencoesAsync.when(
                  data: (manutencoes) => _FormMovimento(
                    processando: _processando,
                    manutencoes: manutencoes,
                    onRegistrar:
                        (tipo, qtd, custo, placa, manutencaoId, motivo) =>
                            _registrarMovimento(
                      pecaId: p.id,
                      empresaId: p.empresaId,
                      tipoMovimento: tipo,
                      quantidade: qtd,
                      custoUnitario: custo,
                      placa: placa,
                      manutencaoId: manutencaoId,
                      motivo: motivo,
                    ),
                  ),
                  loading: () => _FormMovimento(
                    processando: _processando,
                    manutencoes: const [],
                    onRegistrar:
                        (tipo, qtd, custo, placa, manutencaoId, motivo) =>
                            _registrarMovimento(
                      pecaId: p.id,
                      empresaId: p.empresaId,
                      tipoMovimento: tipo,
                      quantidade: qtd,
                      custoUnitario: custo,
                      placa: placa,
                      manutencaoId: manutencaoId,
                      motivo: motivo,
                    ),
                  ),
                  error: (_, __) => _FormMovimento(
                    processando: _processando,
                    manutencoes: const [],
                    onRegistrar:
                        (tipo, qtd, custo, placa, manutencaoId, motivo) =>
                            _registrarMovimento(
                      pecaId: p.id,
                      empresaId: p.empresaId,
                      tipoMovimento: tipo,
                      quantidade: qtd,
                      custoUnitario: custo,
                      placa: placa,
                      manutencaoId: manutencaoId,
                      motivo: motivo,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Histórico de movimentos',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                movimentosAsync.when(
                  data: (lista) {
                    if (lista.isEmpty) {
                      return const Text('Nenhum movimento registrado ainda.',
                          style: TextStyle(fontSize: 12, color: Colors.grey));
                    }
                    return Column(
                      children: lista
                          .map((m) => _linhaMovimento(m, p.unidadeMedida))
                          .toList(),
                    );
                  },
                  loading: () => const Center(
                      child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator())),
                  error: (e, _) => Text('Erro: $e',
                      style: const TextStyle(fontSize: 12, color: Colors.red)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _campoEstoque(String label, String valor, {bool destaque = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.4)),
          const SizedBox(height: 2),
          Text(valor,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: destaque ? const Color(0xFFB91C1C) : Colors.black87)),
        ],
      ),
    );
  }

  Widget _linhaMovimento(MovimentoEstoque m, String unidade) {
    final sinal = m.tipoMovimento == 'saida' ? '-' : '+';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: tipoMovimentoCorFundo[m.tipoMovimento] ??
                    const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12)),
            child: Text(
              tipoMovimentoLabel[m.tipoMovimento] ?? m.tipoMovimento,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: tipoMovimentoCorTexto[m.tipoMovimento] ??
                      Colors.grey.shade700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$sinal${m.quantidade} $unidade${m.custoUnitario != null ? ' (${_fmtMoeda(m.custoUnitario)}/un)' : ''}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  [
                    _fmtDataHora(m.criadoEm),
                    if (m.placa != null) m.placa!,
                    if (m.manutencaoId != null) 'OS #${m.manutencaoId}',
                    if (m.motivo != null) m.motivo!,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormMovimento extends StatefulWidget {
  final bool processando;
  final List<ManutencaoResumo> manutencoes;
  final Future<void> Function(String tipo, double quantidade, double? custo,
      String? placa, int? manutencaoId, String? motivo) onRegistrar;
  const _FormMovimento(
      {required this.processando,
      required this.manutencoes,
      required this.onRegistrar});

  @override
  State<_FormMovimento> createState() => _FormMovimentoState();
}

class _FormMovimentoState extends State<_FormMovimento> {
  String _tipo = 'saida';
  final _quantidadeCtrl = TextEditingController();
  final _custoCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();
  int? _manutencaoId;
  final _motivoCtrl = TextEditingController();
  String? _erroLocal;

  @override
  void dispose() {
    _quantidadeCtrl.dispose();
    _custoCtrl.dispose();
    _placaCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() => _erroLocal = null);
    final quantidade =
        double.tryParse(_quantidadeCtrl.text.replaceAll(',', '.'));
    if (quantidade == null || quantidade <= 0) {
      setState(() => _erroLocal = 'Informe uma quantidade válida.');
      return;
    }
    await widget.onRegistrar(
      _tipo,
      quantidade,
      _tipo == 'entrada'
          ? double.tryParse(_custoCtrl.text.replaceAll(',', '.'))
          : null,
      _placaCtrl.text.trim().isEmpty
          ? null
          : _placaCtrl.text.trim().toUpperCase(),
      _manutencaoId,
      _motivoCtrl.text.trim().isEmpty ? null : _motivoCtrl.text.trim(),
    );
    _quantidadeCtrl.clear();
    _custoCtrl.clear();
    _placaCtrl.clear();
    _motivoCtrl.clear();
    setState(() => _manutencaoId = null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_erroLocal != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_erroLocal!,
                style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _tipo = 'saida'),
                style: OutlinedButton.styleFrom(
                  backgroundColor:
                      _tipo == 'saida' ? const Color(0xFFFEF2F2) : null,
                  side: BorderSide(
                      color: _tipo == 'saida'
                          ? const Color(0xFFFCA5A5)
                          : Colors.grey.shade300),
                ),
                child: Text('Saída (uso)',
                    style: TextStyle(
                        color: _tipo == 'saida'
                            ? const Color(0xFFB91C1C)
                            : Colors.grey.shade700)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _tipo = 'entrada'),
                style: OutlinedButton.styleFrom(
                  backgroundColor:
                      _tipo == 'entrada' ? const Color(0xFFDCFCE7) : null,
                  side: BorderSide(
                      color: _tipo == 'entrada'
                          ? const Color(0xFF86EFAC)
                          : Colors.grey.shade300),
                ),
                child: Text('Entrada (compra)',
                    style: TextStyle(
                        color: _tipo == 'entrada'
                            ? const Color(0xFF166534)
                            : Colors.grey.shade700)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _quantidadeCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
              labelText: 'Quantidade',
              border: OutlineInputBorder(),
              isDense: true),
        ),
        if (_tipo == 'entrada') ...[
          const SizedBox(height: 10),
          TextField(
            controller: _custoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Custo unitário (R\$)',
                hintText: 'opcional',
                border: OutlineInputBorder(),
                isDense: true),
          ),
        ],
        if (_tipo == 'saida') ...[
          const SizedBox(height: 10),
          TextField(
            controller: _placaCtrl,
            decoration: const InputDecoration(
                labelText: 'Placa (veículo)',
                hintText: 'ABC1D23',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int?>(
            value: _manutencaoId,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Vincular à OS (opcional)',
                border: OutlineInputBorder(),
                isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('Nenhuma')),
              for (final m in widget.manutencoes)
                DropdownMenuItem(
                  value: m.id,
                  child: Text(
                      '#${m.id} — ${m.placa} — ${m.dataManutencao}${m.tipo != null ? ' (${m.tipo})' : ''}',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _manutencaoId = v),
          ),
          const SizedBox(height: 4),
          const Text(
              'Vincular a uma OS mostra o consumo real de peças na manutenção — impede baixa sem justificativa.',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _motivoCtrl,
          decoration: const InputDecoration(
              labelText: 'Motivo / observação',
              hintText: 'Opcional',
              border: OutlineInputBorder(),
              isDense: true),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: widget.processando ? null : _enviar,
            child: Text(
                widget.processando ? 'Salvando...' : 'Registrar Movimento'),
          ),
        ),
      ],
    );
  }
}
