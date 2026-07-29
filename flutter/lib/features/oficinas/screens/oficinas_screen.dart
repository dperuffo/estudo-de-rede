import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../veiculos/providers/veiculos_provider.dart';
import '../providers/oficinas_provider.dart';
import '../services/oficinas_service.dart';

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

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  Future<void> _abrirSolicitar(Oficina oficina) async {
    final sessao = await ref.read(sessaoProvider.future);
    final empresaId = sessao.empresaId;
    if (empresaId == null) return;
    if (!mounted) return;
    final veiculos = await ref.read(veiculosClienteProvider.future);

    String? placa;
    final descricaoCtrl = TextEditingController();
    final resultado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: StatefulBuilder(
          builder: (ctx, setStateLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Solicitar orçamento — ${oficina.nome}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: placa,
                decoration: const InputDecoration(labelText: 'Veículo (opcional)', border: OutlineInputBorder(), isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('—')),
                  for (final v in veiculos) DropdownMenuItem(value: v.placa, child: Text(v.placa)),
                ],
                onChanged: (v) => setStateLocal(() => placa = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descricaoCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Serviço desejado *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (descricaoCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Enviar solicitação'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (resultado != true || descricaoCtrl.text.trim().isEmpty) return;
    try {
      await OficinasService().solicitar(
        empresaId: empresaId,
        oficinaId: oficina.id,
        placa: placa,
        descricaoServico: descricaoCtrl.text.trim(),
        criadoPor: sessao.email,
      );
      if (!mounted) return;
      ref.invalidate(minhasSolicitacoesOficinaProvider);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitação enviada.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível enviar: $e')));
    }
  }

  Future<void> _abrirRegistrarResposta(SolicitacaoOrcamento s) async {
    final valorCtrl = TextEditingController();
    final prazoCtrl = TextEditingController();
    final obsCtrl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Registrar retorno da oficina', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('Cotação recebida por telefone/e-mail — documente aqui pra decidir depois.', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: valorCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Valor orçado (R\$) *', border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 10),
            TextField(controller: prazoCtrl, decoration: const InputDecoration(labelText: 'Prazo de execução', border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 10),
            TextField(controller: obsCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Observações', border: OutlineInputBorder())),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (double.tryParse(valorCtrl.text.replaceAll(',', '.')) == null) return;
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
      await OficinasService().registrarResposta(s.id, valorOrcado: valor, prazoExecucao: prazoCtrl.text.trim().isEmpty ? null : prazoCtrl.text.trim(), observacoes: obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim());
      ref.invalidate(minhasSolicitacoesOficinaProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível registrar: $e')));
    }
  }

  Future<void> _decidir(SolicitacaoOrcamento s, String decisao) async {
    final sessao = await ref.read(sessaoProvider.future);
    try {
      await OficinasService().decidir(s.id, decisao, sessao.email);
      ref.invalidate(minhasSolicitacoesOficinaProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível atualizar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rede de Oficinas'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
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
    final oficinasAsync = ref.watch(catalogoOficinasProvider((uf: _uf, especialidade: _especialidade)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _buscaCtrl,
          decoration: const InputDecoration(labelText: 'Buscar', hintText: 'Nome ou município...', border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.search)),
          onChanged: (v) => setState(() => _busca = v),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String?>(
          value: _especialidade,
          decoration: const InputDecoration(labelText: 'Especialidade', border: OutlineInputBorder(), isDense: true),
          items: [
            const DropdownMenuItem(value: null, child: Text('Todas')),
            for (final e in especialidadesOficina) DropdownMenuItem(value: e, child: Text(e)),
          ],
          onChanged: (v) => setState(() => _especialidade = v),
        ),
        const SizedBox(height: 16),
        oficinasAsync.when(
          data: (lista) {
            final termo = _busca.trim().toLowerCase();
            final filtradas = termo.isEmpty
                ? lista
                : lista.where((o) => o.nome.toLowerCase().contains(termo) || (o.municipio?.toLowerCase().contains(termo) ?? false)).toList();
            if (filtradas.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Nenhuma oficina encontrada para esse filtro.', style: TextStyle(color: Colors.grey))),
              );
            }
            return Column(children: filtradas.map(_cardOficina).toList());
          },
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          error: (e, _) => Text('Erro ao carregar: $e', style: const TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  Widget _cardOficina(Oficina o) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(o.nome, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 2),
            Text(
              '${[o.municipio, o.uf].where((s) => s != null && s.isNotEmpty).join(' / ')}${o.avaliacaoMedia != null ? ' · ⭐ ${o.avaliacaoMedia!.toStringAsFixed(1)}' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (o.especialidades.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: o.especialidades
                    .map((e) => Chip(
                          label: Text(e, style: const TextStyle(fontSize: 10)),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
            ],
            if (o.telefone != null || o.email != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${o.telefone ?? ''} ${o.email ?? ''}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(onPressed: () => _abrirSolicitar(o), child: const Text('Solicitar orçamento')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _abaSolicitacoes() {
    final solicitacoesAsync = ref.watch(minhasSolicitacoesOficinaProvider);
    return solicitacoesAsync.when(
      data: (lista) {
        if (lista.isEmpty) {
          return const Center(child: Text('Nenhuma solicitação de orçamento ainda.', style: TextStyle(color: Colors.grey)));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: lista.map(_cardSolicitacao).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
    );
  }

  Widget _cardSolicitacao(SolicitacaoOrcamento s) {
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
                    '${s.oficinaNome ?? 'Oficina'}${s.placa != null ? ' · ${s.placa}' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusOrcamentoCorFundo[s.status] ?? const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                  child: Text(statusOrcamentoLabel[s.status] ?? s.status,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusOrcamentoCorTexto[s.status] ?? Colors.grey.shade700)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(s.descricaoServico, style: const TextStyle(fontSize: 12)),
            if (s.valorOrcado != null) ...[
              const SizedBox(height: 6),
              Text(
                'Orçado: R\$ ${s.valorOrcado!.toStringAsFixed(2).replaceAll('.', ',')}${s.prazoExecucao != null ? ' · Prazo: ${s.prazoExecucao}' : ''}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
            if (s.observacoesOficina != null) ...[
              const SizedBox(height: 4),
              Text(s.observacoesOficina!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
            if (s.status == 'solicitado') ...[
              const SizedBox(height: 10),
              OutlinedButton(onPressed: () => _abrirRegistrarResposta(s), child: const Text('Registrar retorno da oficina')),
            ],
            if (s.status == 'respondido') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton(onPressed: () => _decidir(s, 'aceito'), child: const Text('Aceitar')),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: () => _decidir(s, 'recusado'), child: const Text('Recusar')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
