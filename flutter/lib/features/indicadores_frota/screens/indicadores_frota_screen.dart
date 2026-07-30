import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/indicadores_frota_provider.dart';

final _dataBr = DateFormat('dd/MM/yyyy');
final _dataIso = DateFormat('yyyy-MM-dd');
final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

// Fase Indicadores-da-Frota (30/07/2026) — porta de indicadores-frota/page.tsx.
// Fase D (pedido do Daniel: "colocar um filtro de seleção do veículo...
// escolher o veículo específico ou todos, ou também poder comparar veículos
// entre si... indicadores distintos por modelo, tipo de veículo") acrescenta
// os filtros de tipo/modelo/veículo e a tabela de comparação. Ver escopo
// completo em indicadores_frota_provider.dart.
class IndicadoresFrotaScreen extends ConsumerStatefulWidget {
  const IndicadoresFrotaScreen({super.key});

  @override
  ConsumerState<IndicadoresFrotaScreen> createState() => _IndicadoresFrotaScreenState();
}

class _IndicadoresFrotaScreenState extends ConsumerState<IndicadoresFrotaScreen> {
  DateTime _dataInicio = DateTime.now().subtract(const Duration(days: 90));
  DateTime _dataFim = DateTime.now();
  String? _tipoVeiculo;
  String? _modelo;
  String? _placaSelecionada;
  int _sortColumnIndex = 0;
  bool _sortAsc = true;

