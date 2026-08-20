import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sessao_provider.dart';
import '../../motoristas/providers/motoristas_provider.dart';
import '../providers/multas_provider.dart';
import '../services/multas_service.dart';

import '../../../core/theme/app_theme.dart';

// Fase Onda-2 (benchmark TicketLog, item #4) — detalhe da multa, porta de
// multas/[id]/page.tsx + MultaAcoes.tsx: indicação de condutor (com
// sugestão via vínculo Motorista<->Veículo), status e histórico do
// veículo.
class MultaDetalheScreen extends ConsumerStatefulWidget {
  final String id;
  const MultaDetalheScreen({super.key, required this.id});

  @override
  ConsumerState<MultaDetalheScreen> createState() => _MultaDetalheScreenState();
}

class _MultaDetalheScreenState extends ConsumerState<MultaDetalheScreen> {
  bool _processando = false;
  String? _erro;
  String? _anexoUrl;
  bool _carregandoAnexo = false;

  String _fmtData(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _fmtMoeda(double? v) {
    if (v == null) return '—';
    return 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Future<void> _carregarAnexo(String? caminho) async {
    if (caminho == null || _anexoUrl != null || _carregandoAnexo) return;
    setState(() => _carregandoAnexo = true);
    final url = await MultasService().urlAssinadaAnexo(caminho);
    if (!mounted) return;
    setState(() {
      _anexoUrl = url;
      _carregandoAnexo = false;
    });
  }

  Future<void> _indicarCondutor(String motoristaId) async {
    setState(() {
      _erro = null;
      _processando = true;
    });
    try {
      final sessao = await ref.read(sessaoProvider.future);
      await MultasService()
          .indicarCondutor(widget.id, motoristaId, sessao.email);
      ref.invalidate(multaDetalheProvider(widget.id));
    } catch (e) {
      setState(() => _erro = 'Não foi possível indicar o condutor: $e');
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _mudarStatus(String novoStatus) async {
    setState(() {
      _erro = null;
      _processando = true;
    });
    try {
      await MultasService().atualizarStatus(widget.id, novoStatus);
      ref.invalidate(multaDetalheProvider(widget.id));
    } catch (e) {
      setState(() => _erro = 'Não foi possível atualizar o status: $e');
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _excluir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir multa?'),
        content: const Text('Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;
    await MultasService().excluir(widget.id);
    if (!mounted) return;
    ref.invalidate(multasListProvider);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final multaAsync = ref.watch(multaDetalheProvider(widget.id));

    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Detalhe da Multa')),
      body: multaAsync.when(
        data: (m) {
          if (m == null)
            return const Center(child: Text('Multa não encontrada.'));
          if (m.anexoPath != null) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _carregarAnexo(m.anexoPath));
          }
          return _conteudo(m);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
      ),
    );
  }

  Widget _conteudo(Multa m) {
    final AsyncValue<String?> sugestaoAsync = m.motoristaId == null
        ? ref.watch(sugestaoCondutorProvider(
            (placa: m.placa, dataInfracao: m.dataInfracao)))
        : const AsyncValue.data(null);
    final motoristasAsync = ref.watch(motoristasClienteProvider);
    final historicoAsync = ref.watch(
        historicoMultasVeiculoProvider((placa: m.placa, excluirId: m.id)));

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
                'Multa — ${m.placa}${m.numeroAit != null ? ' · AIT ${m.numeroAit}' : ''}',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color:
                      statusMultaCorFundo[m.status] ?? const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(statusMultaLabel[m.status] ?? m.status,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusMultaCorTexto[m.status] ??
                          Colors.grey.shade700)),
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
                const Text('Dados da infração',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                _campo('Data da infração', _fmtData(m.dataInfracao)),
                _campo('Prazo p/ indicação/desconto',
                    _fmtData(m.dataLimiteIndicacao)),
                _campo('Órgão autuador', m.orgaoAutuador ?? '—'),
                _campo('Local', m.localInfracao ?? '—'),
                _campo('Descrição', m.descricao ?? '—'),
                _campo(
                    'Gravidade',
                    m.gravidade != null
                        ? (gravidadeMultaLabel[m.gravidade] ?? m.gravidade!)
                        : '—'),
                _campo('Pontos na CNH', m.pontos != null ? '${m.pontos}' : '—'),
                _campo('Valor original', _fmtMoeda(m.valorOriginal)),
                _campo('Valor com desconto', _fmtMoeda(m.valorDesconto)),
                _campo('Observações', m.observacoes ?? '—'),
                if (m.anexoPath != null) ...[
                  const SizedBox(height: 8),
                  if (_carregandoAnexo)
                    const Text('Carregando anexo...',
                        style: TextStyle(fontSize: 12, color: Colors.grey))
                  else if (_anexoUrl != null)
                    InkWell(
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => Dialog(
                            child: InteractiveViewer(
                                child: Image.network(_anexoUrl!,
                                    errorBuilder: (_, __, ___) => const Padding(
                                        padding: EdgeInsets.all(20),
                                        child: Text(
                                            'Não foi possível exibir o anexo (pode ser um PDF).'))))),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.attach_file, size: 16, color: Colors.blue),
                          SizedBox(width: 4),
                          Text('Ver anexo da notificação',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
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
                const Text('Alterar status',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (m.status != 'paga')
                      OutlinedButton(
                          onPressed:
                              _processando ? null : () => _mudarStatus('paga'),
                          child: const Text('Marcar como Paga')),
                    if (m.status != 'recorrida')
                      OutlinedButton(
                          onPressed: _processando
                              ? null
                              : () => _mudarStatus('recorrida'),
                          child: const Text('Marcar como Recorrida')),
                    if (m.status != 'cancelada')
                      OutlinedButton(
                          onPressed: _processando
                              ? null
                              : () => _mudarStatus('cancelada'),
                          child: const Text('Cancelar')),
                  ],
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _processando ? null : _excluir,
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.red),
                  label: const Text('Excluir multa',
                      style: TextStyle(color: Colors.red)),
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
                const Text('Condutor infrator',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                if (m.motoristaId != null && m.motoristaNome != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.motoristaNome!,
                          style: const TextStyle(fontSize: 13)),
                      if (m.indicadoEm != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Indicado em ${_fmtData(m.indicadoEm)}${m.indicadoPor != null ? ' por ${m.indicadoPor}' : ''}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ),
                    ],
                  )
                else
                  motoristasAsync.when(
                    data: (motoristas) => sugestaoAsync.when(
                      data: (sugeridoId) =>
                          _formIndicarCondutor(motoristas, sugeridoId),
                      loading: () => _formIndicarCondutor(motoristas, null),
                      error: (_, __) => _formIndicarCondutor(motoristas, null),
                    ),
                    loading: () => const Center(
                        child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator())),
                    error: (e, _) => Text('Erro ao carregar motoristas: $e',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.red)),
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
                Text('Histórico do veículo (${m.placa})',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                historicoAsync.when(
                  data: (lista) {
                    if (lista.isEmpty) {
                      return const Text(
                          'Nenhuma outra multa registrada para esse veículo.',
                          style: TextStyle(fontSize: 12, color: Colors.grey));
                    }
                    return Column(
                      children: lista
                          .map((h) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(_fmtData(h.dataInfracao),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    h.descricao ??
                                        statusMultaLabel[h.status] ??
                                        h.status,
                                    style: const TextStyle(fontSize: 12)),
                                onTap: () => context.push('/multas/${h.id}'),
                              ))
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

  Widget _formIndicarCondutor(List<Motorista> motoristas, String? sugeridoId) {
    return _FormIndicarCondutor(
      motoristas: motoristas,
      sugeridoId: sugeridoId,
      processando: _processando,
      onIndicar: _indicarCondutor,
    );
  }

  Widget _campo(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
          Text(valor, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _FormIndicarCondutor extends StatefulWidget {
  final List<Motorista> motoristas;
  final String? sugeridoId;
  final bool processando;
  final Future<void> Function(String motoristaId) onIndicar;
  const _FormIndicarCondutor(
      {required this.motoristas,
      required this.sugeridoId,
      required this.processando,
      required this.onIndicar});

  @override
  State<_FormIndicarCondutor> createState() => _FormIndicarCondutorState();
}

class _FormIndicarCondutorState extends State<_FormIndicarCondutor> {
  String? _selecionado;

  @override
  void initState() {
    super.initState();
    _selecionado = widget.sugeridoId;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.sugeridoId != null)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Sugestão pré-selecionada com base no vínculo Motorista ↔ Veículo ativo na data da infração.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        DropdownButtonFormField<String>(
          value: _selecionado,
          decoration: const InputDecoration(
              labelText: 'Selecione o condutor...',
              border: OutlineInputBorder(),
              isDense: true),
          items: widget.motoristas
              .map((m) => DropdownMenuItem(
                  value: m.id,
                  child: Text(m.nomeCompleto, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) => setState(() => _selecionado = v),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: widget.processando || _selecionado == null
              ? null
              : () => widget.onIndicar(_selecionado!),
          child: Text(widget.processando ? 'Salvando...' : 'Indicar Condutor'),
        ),
      ],
    );
  }
}
