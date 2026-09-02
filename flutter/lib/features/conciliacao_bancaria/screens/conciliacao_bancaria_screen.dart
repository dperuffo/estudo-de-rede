import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../services/conciliacao_bancaria_service.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _data = DateFormat('dd/MM/yyyy');

// Fase FLT-Conciliação-Bancária (02/09/2026) — porta de
// conciliacao-bancaria/page.tsx + FormImportarExtrato + AcoesLancamentoExtrato
// + AcaoConciliarAutomatico. Import via file_picker (.ofx/.csv), sugestões
// calculadas em memória (mesmo algoritmo da web) e conciliação em bottom
// sheet (lista de sugestões, com opção de conciliar manualmente contra a
// conta indicada).
class ConciliacaoBancariaScreen extends ConsumerStatefulWidget {
  const ConciliacaoBancariaScreen({super.key});

  @override
  ConsumerState<ConciliacaoBancariaScreen> createState() =>
      _ConciliacaoBancariaScreenState();
}

class _ConciliacaoBancariaScreenState
    extends ConsumerState<ConciliacaoBancariaScreen> {
  final _service = ConciliacaoBancariaService();
  Future<List<LancamentoExtrato>>? _futuroLancamentos;
  Future<List<ContaEmAberto>>? _futuroContas;
  bool _importando = false;
  bool _conciliandoLote = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    final empresaId = ref.read(sessaoProvider).valueOrNull?.empresaId;
    if (empresaId == null) {
      setState(() {
        _futuroLancamentos = Future.value(const []);
        _futuroContas = Future.value(const []);
      });
      return;
    }
    setState(() {
      _futuroLancamentos = _service.buscarLancamentos(empresaId);
      _futuroContas = _service.buscarContasEmAberto(empresaId);
    });
  }

  void _mostrarMensagem(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _importar() async {
    final empresaId = ref.read(sessaoProvider).valueOrNull?.empresaId;
    if (empresaId == null) return;
    final resultado = await FilePicker.pickFiles(
        withData: true, type: FileType.custom, allowedExtensions: ['ofx', 'csv']);
    if (resultado == null || resultado.files.isEmpty) return;
    final arquivo = resultado.files.first;
    if (arquivo.bytes == null) return;
    final conteudo = utf8.decode(arquivo.bytes!, allowMalformed: true);

    setState(() => _importando = true);
    final r = await _service.importar(
        empresaId: empresaId, nomeArquivo: arquivo.name, conteudo: conteudo);
    if (!mounted) return;
    setState(() => _importando = false);
    if (r.erro != null) {
      _mostrarMensagem(r.erro!);
    } else {
      _mostrarMensagem(
          '${r.novos} lançamento(s) novo(s) importado(s)${r.duplicados > 0 ? ', ${r.duplicados} já existiam' : ''}.');
      _carregar();
    }
  }

  Future<void> _conciliarLote() async {
    final empresaId = ref.read(sessaoProvider).valueOrNull?.empresaId;
    if (empresaId == null) return;
    setState(() => _conciliandoLote = true);
    final r = await _service.conciliarAutomatico(empresaId);
    if (!mounted) return;
    setState(() => _conciliandoLote = false);
    _mostrarMensagem(
        '${r.conciliados} lançamento(s) conciliado(s) automaticamente${r.erros > 0 ? ' (${r.erros} com erro)' : ''}.');
    _carregar();
  }

  Future<void> _abrirSugestoes(
      LancamentoExtrato lancamento, List<SugestaoConta> sugestoes) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lancamento.descricao,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                  '${_data.format(DateTime.parse(lancamento.data))} · ${_moeda.format(lancamento.valor)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(height: 12),
              if (sugestoes.isEmpty)
                const Text('Nenhuma sugestão encontrada para este lançamento.')
              else
                ...sugestoes.map((s) => Card(
                      child: ListTile(
                        title: Text(s.conta.nome.isEmpty
                            ? s.conta.descricao
                            : s.conta.nome),
                        subtitle: Text(
                            '${s.conta.tipo == 'contas_pagar' ? 'A pagar' : 'A receber'} · vence ${_data.format(DateTime.parse(s.conta.vencimento))} · saldo ${_moeda.format(s.conta.saldoEmAberto)}'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: _corConfianca(s.confianca),
                              borderRadius: BorderRadius.circular(12)),
                          child: Text(_labelConfianca(s.confianca),
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final erro = await _service.conciliarManual(
                            lancamentoId: lancamento.id,
                            contaTipo: s.conta.tipo,
                            contaId: s.conta.id,
                            valorLancamento: lancamento.valor,
                            saldoConta: s.conta.saldoEmAberto,
                          );
                          if (!mounted) return;
                          if (erro != null) {
                            _mostrarMensagem(erro);
                          } else {
                            _carregar();
                          }
                        },
                      ),
                    )),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final erro = await _service.ignorar(lancamento.id);
                      if (!mounted) return;
                      if (erro != null) {
                        _mostrarMensagem(erro);
                      } else {
                        _carregar();
                      }
                    },
                    child: const Text('Ignorar lançamento'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _corConfianca(String c) => switch (c) {
        'alta' => const Color(0xFFDCFCE7),
        'media' => const Color(0xFFFEF3C7),
        _ => const Color(0xFFF3F4F6),
      };

  String _labelConfianca(String c) => switch (c) {
        'alta' => 'Alta confiança',
        'media' => 'Média confiança',
        _ => 'Baixa confiança',
      };

  @override
  Widget build(BuildContext context) {
    ref.listen(sessaoProvider, (prev, next) {
      final idAnterior = prev?.valueOrNull?.empresaId;
      final idAtual = next.valueOrNull?.empresaId;
      if (idAtual != null && idAtual != idAnterior) _carregar();
    });
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Conciliação Bancária')),
      body: RefreshIndicator(
        onRefresh: () async => _carregar(),
        child: FutureBuilder<List<LancamentoExtrato>>(
          future: _futuroLancamentos,
          builder: (context, snapL) {
            if (!snapL.hasData &&
                snapL.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: CircularProgressIndicator()),
              );
            }
            if (snapL.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text('Não deu pra carregar: ${snapL.error}',
                      textAlign: TextAlign.center)
                ],
              );
            }
            final lancamentos = snapL.data ?? const [];
            final pendentes =
                lancamentos.where((l) => l.status == 'pendente').toList();
            final conciliados =
                lancamentos.where((l) => l.status == 'conciliado').toList();
            final valorPendente =
                pendentes.fold<double>(0, (s, l) => s + l.valor.abs());

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _importando ? null : _importar,
                        icon: _importando
                            ? const SizedBox(
                                height: 14,
                                width: 14,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.upload_file, size: 18),
                        label: const Text('Importar extrato'),
                      ),
                    ),
                  ],
                ),
                Text('Aceita arquivos .ofx ou .csv do seu banco.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: [
                    _indicador('Pendentes', '${pendentes.length}'),
                    _indicador('Valor pendente', _moeda.format(valorPendente)),
                    _indicador('Conciliados', '${conciliados.length}'),
                  ],
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<ContaEmAberto>>(
                  future: _futuroContas,
                  builder: (context, snapC) {
                    final contasLista = snapC.data ?? const [];
                    final quantidadeAltaConfianca = pendentes.where((l) {
                      final sugestoes = _service.sugerirContas(l, contasLista);
                      return sugestoes.where((s) => s.confianca == 'alta').length ==
                          1;
                    }).length;
                    if (quantidadeAltaConfianca == 0) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FilledButton.icon(
                        onPressed: _conciliandoLote ? null : _conciliarLote,
                        icon: _conciliandoLote
                            ? const SizedBox(
                                height: 14,
                                width: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.bolt, size: 18),
                        label: Text(
                            'Conciliar automaticamente ($quantidadeAltaConfianca de alta confiança)'),
                      ),
                    );
                  },
                ),
                const Text('Pendentes',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (pendentes.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text('Nenhum lançamento pendente.',
                            style: TextStyle(color: Colors.grey.shade600)),
                      ),
                    ),
                  )
                else
                  FutureBuilder<List<ContaEmAberto>>(
                    future: _futuroContas,
                    builder: (context, snapC) {
                      final contasLista = snapC.data ?? const [];
                      return Column(
                        children: pendentes
                            .map((l) => _cardPendente(l,
                                _service.sugerirContas(l, contasLista)))
                            .toList(),
                      );
                    },
                  ),
                if (conciliados.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text('Histórico',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...conciliados.take(30).map(_cardConciliado),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _cardPendente(
      LancamentoExtrato l, List<SugestaoConta> sugestoes) {
    final altas = sugestoes.where((s) => s.confianca == 'alta').length;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _abrirSugestoes(l, sugestoes),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(l.descricao,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text(_moeda.format(l.valor),
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: l.tipo == 'debito'
                              ? const Color(0xFFB91C1C)
                              : const Color(0xFF15803D))),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(_data.format(DateTime.parse(l.data)),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const Spacer(),
                  if (sugestoes.isNotEmpty)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: altas > 0
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(
                          '${sugestoes.length} sugestão(ões)',
                          style: const TextStyle(fontSize: 11)),
                    )
                  else
                    Text('Sem sugestão',
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardConciliado(LancamentoExtrato l) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(l.descricao, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
              '${_data.format(DateTime.parse(l.data))} · ${l.conciliadoPor ?? ''}'),
          trailing: Text(_moeda.format(l.valor),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          onTap: () async {
            final confirmado = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Reabrir lançamento'),
                content: const Text(
                    'Voltar este lançamento para pendente? Isso não desfaz a baixa já feita na conta.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Reabrir')),
                ],
              ),
            );
            if (confirmado != true) return;
            final erro = await _service.reabrir(l.id);
            if (!mounted) return;
            if (erro != null) {
              _mostrarMensagem(erro);
            } else {
              _carregar();
            }
          },
        ),
      );

  Widget _indicador(String label, String valor) => Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(valor,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}
