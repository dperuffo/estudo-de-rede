import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../services/abastecimentos_cliente_service.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _numero = NumberFormat.decimalPattern('pt_BR');
final _dataHoraBr = DateFormat('dd/MM/yyyy HH:mm');

String _fmtDataHora(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    return _dataHoraBr.format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

// Fase FLT-Aprovação-Manual (02/09/2026, pedido do Daniel: "equalizar o PWA
// Cliente com as funcionalidades construídas para a web cliente") — porta de
// abastecimentos/pendentes-aprovacao/page.tsx + AcaoAprovacaoManual.tsx.
// Prioridade sobre a importação em massa por planilha (também mapeada no
// gap, mas é fluxo de escritório/desktop — pouco valor no celular). Esta
// tela, ao contrário, encaixa bem no mobile: cada card já traz a foto do
// cupom (a mesma que o motorista tirou no PWA Motorista) ao lado dos campos
// extraídos por OCR, e aprovar/rejeitar é 1 ou 2 toques.
//
// Sem o seletor de "Cliente" que a web tem quando o usuário enxerga várias
// empresas sem ter escolhido nenhuma — aqui sempre usa a empresa já
// resolvida pela sessão (`sessaoProvider`, mesmo padrão de
// AbastecimentosScreen); ver README/comentário em sessao_provider.dart.
class AbastecimentosPendentesAprovacaoScreen extends ConsumerStatefulWidget {
  const AbastecimentosPendentesAprovacaoScreen({super.key});

  @override
  ConsumerState<AbastecimentosPendentesAprovacaoScreen> createState() =>
      _AbastecimentosPendentesAprovacaoScreenState();
}

class _AbastecimentosPendentesAprovacaoScreenState
    extends ConsumerState<AbastecimentosPendentesAprovacaoScreen> {
  final _service = AbastecimentosClienteService();
  Future<List<AbastecimentoManualPendente>>? _futuro;
  final Set<int> _processando = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    final empresaId = ref.read(sessaoProvider).valueOrNull?.empresaId;
    if (empresaId == null) {
      setState(() => _futuro = Future.value(const []));
      return;
    }
    setState(() {
      _futuro = _service.buscarPendentesManuais(empresaId: empresaId);
    });
  }

  Future<void> _aprovar(AbastecimentoManualPendente p) async {
    setState(() => _processando.add(p.id));
    final erro = await _service.aprovarRejeitarManual(id: p.id, aprovar: true);
    if (!mounted) return;
    setState(() => _processando.remove(p.id));
    if (erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Abastecimento aprovado.')),
    );
    _carregar();
  }

  Future<void> _rejeitar(AbastecimentoManualPendente p) async {
    final motivoCtrl = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejeitar lançamento'),
        content: TextField(
          controller: motivoCtrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo da rejeição',
            hintText: 'Ex.: valor não confere com o cupom',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, motivoCtrl.text.trim()),
            child: const Text('Rejeitar'),
          ),
        ],
      ),
    );
    motivoCtrl.dispose();
    if (motivo == null) return;
    if (!mounted) return;
    if (motivo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o motivo da rejeição.')),
      );
      return;
    }
    setState(() => _processando.add(p.id));
    final erro = await _service.aprovarRejeitarManual(
      id: p.id,
      aprovar: false,
      motivoRejeicao: motivo,
    );
    if (!mounted) return;
    setState(() => _processando.remove(p.id));
    if (erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lançamento rejeitado.')),
    );
    _carregar();
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
          title: const Text('Pendentes de aprovação')),
      body: RefreshIndicator(
        onRefresh: () async => _carregar(),
        child: FutureBuilder<List<AbastecimentoManualPendente>>(
          future: _futuro,
          builder: (context, snap) {
            if (!snap.hasData &&
                snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text('Não deu pra carregar: ${snap.error}',
                      textAlign: TextAlign.center)
                ],
              );
            }
            final pendentes = snap.data ?? const [];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  'Lançamentos feitos pelo motorista no aplicativo a partir da foto do cupom fiscal — '
                  'só entram nos indicadores e no financeiro depois de aprovados aqui.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 16),
                if (pendentes.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'Nenhum lançamento manual pendente de aprovação no momento.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    ),
                  )
                else
                  ...pendentes.map((p) => _card(p)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _card(AbastecimentoManualPendente p) {
    final processando = _processando.contains(p.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: p.fotoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: p.fotoUrl!,
                          width: 80,
                          height: 104,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _semFoto(),
                        )
                      : _semFoto(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${p.placa} · ${p.motoristaNome ?? "Motorista não identificado"}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(_fmtDataHora(p.dataAbastecimento),
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 6),
                      Text(
                        '${p.combustivel ?? "—"} · ${_numero.format(p.quantidade)} L'
                        '${p.valorUnitario != null ? " · ${_moeda.format(p.valorUnitario)}/L" : ""}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(_moeda.format(p.valorTotal),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(p.postoNome ?? 'Posto não identificado',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                      if (p.hodometro != null)
                        Text(
                            'Hodômetro: ${_numero.format(p.hodometro!.round())} km',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (processando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                    child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _rejeitar(p),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700),
                      child: const Text('Rejeitar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _aprovar(p),
                      child: const Text('Aprovar'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _semFoto() => Container(
        width: 80,
        height: 104,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300)),
        child: Text('Sem\nfoto',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      );
}
