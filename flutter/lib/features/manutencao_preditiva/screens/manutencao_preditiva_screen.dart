import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../centros_custo/providers/centros_custo_provider.dart' show CentroCusto, centrosCustoClienteProvider;
import '../providers/manutencao_preditiva_provider.dart';

// Fase FLT-3 — Manutenção Preditiva (cliente): lista + KPIs + filtros,
// porta de manutencao-preditiva/page.tsx. Ver escopo em
// manutencao_preditiva_provider.dart.
class ManutencaoPreditivaScreen extends ConsumerStatefulWidget {
  const ManutencaoPreditivaScreen({super.key});

  @override
  ConsumerState<ManutencaoPreditivaScreen> createState() => _ManutencaoPreditivaScreenState();
}

class _ManutencaoPreditivaScreenState extends ConsumerState<ManutencaoPreditivaScreen> {
  final _buscaCtrl = TextEditingController();
  String? _busca;
  String? _centroCustoId;
  String? _status;
  String _ordenar = 'score';
  int _pagina = 1;

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  void _aplicarFiltros() {
    setState(() {
      _busca = _buscaCtrl.text.trim().isEmpty ? null : _buscaCtrl.text.trim();
      _pagina = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtrosResumo = (busca: _busca, centroCustoId: _centroCustoId, status: _status, ordenar: _ordenar, pagina: _pagina);
    final filtrosKpis = (busca: _busca, centroCustoId: _centroCustoId);
    final resumoAsync = ref.watch(manutencaoResumoProvider(filtrosResumo));
    final kpisAsync = ref.watch(manutencaoKpisProvider(filtrosKpis));
    final centrosCustoAsync = ref.watch(centrosCustoClienteProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manutenção Preditiva')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Score de desgaste por veículo (óleo, pneus, filtros e outros 5 componentes), com base em km rodado, '
            'consumo e histórico real de manutenções.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),

          kpisAsync.when(
            data: (k) => _kpis(k),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Erro ao carregar indicadores: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _buscaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Buscar',
                    hintText: 'Placa, marca ou modelo...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _aplicarFiltros(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _aplicarFiltros, child: const Text('Filtrar')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: centrosCustoAsync.when(
                  data: (lista) => DropdownButtonFormField<String?>(
                    value: _centroCustoId,
                    decoration: const InputDecoration(labelText: 'Centro de custo', border: OutlineInputBorder(), isDense: true),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todos')),
                      for (final c in lista) DropdownMenuItem(value: c.id, child: Text(c.nome, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() {
                      _centroCustoId = v;
                      _pagina = 1;
                    }),
                  ),
                  loading: () => const SizedBox(height: 48),
                  error: (_, __) => const SizedBox(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Todos')),
                    DropdownMenuItem(value: 'critico', child: Text('🔴 Crítico')),
                    DropdownMenuItem(value: 'alerta', child: Text('🟡 Alerta')),
                    DropdownMenuItem(value: 'ok', child: Text('🟢 OK')),
                  ],
                  onChanged: (v) => setState(() {
                    _status = v;
                    _pagina = 1;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _ordenar,
            decoration: const InputDecoration(labelText: 'Ordenar por', border: OutlineInputBorder(), isDense: true),
            items: const [
              DropdownMenuItem(value: 'score', child: Text('Pior estado primeiro')),
              DropdownMenuItem(value: 'km', child: Text('Maior km')),
              DropdownMenuItem(value: 'placa', child: Text('Placa A→Z')),
            ],
            onChanged: (v) => setState(() {
              _ordenar = v ?? _ordenar;
              _pagina = 1;
            }),
          ),
          const SizedBox(height: 16),

          resumoAsync.when(
            data: (lista) => _lista(lista),
            loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Erro ao carregar: $e', style: const TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpis(KpisManutencao k) {
    return Column(
      children: [
        Row(
          children: [
            _indicador('Veículos', '${k.totalVeiculos}'),
            const SizedBox(width: 8),
            _indicador('🔴 Críticos', '${k.totalCriticos}', destaque: k.totalCriticos > 0),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _indicador('🟡 Em alerta', '${k.totalAlertas}'),
            const SizedBox(width: 8),
            _indicador('🟢 OK', '${k.totalOk}'),
          ],
        ),
        const SizedBox(height: 8),
        _indicador('Score médio', '${k.scoreMedio.round()}/100'),
        if (k.totalCriticos > 0) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFECACA))),
            child: Text(
              '🚨 ${k.totalCriticos} veículo(s) em estado crítico — pelo menos um componente vencido pelo km rodado. Priorize agendar manutenção para eles.',
              style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _indicador(String label, String valor, {bool destaque = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: destaque ? const Color(0xFFFEF2F2) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: destaque ? const Color(0xFFFECACA) : Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(valor, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: destaque ? const Color(0xFFB91C1C) : Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _lista(List<VeiculoResumoManutencao> lista) {
    if (lista.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('Nenhum veículo encontrado para esse filtro.', style: TextStyle(color: Colors.grey))),
      );
    }
    final total = lista.first.totalCount;
    final totalPaginas = (total / 50).ceil().clamp(1, 999999);
    return Column(
      children: [
        ...lista.map(_cardVeiculo),
        if (totalPaginas > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Página $_pagina de $totalPaginas · $total veículo(s)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Row(
                children: [
                  TextButton(
                    onPressed: _pagina > 1 ? () => setState(() => _pagina--) : null,
                    child: const Text('← Anterior'),
                  ),
                  TextButton(
                    onPressed: _pagina < totalPaginas ? () => setState(() => _pagina++) : null,
                    child: const Text('Próxima →'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _cardVeiculo(VeiculoResumoManutencao v) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('/manutencao-preditiva/${v.placa}'),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: corStatusFundo(v.status), borderRadius: BorderRadius.circular(12)),
              child: Text(
                '${v.status == 'critico' ? '🔴' : v.status == 'alerta' ? '🟡' : '🟢'} ${labelStatus[v.status] ?? v.status}',
                style: TextStyle(fontSize: 10, color: corStatusTexto(v.status), fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(v.placa, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
            Text('${v.scoreGeral}/100', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: corBarraScore(v.scoreGeral.toDouble()))),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${[v.marca, v.modelo].where((s) => s != null && s.isNotEmpty).join(' ')}${v.marca == null && v.modelo == null ? '—' : ''}'
                '${v.centroCustoNome != null ? ' · ${v.centroCustoNome}' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                v.kmAtual > 0 ? '${v.kmAtual.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} km' : '—',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              if (v.nCriticos > 0 || v.nAlertas > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      if (v.nCriticos > 0) Text('${v.nCriticos} crítico(s)  ', style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
                      if (v.nAlertas > 0) Text('${v.nAlertas} alerta(s)', style: const TextStyle(fontSize: 11, color: Color(0xFFD97706))),
                    ],
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
