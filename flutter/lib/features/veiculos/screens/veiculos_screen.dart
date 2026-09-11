import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/veiculos_provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';

// Fase FLT-3 — Veículos (cliente). Ver escopo (sem paginação/importação
// por planilha) no comentário de veiculos_provider.dart.
class VeiculosScreen extends ConsumerStatefulWidget {
  const VeiculosScreen({super.key});

  @override
  ConsumerState<VeiculosScreen> createState() => _VeiculosScreenState();
}

class _VeiculosScreenState extends ConsumerState<VeiculosScreen> {
  final _buscaCtrl = TextEditingController();
  String _busca = '';
  String _filtroStatus = 'todos';

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(veiculosClienteProvider);

    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Veículos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/veiculos/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Novo'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (veiculos) {
          if (veiculos.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nenhum veículo cadastrado ainda.',
                    style: TextStyle(color: Colors.grey)),
              ),
            );
          }
          final ativos = veiculos.where((v) => v.ativo).length;

          final buscaLimpa = _busca.trim().toLowerCase();
          final filtrados = veiculos.where((v) {
            if (_filtroStatus == 'ativos' && !v.ativo) return false;
            if (_filtroStatus == 'inativos' && v.ativo) return false;
            if (buscaLimpa.isEmpty) return true;
            final placa = v.placa.toLowerCase();
            final marca = (v.marca ?? '').toLowerCase();
            final modelo = (v.modelo ?? '').toLowerCase();
            return placa.contains(buscaLimpa) ||
                marca.contains(buscaLimpa) ||
                modelo.contains(buscaLimpa);
          }).toList();

          // Fase Pente-Fino-Performance (10/09/2026, pedido do Daniel:
          // "melhorar a performance da aplicacao como um todo") — achado
          // real (auditoria): a lista inteira era construída de uma vez
          // (ListView(children: [...])), então uma frota de centenas de
          // veículos virava centenas de widgets montados mesmo com só ~8
          // cabendo na tela. Trocado por CustomScrollView + Sliver: o
          // cabeçalho (indicadores/busca/filtro) fica num SliverToBoxAdapter
          // fixo, e no celular (o caso mais comum e o que a auditoria mais
          // apontou) a lista agora é lazy de verdade (SliverList.builder).
          // A partir de tablet mantém o Responsive.grade original (Wrap,
          // não-lazy): os cards têm altura variável conforme o texto
          // (marca/modelo/centro de custo), e um SliverGrid de altura fixa
          // arriscaria cortar conteúdo sem eu poder conferir visualmente —
          // tablet/desktop tem tela maior e é onde esse existia há só 2 dias
          // (Fase Auditoria-UX-Responsividade), preferi não arriscar quebrar.
          final isTablet = Responsive.isTablet(context);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(veiculosClienteProvider),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: _indicador(
                                    'Total', veiculos.length.toString())),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _indicador('Ativos', ativos.toString())),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _indicador('Inativos',
                                    (veiculos.length - ativos).toString())),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _buscaCtrl,
                          decoration: InputDecoration(
                            hintText: 'Buscar por placa, marca ou modelo...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: _busca.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _buscaCtrl.clear();
                                      setState(() => _busca = '');
                                    },
                                  ),
                          ),
                          onChanged: (v) => setState(() => _busca = v),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Todos'),
                              selected: _filtroStatus == 'todos',
                              onSelected: (_) =>
                                  setState(() => _filtroStatus = 'todos'),
                            ),
                            ChoiceChip(
                              label: const Text('Ativos'),
                              selected: _filtroStatus == 'ativos',
                              onSelected: (_) =>
                                  setState(() => _filtroStatus = 'ativos'),
                            ),
                            ChoiceChip(
                              label: const Text('Inativos'),
                              selected: _filtroStatus == 'inativos',
                              onSelected: (_) =>
                                  setState(() => _filtroStatus = 'inativos'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (filtrados.isEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                  'Nenhum veículo encontrado com esse filtro.',
                                  style:
                                      TextStyle(color: Colors.grey.shade600)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (filtrados.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                    sliver: isTablet
                        ? SliverToBoxAdapter(
                            child: Responsive.grade(
                              context,
                              itens: filtrados
                                  .map((v) => _cardVeiculo(context, v))
                                  .toList(),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) =>
                                  _cardVeiculo(context, filtrados[i]),
                              childCount: filtrados.length,
                            ),
                          ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _cardVeiculo(BuildContext context, Veiculo v) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('/veiculos/${v.id}'),
        title: Text(v.placa,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(builder: (context) {
              final marcaModelo = [v.marca, v.modelo]
                  .where((x) => x != null && x.isNotEmpty)
                  .join(' ');
              final texto = marcaModelo.isEmpty ? '—' : marcaModelo;
              return Tooltip(
                message: texto,
                child: Text(
                  texto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              );
            }),
            Text(
              [
                if (v.tipoVeiculo != null) v.tipoVeiculo!,
                v.classificacao,
                if (v.centroCustoNome != null) v.centroCustoNome!,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (v.ativo ? const Color(0xFF16A34A) : const Color(0xFF64748B))
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(v.ativo ? 'Ativo' : 'Inativo',
              style: TextStyle(
                  fontSize: 11,
                  color: v.ativo
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600)),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _indicador(String label, String valor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Text(valor,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
