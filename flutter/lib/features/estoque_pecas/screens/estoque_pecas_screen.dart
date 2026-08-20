import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/estoque_pecas_provider.dart';

import '../../../core/theme/app_theme.dart';

// Fase Grupo 1 Rodopar item 2 (03/08/2026, benchmark FNI vs Rodopar/Datapar)
// — Estoque de Peças (cliente): catálogo + busca + KPIs, porta de
// estoque-pecas/page.tsx.
class EstoquePecasScreen extends ConsumerStatefulWidget {
  const EstoquePecasScreen({super.key});

  @override
  ConsumerState<EstoquePecasScreen> createState() => _EstoquePecasScreenState();
}

class _EstoquePecasScreenState extends ConsumerState<EstoquePecasScreen> {
  final _buscaCtrl = TextEditingController();
  String _busca = '';

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  String _fmtMoeda(double? v) {
    if (v == null) return '—';
    return 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  @override
  Widget build(BuildContext context) {
    final pecasAsync = ref.watch(pecasEstoqueListProvider);

    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Estoque de Peças')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/estoque-pecas/nova'),
        icon: const Icon(Icons.add),
        label: const Text('Nova Peça'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(pecasEstoqueListProvider),
        child: pecasAsync.when(
          data: (lista) {
            final termo = _busca.trim().toLowerCase();
            final filtradas = termo.isEmpty
                ? lista
                : lista
                    .where((p) =>
                        p.nome.toLowerCase().contains(termo) ||
                        (p.codigo?.toLowerCase().contains(termo) ?? false))
                    .toList();

            final ativas = lista.where((p) => p.ativa).toList();
            final abaixoDoMinimo = ativas.where((p) => p.abaixoDoMinimo).length;
            final valorEmEstoque = ativas.fold<double>(0,
                (s, p) => s + p.quantidadeAtual * (p.custoUnitarioMedio ?? 0));

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Catálogo de peças da Manutenção, com saldo e custo médio calculados a partir das entradas e saídas registradas.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _kpi('Ativas', '${ativas.length}'),
                    const SizedBox(width: 8),
                    _kpi('Abaixo do mínimo', '$abaixoDoMinimo',
                        destaque: abaixoDoMinimo > 0),
                    const SizedBox(width: 8),
                    _kpi('Em estoque', _fmtMoeda(valorEmEstoque)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _buscaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Buscar',
                    hintText: 'Nome ou código...',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _busca = v),
                ),
                const SizedBox(height: 16),
                if (filtradas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                        child: Text('Nenhuma peça cadastrada ainda.',
                            style: TextStyle(color: Colors.grey))),
                  )
                else
                  ...filtradas.map(_card),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        ),
      ),
    );
  }

  Widget _kpi(String label, String valor, {bool destaque = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: destaque ? const Color(0xFFFEF2F2) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: destaque ? const Color(0xFFFECACA) : Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(valor,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: destaque ? const Color(0xFFB91C1C) : Colors.black87),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _card(PecaEstoque p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('/estoque-pecas/${p.id}'),
        title: Row(
          children: [
            Expanded(
              child: Text(
                p.nome + (!p.ativa ? ' (inativa)' : ''),
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
            if (p.codigo != null)
              Text(p.codigo!,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Saldo: ${p.quantidadeAtual} ${p.unidadeMedida} · Mínimo: ${p.quantidadeMinima} ${p.unidadeMedida}',
                style: TextStyle(
                    fontSize: 12,
                    color: p.abaixoDoMinimo
                        ? const Color(0xFFB91C1C)
                        : Colors.black87,
                    fontWeight:
                        p.abaixoDoMinimo ? FontWeight.w700 : FontWeight.normal),
              ),
              const SizedBox(height: 2),
              Text('Custo médio: ${_fmtMoeda(p.custoUnitarioMedio)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: p.abaixoDoMinimo
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  p.abaixoDoMinimo ? 'Repor' : 'OK',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: p.abaixoDoMinimo
                          ? const Color(0xFF991B1B)
                          : const Color(0xFF166534)),
                ),
              ),
            ],
          ),
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
