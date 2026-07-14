import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/planos_viagem_provider.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _data = DateFormat('dd/MM/yyyy');

// Fase FLT-3 — Planos de Viagem (cliente): lista + KPIs + filtros +
// desempenho por veículo, porta de planos-viagem/page.tsx. Ver escopo em
// planos_viagem_provider.dart.
class PlanosViagemScreen extends ConsumerStatefulWidget {
  const PlanosViagemScreen({super.key});

  @override
  ConsumerState<PlanosViagemScreen> createState() => _PlanosViagemScreenState();
}

class _PlanosViagemScreenState extends ConsumerState<PlanosViagemScreen> {
  final _placaCtrl = TextEditingController();
  String? _status;
  String? _placa;

  @override
  void dispose() {
    _placaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtros = (status: _status, placa: _placa);
    final listaAsync = ref.watch(planosViagemListaProvider(filtros));

    return Scaffold(
      appBar: AppBar(title: const Text('Planos de Viagem')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/planos-viagem/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Novo Plano'),
      ),
      body: listaAsync.when(
        data: (lista) => _conteudo(lista),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
      ),
    );
  }

  Widget _conteudo(List<PlanoViagem> lista) {
    final kpis = calcularKpisPlanos(lista);
    final porVeiculo = agruparPorVeiculo(lista);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Orçamento estimado de custos e receita por viagem e veículo.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),

        _kpis(kpis),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos os status')),
                  for (final s in statusPlanoViagem) DropdownMenuItem(value: s, child: Text(statusPlanoViagemLabel[s] ?? s)),
                ],
                onChanged: (v) => setState(() => _status = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _placaCtrl,
                decoration: const InputDecoration(labelText: 'Placa', hintText: 'Filtrar placa...', border: OutlineInputBorder(), isDense: true),
                onSubmitted: (v) => setState(() => _placa = v.trim().isEmpty ? null : v.trim()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (lista.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Nenhum plano de viagem encontrado.', style: TextStyle(color: Colors.grey.shade500))),
          )
        else
          ...lista.map(_cardPlano),

        if (porVeiculo.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('DESEMPENHO POR VEÍCULO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          ...porVeiculo.map(_cardVeiculo),
        ],
      ],
    );
  }

  Widget _kpis(KpisPlanosViagem k) {
    return Column(
      children: [
        Row(
          children: [
            _indicador('Planos de viagem', '${k.totalPlanos}'),
            const SizedBox(width: 8),
            _indicador('Orçamento total estimado', _moeda.format(k.orcamentoTotalEstimado)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _indicador('Custo médio por km', k.custoMedioPorKm > 0 ? '${_moeda.format(k.custoMedioPorKm)}/km' : '—'),
            const SizedBox(width: 8),
            _indicador(
              'Margem estimada',
              _moeda.format(k.margemEstimada),
              destaque: k.margemEstimada >= 0 ? _CorDestaque.positivo : _CorDestaque.negativo,
            ),
          ],
        ),
      ],
    );
  }

  Widget _indicador(String label, String valor, {_CorDestaque destaque = _CorDestaque.neutro}) {
    final cor = switch (destaque) {
      _CorDestaque.positivo => const Color(0xFF15803D),
      _CorDestaque.negativo => const Color(0xFFDC2626),
      _CorDestaque.neutro => Colors.black87,
    };
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(valor, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cor), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _cardPlano(PlanoViagem p) {
    final margem = p.margemEstimada;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('/planos-viagem/${p.id}/editar'),
        title: Text(p.nome, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${p.placa ?? '—'} · ${p.motoristaNome ?? '—'}${p.dataSaida != null ? ' · ${_data.format(DateTime.parse(p.dataSaida!))}' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
                    child: Text(statusPlanoViagemLabel[p.status] ?? p.status, style: const TextStyle(fontSize: 10, color: Color(0xFF92400E), fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Text('${_moeda.format(p.custoTotalEstimado)} est.', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const Spacer(),
                  Text(
                    'Margem: ${_moeda.format(margem)}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: margem >= 0 ? const Color(0xFF15803D) : const Color(0xFFDC2626)),
                  ),
                ],
              ),
            ],
          ),
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _cardVeiculo(DesempenhoVeiculo v) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(v.placa, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            _linhaDado('Planos', '${v.planos}'),
            _linhaDado('KM total', '${v.km.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} km'),
            _linhaDado('Custo estimado', _moeda.format(v.custo)),
            _linhaDado('Custo/km', v.km > 0 ? '${_moeda.format(v.custo / v.km)}/km' : '—'),
          ],
        ),
      ),
    );
  }

  Widget _linhaDado(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Text(valor, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

enum _CorDestaque { positivo, negativo, neutro }
