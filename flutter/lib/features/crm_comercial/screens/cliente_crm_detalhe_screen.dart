import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/crm_provider.dart';
import '../services/crm_service.dart';

import '../../../core/theme/app_theme.dart';

// Fase Grupo 2 (Rodopar/Datapar, item 5, 03/08/2026) — detalhe do cliente:
// funil de propostas (read-only, lê cotacoes já existente) + histórico de
// relacionamento (registrar/excluir interações), porta de
// crm-comercial/clientes/[id]/page.tsx.
class ClienteCrmDetalheScreen extends ConsumerStatefulWidget {
  final String id;
  const ClienteCrmDetalheScreen({super.key, required this.id});

  @override
  ConsumerState<ClienteCrmDetalheScreen> createState() =>
      _ClienteCrmDetalheScreenState();
}

class _ClienteCrmDetalheScreenState
    extends ConsumerState<ClienteCrmDetalheScreen> {
  bool _processando = false;
  String? _erro;

  String _fmtMoeda(double v) =>
      'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  String _fmtData(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final local = d.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  String _fmtDataHora(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final local = d.toLocal();
    return '${_fmtData(iso)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _fmtCnpjCpf(String v) {
    final d = v.replaceAll(RegExp(r'\D'), '');
    if (d.length == 14)
      return d.replaceAllMapped(RegExp(r'(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})'),
          (m) => '${m[1]}.${m[2]}.${m[3]}/${m[4]}-${m[5]}');
    if (d.length == 11)
      return d.replaceAllMapped(RegExp(r'(\d{3})(\d{3})(\d{3})(\d{2})'),
          (m) => '${m[1]}.${m[2]}.${m[3]}-${m[4]}');
    return v;
  }

  Future<void> _registrarInteracao(String empresaId, String tipo,
      String descricao, String? proximaAcaoData) async {
    setState(() {
      _erro = null;
      _processando = true;
    });
    try {
      final sessao = await ref.read(sessaoProvider.future);
      await CrmService().criarInteracao(
        empresaId: empresaId,
        clienteId: widget.id,
        tipo: tipo,
        descricao: descricao,
        proximaAcaoData: proximaAcaoData,
        criadoPor: sessao.email,
      );
      ref.invalidate(interacoesClienteProvider(widget.id));
    } catch (e) {
      setState(() => _erro = 'Não foi possível registrar: $e');
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _excluirInteracao(String interacaoId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir interação?'),
        content: const Text('Este registro de histórico será removido.'),
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
    setState(() => _processando = true);
    try {
      await CrmService().excluirInteracao(interacaoId);
      ref.invalidate(interacoesClienteProvider(widget.id));
    } catch (e) {
      setState(() => _erro = 'Não foi possível excluir: $e');
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clienteAsync = ref.watch(clienteCrmDetalheProvider(widget.id));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
            decoration:
                const BoxDecoration(gradient: AppTheme.glassNavGradient)),
        foregroundColor: AppTheme.glassTexto,
        iconTheme: const IconThemeData(color: AppTheme.glassIcone),
        title: const Text('Cliente'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/crm-comercial/${widget.id}/editar'),
          ),
        ],
      ),
      body: clienteAsync.when(
        data: (c) {
          if (c == null)
            return const Center(child: Text('Cliente não encontrado.'));
          return _conteudo(c);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
      ),
    );
  }

  Widget _conteudo(ClienteCrm c) {
    final cotacoesAsync = ref.watch(cotacoesClienteProvider(c.id));
    final interacoesAsync = ref.watch(interacoesClienteProvider(c.id));

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
        Text(c.razaoSocial,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 2),
        Text(_fmtCnpjCpf(c.cnpjCpf),
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Funil de propostas',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                cotacoesAsync.when(
                  data: (lista) {
                    final aberto = lista
                        .where((c) => c.status == 'simulada')
                        .fold<double>(0, (s, c) => s + c.valorTotal);
                    final ganho = lista
                        .where((c) => c.status == 'convertida')
                        .fold<double>(0, (s, c) => s + c.valorTotal);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _campoResumo('Em aberto', _fmtMoeda(aberto)),
                            _campoResumo('Ganho', _fmtMoeda(ganho),
                                destaque: true),
                            _campoResumo('Propostas', '${lista.length}'),
                          ],
                        ),
                        if (lista.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: Text('Nenhuma proposta ainda.',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          )
                        else ...[
                          const SizedBox(height: 10),
                          ...lista.map(_linhaCotacao),
                        ],
                      ],
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
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Registrar interação',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                _FormInteracao(
                  processando: _processando,
                  onRegistrar: (tipo, descricao, proximaAcao) =>
                      _registrarInteracao(
                          c.empresaId, tipo, descricao, proximaAcao),
                ),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 6),
                const Text('Histórico de relacionamento',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                interacoesAsync.when(
                  data: (lista) {
                    if (lista.isEmpty) {
                      return const Text('Nenhuma interação registrada ainda.',
                          style: TextStyle(fontSize: 12, color: Colors.grey));
                    }
                    return Column(
                        children: lista.map(_linhaInteracao).toList());
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

  Widget _campoResumo(String label, String valor, {bool destaque = false}) {
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
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: destaque ? const Color(0xFF166534) : Colors.black87)),
        ],
      ),
    );
  }

  Widget _linhaCotacao(CotacaoResumo cot) {
    final cor = cot.status == 'convertida'
        ? const Color(0xFF166534)
        : cot.status == 'descartada'
            ? Colors.grey.shade600
            : Colors.blue.shade700;
    final fundo = cot.status == 'convertida'
        ? const Color(0xFFDCFCE7)
        : cot.status == 'descartada'
            ? Colors.grey.shade200
            : const Color(0xFFDBEAFE);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${cot.origemLabel} → ${cot.destinoLabel}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                Text('${_fmtMoeda(cot.valorTotal)} · ${_fmtData(cot.criadoEm)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: fundo, borderRadius: BorderRadius.circular(12)),
            child: Text(statusPropostaLabel[cot.status] ?? cot.status,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: cor)),
          ),
        ],
      ),
    );
  }

  Widget _linhaInteracao(InteracaoCrm i) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tipoInteracaoLabel[i.tipo] ?? i.tipo,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12)),
              Text(_fmtDataHora(i.criadoEm),
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 4),
          Text(i.descricao, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  [
                    if (i.criadoPor != null) i.criadoPor!,
                    if (i.proximaAcaoData != null)
                      'Próxima ação: ${_fmtData(i.proximaAcaoData!)}',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: _processando ? null : () => _excluirInteracao(i.id),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                child: const Text('Excluir',
                    style: TextStyle(fontSize: 11, color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormInteracao extends StatefulWidget {
  final bool processando;
  final Future<void> Function(
      String tipo, String descricao, String? proximaAcaoData) onRegistrar;
  const _FormInteracao({required this.processando, required this.onRegistrar});

  @override
  State<_FormInteracao> createState() => _FormInteracaoState();
}

class _FormInteracaoState extends State<_FormInteracao> {
  String? _tipo;
  final _descricaoCtrl = TextEditingController();
  DateTime? _proximaAcao;
  String? _erroLocal;

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final agora = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _proximaAcao ?? agora,
      firstDate: agora.subtract(const Duration(days: 1)),
      lastDate: agora.add(const Duration(days: 365)),
    );
    if (escolhida != null) setState(() => _proximaAcao = escolhida);
  }

  Future<void> _enviar() async {
    setState(() => _erroLocal = null);
    if (_tipo == null) {
      setState(() => _erroLocal = 'Escolha o tipo de interação.');
      return;
    }
    if (_descricaoCtrl.text.trim().isEmpty) {
      setState(() => _erroLocal = 'Descreva o que foi conversado/combinado.');
      return;
    }
    final proximaAcaoIso = _proximaAcao == null
        ? null
        : '${_proximaAcao!.year.toString().padLeft(4, '0')}-${_proximaAcao!.month.toString().padLeft(2, '0')}-${_proximaAcao!.day.toString().padLeft(2, '0')}';
    await widget.onRegistrar(
        _tipo!, _descricaoCtrl.text.trim(), proximaAcaoIso);
    _descricaoCtrl.clear();
    setState(() {
      _tipo = null;
      _proximaAcao = null;
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
            child: Text(_erroLocal!,
                style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
          ),
        DropdownButtonFormField<String>(
          value: _tipo,
          decoration: const InputDecoration(
              labelText: 'Tipo', border: OutlineInputBorder(), isDense: true),
          items: tipoInteracaoLabel.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => setState(() => _tipo = v),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _descricaoCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
              labelText: 'O que foi conversado/combinado',
              border: OutlineInputBorder(),
              isDense: true),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: _selecionarData,
          child: InputDecorator(
            decoration: const InputDecoration(
                labelText: 'Próxima ação (opcional)',
                border: OutlineInputBorder(),
                isDense: true,
                suffixIcon: Icon(Icons.calendar_today, size: 16)),
            child: Text(
              _proximaAcao == null
                  ? '—'
                  : '${_proximaAcao!.day.toString().padLeft(2, '0')}/${_proximaAcao!.month.toString().padLeft(2, '0')}/${_proximaAcao!.year}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: widget.processando ? null : _enviar,
            child: Text(
                widget.processando ? 'Registrando...' : 'Registrar Interação'),
          ),
        ),
      ],
    );
  }
}
