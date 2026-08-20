import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../veiculos/providers/veiculos_provider.dart';
import '../providers/oficinas_provider.dart';
import '../services/oficinas_service.dart';

import '../../../core/theme/app_theme.dart';

// Fase Onda-2 (benchmark TicketLog, item #5) — Rede de Oficinas
// Credenciadas: catálogo + solicitação de orçamento (aba 1) e
// acompanhamento das solicitações (aba 2), porta de oficinas/page.tsx.
class OficinasScreen extends ConsumerStatefulWidget {
  const OficinasScreen({super.key});

  @override
  ConsumerState<OficinasScreen> createState() => _OficinasScreenState();
}

class _OficinasScreenState extends ConsumerState<OficinasScreen> {
  String? _uf;
  String? _especialidade;
  final _buscaCtrl = TextEditingController();
  String _busca = '';
  // Fase marketplace-pecas (04/08/2026) — seleção multi-oficina: o cliente
  // marca quantas quiser e pede cotação pra todas de uma vez (mesmo padrão
  // da web, CatalogoOficinasComSelecao.tsx).
  final Set<String> _selecionadas = {};

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  void _alternarSelecao(String oficinaId) {
    setState(() {
      if (_selecionadas.contains(oficinaId)) {
        _selecionadas.remove(oficinaId);
      } else {
        _selecionadas.add(oficinaId);
      }
    });
  }

