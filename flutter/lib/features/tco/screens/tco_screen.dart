import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../centros_custo/providers/centros_custo_provider.dart'
    show centrosCustoClienteProvider;
import '../providers/tco_provider.dart';

import '../../../core/theme/app_theme.dart';

final _dataBr = DateFormat('dd/MM/yyyy');
final _dataIso = DateFormat('yyyy-MM-dd');
final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

// Fase TCO (29/07/2026) — Custo Total de Propriedade (cliente), porta de
// tco/page.tsx. Ver escopo em tco_provider.dart.
class TcoScreen extends ConsumerStatefulWidget {
  const TcoScreen({super.key});

  @override
  ConsumerState<TcoScreen> createState() => _TcoScreenState();
}

class _TcoScreenState extends ConsumerState<TcoScreen> {
  final _buscaCtrl = TextEditingController();
  String? _busca;
  String? _centroCustoId;
  String _ordenar = 'custo_por_km_desc';
  int _pagina = 1;
  DateTime _dataInicio = DateTime.now().subtract(const Duration(days: 90));
  DateTime _dataFim = DateTime.now();

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

  Future<void> _escolherData({required bool inicio}) async {
    final atual = inicio ? _dataInicio : _dataFim;
    final escolhida = await showDatePicker(
        context: context,
        initialDate: atual,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100));
    if (escolhida == null || !mounted) return;
    setState(() {
      if (inicio) {
        _dataInicio = escolhida;
      } else {
        _dataFim = escolhida;
      }
      _pagina = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtros = (
      busca: _busca,
      centroCustoId: _centroCustoId,
      ordenar: _ordenar,
      pagina: _pagina,
      dataInicio: _dataIso.format(_dataInicio),
      dataFim: _dataIso.format(_dataFim),
    );
    final resumoAsync = ref.watch(tcoResumoProvider(filtros));
    final centrosCustoAsync = ref.watch(centrosCustoClienteProvider);

    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('TCO — Custo Total de Propriedade')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(tcoResumoProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Custo completo por veículo no período (combustível, manutenção, multas, oficinas, custos fixos e '
              'depreciação), pra identificar quais veículos estão pesando mais no bolso e quando vale trocar.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _escolherData(inicio: true),
                    child: Text('De: ${_dataBr.format(_dataInicio)}',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _escolherData(inicio: false),
                    child: Text('Até: ${_dataBr.format(_dataFim)}',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
                FilledButton(
                    onPressed: _aplicarFiltros, child: const Text('Filtrar')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: centrosCustoAsync.when(
                    data: (lista) => DropdownButtonFormField<String?>(
                      value: _centroCustoId,
                      decoration: const InputDecoration(
                          labelText: 'Centro de custo',
                          border: OutlineInputBorder(),
                          isDense: true),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Todos')),
                        for (final c in lista)
                          DropdownMenuItem(
                              value: c.id,
                              child: Text(c.nome,
                                  overflow: TextOverflow.ellipsis)),
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
                  child: DropdownButtonFormField<String>(
                    value: _ordenar,
                    decoration: const InputDecoration(
                        labelText: 'Ordenar por',
                        border: OutlineInputBorder(),
                        isDense: true),
                    items: const [
                      DropdownMenuItem(
                          value: 'custo_por_km_desc',
                          child: Text('Maior custo/km')),
                      DropdownMenuItem(
                          value: 'custo_por_km_asc',
                          child: Text('Menor custo/km')),
                      DropdownMenuItem(
                          value: 'tco_total_desc',
                          child: Text('Maior TCO total')),
                    ],
                    onChanged: (v) => setState(() {
                      _ordenar = v ?? _ordenar;
                      _pagina = 1;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            resumoAsync.when(
              data: (lista) => _corpo(lista),
              loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Erro ao carregar: $e',
                    style: const TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _corpo(List<VeiculoResumoTco> lista) {
    if (lista.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
            child: Text('Nenhum veículo encontrado para esse filtro.',
                style: TextStyle(color: Colors.grey))),
      );
    }

    final tcoTotalFrota = lista.fold<double>(0, (s, v) => s + v.tcoTotal);
    final comKm = lista.where((v) => v.custoPorKm != null).toList();
    final custoPorKmMedio = comKm.isEmpty
        ? 0.0
        : comKm.fold<double>(0, (s, v) => s + (v.custoPorKm ?? 0)) /
            comKm.length;
    final semAquisicao = lista.where((v) => !v.tcoCompleto).length;

    final total = lista.first.totalCount;
    final totalPaginas = (total / 50).ceil().clamp(1, 999999);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _indicador('TCO total', _moeda.format(tcoTotalFrota)),
            const SizedBox(width: 8),
            _indicador(
                'Custo/km médio',
                custoPorKmMedio > 0
                    ? '${_moeda.format(custoPorKmMedio)}/km'
                    : '—'),
          ],
        ),
        const SizedBox(height: 8),
        _indicador('Sem dado de aquisição', '$semAquisicao',
            destaque: semAquisicao > 0),
        if (semAquisicao > 0) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A))),
            child: Text(
              '⚠️ $semAquisicao veículo(s) sem valor de aquisição cadastrado — o TCO deles está sendo calculado sem '
              'depreciação (custo "operacional"). Complete o cadastro em Veículos pra ver o TCO completo.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
        ],
        const SizedBox(height: 16),
        ...lista.map(_cardVeiculo),
        if (totalPaginas > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Página $_pagina de $totalPaginas · $total veículo(s)',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Row(
                children: [
                  TextButton(
                      onPressed:
                          _pagina > 1 ? () => setState(() => _pagina--) : null,
                      child: const Text('← Anterior')),
                  TextButton(
                      onPressed: _pagina < totalPaginas
                          ? () => setState(() => _pagina++)
                          : null,
                      child: const Text('Próxima →')),
                ],
              ),
            ],
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
          color: destaque ? const Color(0xFFFFFBEB) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: destaque ? const Color(0xFFFDE68A) : Colors.grey.shade200),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color:
                        destaque ? const Color(0xFF92400E) : Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _cardVeiculo(VeiculoResumoTco v) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('/tco/${v.placa}'),
        title: Row(
          children: [
            Expanded(
                child: Text(v.placa,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14))),
            Text(_moeda.format(v.tcoTotal),
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${[
                  v.marca,
                  v.modelo
                ].where((s) => s != null && s.isNotEmpty).join(' ')}'
                '${v.centroCustoNome != null ? ' · ${v.centroCustoNome}' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    v.custoPorKm != null
                        ? '${_moeda.format(v.custoPorKm!)}/km'
                        : 'custo/km indisponível',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: v.tcoCompleto
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      v.tcoCompleto ? 'Completo' : 'Operacional',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: v.tcoCompleto
                              ? const Color(0xFF047857)
                              : const Color(0xFF92400E)),
                    ),
                  ),
                  if (v.fonteDepreciacao == 'fipe_curva_real') ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Text('Curva FIPE',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0369A1))),
                    ),
                  ],
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
}
