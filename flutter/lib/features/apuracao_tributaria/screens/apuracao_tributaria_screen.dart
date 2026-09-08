import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../services/apuracao_tributaria_service.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _data = DateFormat('dd/MM/yyyy');

// Evita DateFormat('MMMM', 'pt_BR') — exigiria initializeDateFormatting()
// no boot do app, que não é chamado em nenhum outro lugar deste projeto
// (NumberFormat.currency funciona sem isso, mas nomes de mês por extenso
// não). Lista fixa em vez disso.
const _nomesMeses = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];
String _formatarMesAno(DateTime d) => '${_nomesMeses[d.month - 1]}/${d.year}';

// Fase FLT-Apuração-Tributária (02/09/2026) — porta de
// apuracao-tributaria/page.tsx + FormularioRegimeTributario.tsx. Sem botão
// de "reprocessar notas antigas" (ligado ao Storage de XML, fora de
// escopo do v1 mobile) — a lista de notas sem dado ainda é exibida, só
// sem a ação de reprocesso.
class ApuracaoTributariaScreen extends ConsumerStatefulWidget {
  const ApuracaoTributariaScreen({super.key});

  @override
  ConsumerState<ApuracaoTributariaScreen> createState() =>
      _ApuracaoTributariaScreenState();
}

class _ApuracaoTributariaScreenState
    extends ConsumerState<ApuracaoTributariaScreen> {
  final _service = ApuracaoTributariaService();
  Future<DadosFiscaisEmpresa>? _futuroDados;
  Future<List<NotaFiscalTributaria>>? _futuroNotas;
  DateTime _periodo = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    final empresaId = ref.read(sessaoProvider).valueOrNull?.empresaId;
    if (empresaId == null) {
      setState(() {
        _futuroDados = null;
        _futuroNotas = Future.value(const []);
      });
      return;
    }
    final inicio = DateTime(_periodo.year, _periodo.month);
    final fimExclusivo = DateTime(_periodo.year, _periodo.month + 1);
    setState(() {
      _futuroDados = _service.buscarDadosFiscais(empresaId);
      _futuroNotas = _service.buscarNotasDoPeriodo(
          empresaId: empresaId, inicio: inicio, fimExclusivo: fimExclusivo);
    });
  }

  Future<void> _selecionarMes() async {
    final escolhido = await showDatePicker(
      context: context,
      initialDate: _periodo,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Selecione um dia do mês desejado',
    );
    if (escolhido == null) return;
    setState(() => _periodo = DateTime(escolhido.year, escolhido.month));
    _carregar();
  }

  Future<void> _editarRegime(DadosFiscaisEmpresa dados) async {
    final empresaId = ref.read(sessaoProvider).valueOrNull?.empresaId;
    if (empresaId == null) return;
    var regime = dados.regimeTributario ?? 'normal';
    var elegivel = dados.elegivelCreditoIcmsCombustivel ?? false;

    final salvar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Regime tributário'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RadioListTile<String>(
                  value: 'normal',
                  groupValue: regime,
                  title: const Text('Regime normal (RPA / Lucro Presumido ou Real)'),
                  onChanged: (v) => setDialogState(() => regime = v!),
                ),
                RadioListTile<String>(
                  value: 'simples_nacional',
                  groupValue: regime,
                  title: const Text('Simples Nacional'),
                  onChanged: (v) => setDialogState(() => regime = v!),
                ),
                const Divider(),
                CheckboxListTile(
                  value: elegivel,
                  title: const Text(
                      'Minha empresa presta serviço de transporte tributado por ICMS (ou isento com manutenção de crédito) e não é optante pelo regime de crédito outorgado.'),
                  onChanged: (v) => setDialogState(() => elegivel = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Salvar')),
          ],
        ),
      ),
    );
    if (salvar != true) return;
    final erro = await _service.atualizarRegimeTributario(
        empresaId: empresaId, regimeTributario: regime, elegivel: elegivel);
    if (!mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    } else {
      _carregar();
    }
  }

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
          title: const Text('Apuração de Crédito Tributário')),
      body: RefreshIndicator(
        onRefresh: () async => _carregar(),
        child: _futuroDados == null
            ? const Center(
                child: Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: CircularProgressIndicator()))
            : FutureBuilder<DadosFiscaisEmpresa>(
                future: _futuroDados,
                builder: (context, snapD) {
                  if (!snapD.hasData &&
                      snapD.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: CircularProgressIndicator()),
                    );
                  }
                  if (snapD.hasError) {
                    return ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text('Não deu pra carregar: ${snapD.error}',
                            textAlign: TextAlign.center)
                      ],
                    );
                  }
                  final dados = snapD.data!;
                  if (dados.segmento == 'Revenda') {
                    return ListView(
                      padding: const EdgeInsets.all(24),
                      children: const [
                        Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                                'A apuração de crédito tributário é uma funcionalidade do lado do cliente (transportadora), não do posto.'),
                          ),
                        ),
                      ],
                    );
                  }

                  return FutureBuilder<List<NotaFiscalTributaria>>(
                    future: _futuroNotas,
                    builder: (context, snapN) {
                      if (!snapN.hasData &&
                          snapN.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                              padding: EdgeInsets.only(top: 80),
                              child: CircularProgressIndicator()),
                        );
                      }
                      final notas = snapN.data ?? const [];
                      final comCredito =
                          notas.where((n) => n.vIcmsMonoRet != null).toList();
                      final semDado = notas.length - comCredito.length;
                      final totalCredito = comCredito.fold<double>(
                          0, (s, n) => s + (n.vIcmsMonoRet ?? 0));
                      final ufs = comCredito
                          .map((n) => n.ufEmitente)
                          .whereType<String>()
                          .toSet();

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        children: [
                          Card(
                            child: ListTile(
                              title: const Text('Regime tributário'),
                              subtitle: Text(dados.regimeTributario == null
                                  ? 'Não configurado'
                                  : (dados.regimeTributario == 'normal'
                                          ? 'Regime normal'
                                          : 'Simples Nacional') +
                                      (dados.elegivelCreditoIcmsCombustivel ==
                                              true
                                          ? ' · elegível ao crédito'
                                          : dados.elegivelCreditoIcmsCombustivel ==
                                                  false
                                              ? ' · não elegível'
                                              : '')),
                              trailing: TextButton(
                                onPressed: () => _editarRegime(dados),
                                child: const Text('Editar'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (dados.cadastroIncompleto)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Text(
                                  'Preencha o regime tributário e a elegibilidade acima para saber se sua empresa pode tomar o crédito de ICMS.',
                                  style: TextStyle(fontSize: 13)),
                            )
                          else if (!dados.podeCreditar)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                  dados.regimeTributario == 'simples_nacional'
                                      ? 'Simples Nacional não tem direito a crédito de ICMS sobre combustível — os valores abaixo são só informativos.'
                                      : 'Sua empresa não é elegível ao crédito (não presta transporte tributado por ICMS, ou é optante por crédito outorgado) — valores abaixo são só informativos.',
                                  style: const TextStyle(
                                      fontSize: 13, color: Color(0xFFB91C1C))),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _selecionarMes,
                                  icon: const Icon(Icons.calendar_month, size: 18),
                                  label: Text(_formatarMesAno(_periodo)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          GridView.count(
                            crossAxisCount: Responsive.colunasGrade(context, mobile: 3, desktop: 4),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 1.1,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            children: [
                              _indicador(
                                  dados.podeCreditar
                                      ? 'Crédito apurável no mês'
                                      : 'Valor identificado (informativo)',
                                  _moeda.format(totalCredito)),
                              _indicador('Notas com dado de crédito',
                                  '${comCredito.length} de ${notas.length}'),
                              _indicador('Notas sem grupo ICMS61', '$semDado',
                                  destaque: semDado > 0),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (ufs.length > 1) ...[
                            const Text('Por UF do posto emitente',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold)),
                            Text(
                                '(aproximação — usa a UF do posto emitente, não a UF de início do transporte)',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade600)),
                            const SizedBox(height: 8),
                            ...ufs.map((uf) {
                              final total = comCredito
                                  .where((n) => n.ufEmitente == uf)
                                  .fold<double>(
                                      0, (s, n) => s + (n.vIcmsMonoRet ?? 0));
                              return Card(
                                child: ListTile(
                                  title: Text(uf),
                                  trailing: Text(_moeda.format(total)),
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                          ],
                          const Text('Notas do período',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (notas.isEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Center(
                                  child: Text(
                                      'Nenhuma nota fiscal de abastecimento neste período.',
                                      style: TextStyle(color: Colors.grey.shade600)),
                                ),
                              ),
                            )
                          else
                            ...notas.map(_cardNota),
                          const SizedBox(height: 16),
                          Text(
                              'Base legal: LC 192/2022 e Convênio ICMS 26/2023. Consulte seu contador antes de tomar o crédito — os valores acima são calculados a partir do que o posto informou na NF-e.',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  Widget _cardNota(NotaFiscalTributaria n) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('NF ${n.numeroNf} · ${n.nomeEmitente}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text(_data.format(DateTime.parse(n.dataEmissao)),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
              const SizedBox(height: 4),
              Text(n.produtoDescricaoAnp ?? n.produtoNomeXml ?? '—',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text('${n.quantidade.toStringAsFixed(2)} L',
                      style: const TextStyle(fontSize: 12)),
                  Text('Valor: ${_moeda.format(n.valorTotal)}',
                      style: const TextStyle(fontSize: 12)),
                  Text(
                      'Crédito: ${n.vIcmsMonoRet != null ? _moeda.format(n.vIcmsMonoRet) : 'sem dado'}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: n.vIcmsMonoRet != null
                              ? const Color(0xFF15803D)
                              : Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _indicador(String label, String valor, {bool destaque = false}) =>
      Card(
        color: destaque ? const Color(0xFFFEF3C7) : null,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(valor,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}