  Future<void> _abrirSolicitarMulti(List<Oficina> todasOficinas) async {
    final sessao = await ref.read(sessaoProvider.future);
    final empresaId = sessao.empresaId;
    if (empresaId == null || _selecionadas.isEmpty) return;
    if (!mounted) return;
    final veiculos = await ref.read(veiculosClienteProvider.future);
    final oficinasSelecionadas =
        todasOficinas.where((o) => _selecionadas.contains(o.id)).toList();

    String? placa;
    final descricaoCtrl = TextEditingController();
    final resultado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: StatefulBuilder(
          builder: (ctx, setStateLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Pedir cotação — ${oficinasSelecionadas.length} oficina${oficinasSelecionadas.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: oficinasSelecionadas
                    .map((o) => Chip(
                          label: Text(o.nome,
                              style: const TextStyle(fontSize: 10)),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: placa,
                decoration: const InputDecoration(
                    labelText: 'Veículo (opcional)',
                    border: OutlineInputBorder(),
                    isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('—')),
                  for (final v in veiculos)
                    DropdownMenuItem(value: v.placa, child: Text(v.placa)),
                ],
                onChanged: (v) => setStateLocal(() => placa = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descricaoCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Serviço desejado *',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (descricaoCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Enviar pedido'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (resultado != true || descricaoCtrl.text.trim().isEmpty) return;
    try {
      await OficinasService().solicitarMulti(
        empresaId: empresaId,
        oficinaIds: _selecionadas.toList(),
        placa: placa,
        descricaoServico: descricaoCtrl.text.trim(),
        criadoPor: sessao.email,
      );
      if (!mounted) return;
      setState(() => _selecionadas.clear());
      ref.invalidate(meusPedidosOrcamentoProvider);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pedido enviado pra todas as oficinas selecionadas.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Não foi possível enviar: $e')));
    }
  }

  Future<void> _abrirRegistrarResposta(PropostaOrcamento s) async {
    final valorCtrl = TextEditingController();
    final prazoCtrl = TextEditingController();
    final obsCtrl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Registrar retorno da oficina',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            const Text(
                'Cotação recebida por telefone/e-mail — documente aqui pra decidir depois.',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: valorCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Valor orçado (R\$) *',
                  border: OutlineInputBorder(),
                  isDense: true),
            ),
            const SizedBox(height: 10),
            TextField(
                controller: prazoCtrl,
                decoration: const InputDecoration(
                    labelText: 'Prazo de execução',
                    border: OutlineInputBorder(),
                    isDense: true)),
            const SizedBox(height: 10),
            TextField(
                controller: obsCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Observações', border: OutlineInputBorder())),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (double.tryParse(valorCtrl.text.replaceAll(',', '.')) ==
                      null) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text('Salvar'),
              ),
            ),
          ],
        ),
      ),
    );
    final valor = double.tryParse(valorCtrl.text.replaceAll(',', '.'));
    if (ok != true || valor == null) return;
    try {
      await OficinasService().registrarResposta(s.id,
          valorOrcado: valor,
          prazoExecucao:
              prazoCtrl.text.trim().isEmpty ? null : prazoCtrl.text.trim(),
          observacoes:
              obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim());
      ref.invalidate(meusPedidosOrcamentoProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível registrar: $e')));
    }
  }

  Future<void> _decidir(PropostaOrcamento p, String decisao) async {
    final sessao = await ref.read(sessaoProvider.future);
    try {
      await OficinasService().decidir(p.id, decisao, sessao.email);
      ref.invalidate(meusPedidosOrcamentoProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível atualizar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Rede de Oficinas'),
          bottom: const TabBar(
            labelColor: AppTheme.glassTextoAtivo,
            unselectedLabelColor: AppTheme.glassTextoMuted,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: '🔧 Catálogo'),
              Tab(text: '📋 Minhas Solicitações'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_abaCatalogo(), _abaSolicitacoes()],
        ),
      ),
    );
  }

  Widget _abaCatalogo() {
    final oficinasAsync = ref.watch(
        catalogoOficinasProvider((uf: _uf, especialidade: _especialidade)));

    return oficinasAsync.when(
      data: (lista) {
        final termo = _busca.trim().toLowerCase();
        final filtradas = termo.isEmpty
            ? lista
            : lista
                .where((o) =>
                    o.nome.toLowerCase().contains(termo) ||
                    (o.municipio?.toLowerCase().contains(termo) ?? false))
                .toList();

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    controller: _buscaCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Buscar',
                        hintText: 'Nome ou município...',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.search)),
                    onChanged: (v) => setState(() => _busca = v),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    value: _especialidade,
                    decoration: const InputDecoration(
                        labelText: 'Especialidade',
                        border: OutlineInputBorder(),
                        isDense: true),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas')),
                      for (final e in especialidadesOficina)
                        DropdownMenuItem(value: e, child: Text(e)),
                    ],
                    onChanged: (v) => setState(() => _especialidade = v),
                  ),
                  const SizedBox(height: 16),
                  if (filtradas.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                          child: Text(
                              'Nenhuma oficina encontrada para esse filtro.',
                              style: TextStyle(color: Colors.grey))),
                    )
                  else
                    Column(children: filtradas.map(_cardOficina).toList()),
                ],
              ),
            ),
            // Fase marketplace-pecas (04/08/2026) — barra fixa embaixo,
            // mesmo padrão da web (barra "sticky" com contagem + botão),
            // só aparece com pelo menos 1 oficina marcada.
            if (_selecionadas.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border:
                      const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_selecionadas.length} oficina${_selecionadas.length > 1 ? 's' : ''} selecionada${_selecionadas.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      FilledButton(
                          onPressed: () => _abrirSolicitarMulti(lista),
                          child: const Text('Pedir cotação')),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text('Erro ao carregar: $e',
              style: const TextStyle(color: Colors.red))),
    );
  }

  Widget _cardOficina(Oficina o) {
    final selecionada = _selecionadas.contains(o.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: selecionada
            ? const BorderSide(color: Colors.blue, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _alternarSelecao(o.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.nome,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      '${[
                        o.municipio,
                        o.uf
                      ].where((s) => s != null && s.isNotEmpty).join(' / ')}${o.avaliacaoMedia != null ? ' · ⭐ ${o.avaliacaoMedia!.toStringAsFixed(1)}' : ''}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (o.especialidades.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: o.especialidades
                            .map((e) => Chip(
                                  label: Text(e,
                                      style: const TextStyle(fontSize: 10)),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ))
                            .toList(),
                      ),
                    ],
                    if (o.telefone != null || o.email != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('${o.telefone ?? ''} ${o.email ?? ''}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ),
                  ],
                ),
              ),
              Checkbox(
                  value: selecionada, onChanged: (_) => _alternarSelecao(o.id)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _abaSolicitacoes() {
    final pedidosAsync = ref.watch(meusPedidosOrcamentoProvider);
    return pedidosAsync.when(
      data: (lista) {
        if (lista.isEmpty) {
          return const Center(
              child: Text('Nenhuma solicitação de orçamento ainda.',
                  style: TextStyle(color: Colors.grey)));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: lista.map(_cardPedido).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
    );
  }

  // Fase marketplace-pecas (04/08/2026) — 1 pedido pode ter várias
  // propostas (1 por oficina escolhida); este card mostra todas lado a
  // lado pra comparação, cada uma com seu próprio botão de ação.
  Widget _cardPedido(PedidoOrcamento p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${p.descricaoServico}${p.placa != null ? ' · ${p.placa}' : ''}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: p.status == 'decidido'
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    p.status == 'decidido'
                        ? 'Decidido'
                        : 'Aguardando propostas',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: p.status == 'decidido'
                            ? const Color(0xFF166534)
                            : const Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
                '${p.propostas.length} oficina${p.propostas.length > 1 ? 's' : ''} cotada${p.propostas.length > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 8),
            ...p.propostas.map(_cardProposta),
          ],
        ),
      ),
    );
  }

  Widget _cardProposta(PropostaOrcamento s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(s.oficinaNome ?? 'Oficina',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: statusOrcamentoCorFundo[s.status] ??
                        const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(statusOrcamentoLabel[s.status] ?? s.status,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusOrcamentoCorTexto[s.status] ??
                            Colors.grey.shade700)),
              ),
            ],
          ),
          if (s.valorOrcado != null) ...[
            const SizedBox(height: 6),
            Text(
              'Orçado: R\$ ${s.valorOrcado!.toStringAsFixed(2).replaceAll('.', ',')}${s.prazoExecucao != null ? ' · Prazo: ${s.prazoExecucao}' : ''}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          if (s.observacoesOficina != null) ...[
            const SizedBox(height: 4),
            Text(s.observacoesOficina!,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
          if (s.status == 'solicitado') ...[
            const SizedBox(height: 8),
            OutlinedButton(
                onPressed: () => _abrirRegistrarResposta(s),
                child: const Text('Registrar retorno da oficina')),
          ],
          if (s.status == 'respondido') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                    onPressed: () => _decidir(s, 'aceito'),
                    child: const Text('Aceitar')),
                const SizedBox(width: 8),
                OutlinedButton(
                    onPressed: () => _decidir(s, 'recusado'),
                    child: const Text('Recusar')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