  Future<void> _escolherData({required bool inicio}) async {
    final atual = inicio ? _dataInicio : _dataFim;
    final escolhida = await showDatePicker(context: context, initialDate: atual, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (escolhida == null || !mounted) return;
    setState(() {
      if (inicio) {
        _dataInicio = escolhida;
      } else {
        _dataFim = escolhida;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtro = (dataInicio: _dataIso.format(_dataInicio), dataFim: _dataIso.format(_dataFim));
    final kpisAsync = ref.watch(kpisFrotaProvider(filtro));
    final veiculosAsync = ref.watch(kpisPorVeiculoProvider(filtro));

    return Scaffold(
      appBar: AppBar(title: const Text('Indicadores da Frota')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(kpisFrotaProvider);
          ref.invalidate(kpisPorVeiculoProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Os principais KPIs de gestão de frota, calculados a partir dos dados já cadastrados. Filtre por '
              'veículo, tipo ou modelo, ou compare a frota inteira na tabela abaixo.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _escolherData(inicio: true),
                    child: Text('De: ${_dataBr.format(_dataInicio)}', style: const TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _escolherData(inicio: false),
                    child: Text('Até: ${_dataBr.format(_dataFim)}', style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            veiculosAsync.when(
              data: (veiculos) => _corpo(kpisAsync, veiculos, filtro),
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Erro ao carregar veículos: $e', style: const TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _corpo(AsyncValue<KpisFrota?> kpisAsync, List<VeiculoKpi> veiculos, FiltroKpisFrota filtro) {
    final tipos = veiculos.map((v) => v.tipoVeiculo).whereType<String>().toSet().toList()..sort();
    final modelos = veiculos.map((v) => v.modelo).whereType<String>().toSet().toList()..sort();
    final filtrados = veiculos
        .where((v) => (_tipoVeiculo == null || v.tipoVeiculo == _tipoVeiculo) && (_modelo == null || v.modelo == _modelo))
        .toList();

    final diasPeriodo = _dataFim.difference(_dataInicio).inDays + 1;
    VeiculoKpi? veiculoSelecionado;
    if (_placaSelecionada != null) {
      for (final v in veiculos) {
        if (v.placa == _placaSelecionada) {
          veiculoSelecionado = v;
          break;
        }
      }
    }
    final filtroAtivo = _tipoVeiculo != null || _modelo != null;

    KpisExibicao? kpis;
    String contexto = 'Frota inteira';
    if (veiculoSelecionado != null) {
      kpis = KpisExibicao.deVeiculo(veiculoSelecionado);
      contexto = 'Veículo ${veiculoSelecionado.placa}';
    } else if (filtroAtivo) {
      kpis = agregarVeiculos(filtrados, diasPeriodo);
      contexto = 'Frota filtrada (${filtrados.length} veículo${filtrados.length == 1 ? '' : 's'})';
    } else {
      final k = kpisAsync.asData?.value;
      if (k != null) kpis = KpisExibicao.deFrota(k);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                value: _tipoVeiculo,
                decoration: const InputDecoration(labelText: 'Tipo de veículo', border: OutlineInputBorder(), isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos')),
                  for (final t in tipos) DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _tipoVeiculo = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String?>(
                value: _modelo,
                decoration: const InputDecoration(labelText: 'Modelo', border: OutlineInputBorder(), isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos')),
                  for (final m in modelos) DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _modelo = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String?>(
          value: _placaSelecionada,
          decoration: const InputDecoration(labelText: 'Veículo', border: OutlineInputBorder(), isDense: true),
          items: [
            const DropdownMenuItem(value: null, child: Text('Todos (agregado)')),
            for (final v in filtrados) DropdownMenuItem(value: v.placa, child: Text(v.placa)),
          ],
          onChanged: (v) => setState(() => _placaSelecionada = v),
        ),
        const SizedBox(height: 16),
        if (kpis != null) ...[
          Text(contexto, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _kpisView(kpis, veiculoSelecionado),
        ] else if (kpisAsync.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (kpisAsync.hasError)
          Text('Erro ao carregar: ${kpisAsync.error}', style: const TextStyle(color: Colors.red, fontSize: 12))
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Nenhum dado encontrado para esse período.', style: TextStyle(color: Colors.grey))),
          ),
        const SizedBox(height: 24),
        Text('Comparação entre veículos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text('Toque numa placa pra ver os indicadores só dela acima, ou num cabeçalho pra ordenar.',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 8),
        _tabelaComparacao(filtrados),
      ],
    );
  }

  Widget _kpisView(KpisExibicao k, VeiculoKpi? veiculoSelecionado) {
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.7,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            _card('Disponibilidade', k.disponibilidadePct != null ? '${k.disponibilidadePct}%' : '—', destaque: k.disponibilidadePct != null && k.disponibilidadePct! < 90),
            _card('CPK operacional', k.cpkOperacional != null ? '${_moeda.format(k.cpkOperacional)}/km' : '—'),
            _card('Consumo médio', k.mediaKmL != null ? '${k.mediaKmL} km/l' : '—'),
            _card('Utilização', k.utilizacaoPct != null ? '${k.utilizacaoPct}%' : '—', destaque: k.utilizacaoPct != null && k.utilizacaoPct! < 70),
            _card(
              'Manutenção corretiva',
              k.pctCorretiva != null ? '${k.pctCorretiva}%' : 'Sem classificação',
              destaque: k.pctCorretiva != null && k.pctCorretiva! > 20,
            ),
            _card(veiculoSelecionado != null ? 'Veículo' : 'Veículos no filtro', veiculoSelecionado?.placa ?? '${k.totalVeiculos}'),
            _card(
              'Conformidade (checklist)',
              k.conformidadePct != null ? '${k.conformidadePct}%' : 'Sem inspeções',
              destaque: k.conformidadePct != null && k.conformidadePct! < 90,
            ),
            _card('TMRNC (resolução)', k.tmrncHoras != null ? '${k.tmrncHoras}h' : 'Sem pendências resolvidas'),
            if (k.indiceSinistralidade != null)
              _card('Índice de sinistralidade', '${k.indiceSinistralidade}%', destaque: k.indiceSinistralidade! > 10)
            else
              _card('Sinistros no período', '${k.totalSinistros}', destaque: k.totalSinistros > 0),
          ],
        ),
        if (k.manutencaoNaoClassificadaCusto > 0) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFDE68A))),
            child: Text(
              '⚠️ ${_moeda.format(k.manutencaoNaoClassificadaCusto)} em manutenções deste período ainda não foram '
              'classificadas como Preventiva ou Corretiva. Classifique as novas manutenções em Manutenção Preditiva.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => context.push('/manutencao-preditiva'),
            child: const Text('Ir para Manutenção Preditiva →', style: TextStyle(fontSize: 12)),
          ),
        ],
        if (k.itensInspecionados == 0) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
            child: const Text(
              'Nenhuma inspeção registrada neste período — a conformidade e o TMRNC aparecem assim que a primeira '
              'inspeção for feita em Checklist de Inspeção.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ],
    );
  }

  Widget _card(String label, String valor, {bool destaque = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: destaque ? const Color(0xFFFFFBEB) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: destaque ? const Color(0xFFFDE68A) : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: destaque ? const Color(0xFF92400E) : Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _tabelaComparacao(List<VeiculoKpi> veiculos) {
    if (veiculos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('Nenhum veículo encontrado para esse filtro.', style: TextStyle(color: Colors.grey))),
      );
    }

    final ordenados = [...veiculos];
    int cmp<T extends Comparable>(T? a, T? b) {
      if (a == null) return 1;
      if (b == null) return -1;
      return a.compareTo(b);
    }

    switch (_sortColumnIndex) {
      case 0:
        ordenados.sort((a, b) => cmp(a.placa, b.placa));
        break;
      case 1:
        ordenados.sort((a, b) => cmp(a.disponibilidadePct, b.disponibilidadePct));
        break;
      case 2:
        ordenados.sort((a, b) => cmp(a.cpkOperacional, b.cpkOperacional));
        break;
      case 3:
        ordenados.sort((a, b) => cmp(a.mediaKmL, b.mediaKmL));
        break;
      case 4:
        ordenados.sort((a, b) => cmp(a.utilizacaoPct, b.utilizacaoPct));
        break;
      case 5:
        ordenados.sort((a, b) => cmp(a.conformidadePct, b.conformidadePct));
        break;
      case 6:
        ordenados.sort((a, b) => cmp(a.totalSinistros, b.totalSinistros));
        break;
    }
    final lista = _sortAsc ? ordenados : ordenados.reversed.toList();

    void ordenarPor(int coluna) {
      setState(() {
        if (_sortColumnIndex == coluna) {
          _sortAsc = !_sortAsc;
        } else {
          _sortColumnIndex = coluna;
          _sortAsc = true;
        }
      });
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        sortColumnIndex: _sortColumnIndex,
        sortAscending: _sortAsc,
        columnSpacing: 20,
        headingRowHeight: 40,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 48,
        columns: [
          DataColumn(label: const Text('Placa', style: TextStyle(fontSize: 12)), onSort: (i, _) => ordenarPor(i)),
          DataColumn(label: const Text('Disp.', style: TextStyle(fontSize: 12)), numeric: true, onSort: (i, _) => ordenarPor(i)),
          DataColumn(label: const Text('CPK', style: TextStyle(fontSize: 12)), numeric: true, onSort: (i, _) => ordenarPor(i)),
          DataColumn(label: const Text('Consumo', style: TextStyle(fontSize: 12)), numeric: true, onSort: (i, _) => ordenarPor(i)),
          DataColumn(label: const Text('Utiliz.', style: TextStyle(fontSize: 12)), numeric: true, onSort: (i, _) => ordenarPor(i)),
          DataColumn(label: const Text('Conf.', style: TextStyle(fontSize: 12)), numeric: true, onSort: (i, _) => ordenarPor(i)),
          DataColumn(label: const Text('Sinistr.', style: TextStyle(fontSize: 12)), numeric: true, onSort: (i, _) => ordenarPor(i)),
        ],
        rows: lista
            .map((v) => DataRow(
                  selected: v.placa == _placaSelecionada,
                  onSelectChanged: (_) => setState(() => _placaSelecionada = _placaSelecionada == v.placa ? null : v.placa),
                  cells: [
                    DataCell(Text(v.placa, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                    DataCell(Text(v.disponibilidadePct != null ? '${v.disponibilidadePct}%' : '—', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(v.cpkOperacional != null ? _moeda.format(v.cpkOperacional) : '—', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(v.mediaKmL != null ? '${v.mediaKmL}' : '—', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(v.utilizacaoPct != null ? '${v.utilizacaoPct}%' : '—', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(v.conformidadePct != null ? '${v.conformidadePct}%' : '—', style: const TextStyle(fontSize: 12))),
                    DataCell(Text('${v.totalSinistros}', style: const TextStyle(fontSize: 12))),
                  ],
                ))
            .toList(),
      ),
    );
  }
}
