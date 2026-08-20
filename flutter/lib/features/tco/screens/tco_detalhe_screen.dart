import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/tco_provider.dart';

import '../../../core/theme/app_theme.dart';

final _dataBr = DateFormat('dd/MM/yyyy');
final _dataIso = DateFormat('yyyy-MM-dd');
final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

String _milhar(int v) => v
    .toString()
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

// Fase TCO (29/07/2026) — detalhe do veículo, porta de tco/[placa]/page.tsx.
class TcoDetalheScreen extends ConsumerStatefulWidget {
  final String placa;
  const TcoDetalheScreen({super.key, required this.placa});

  @override
  ConsumerState<TcoDetalheScreen> createState() => _TcoDetalheScreenState();
}

class _TcoDetalheScreenState extends ConsumerState<TcoDetalheScreen> {
  DateTime _dataInicio = DateTime.now().subtract(const Duration(days: 90));
  DateTime _dataFim = DateTime.now();

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
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtro = (
      placa: widget.placa,
      dataInicio: _dataIso.format(_dataInicio),
      dataFim: _dataIso.format(_dataFim)
    );
    final detalheAsync = ref.watch(tcoDetalheProvider(filtro));
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: Text(widget.placa)),
      body: detalheAsync.when(
        data: (v) {
          if (v == null) {
            return const Center(child: Text('Veículo não encontrado.'));
          }
          return _conteudo(v);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
      ),
    );
  }

  Widget _conteudo(VeiculoDetalheTco v) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [v.marca, v.modelo]
                            .where((s) => s != null && s.isNotEmpty)
                            .join(' ')
                            .isEmpty
                        ? 'Sem marca/modelo cadastrado'
                        : [v.marca, v.modelo]
                            .where((s) => s != null && s.isNotEmpty)
                            .join(' '),
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  Text(
                    '${v.centroCustoNome ?? 'Sem centro de custo'}${v.anoFabricacao != null ? ' · ${v.anoFabricacao}' : ''}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_moeda.format(v.tcoTotal),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                Text(
                  v.custoPorKm != null
                      ? '${_moeda.format(v.custoPorKm!)}/km'
                      : 'sem custo/km',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 16),
        if (!v.tcoCompleto)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A))),
            child: const Text(
              '⚠️ Este veículo não tem valor de aquisição cadastrado — o TCO acima é operacional (sem depreciação). '
              'Complete o cadastro em Veículos pra ver o TCO completo.',
              style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Detalhamento por categoria',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.9,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    _componenteCard('⛽ Combustível', v.custoCombustivel),
                    _componenteCard('🔧 Manutenção', v.custoManutencao),
                    _componenteCard('🚨 Multas', v.custoMultas),
                    _componenteCard(
                        '🛠️ Oficinas credenciadas', v.custoOficinas),
                    _componenteCard('📋 Custos fixos', v.custoFixos),
                    _componenteCard(
                      '📉 Depreciação',
                      v.custoDepreciacao,
                      selo: v.fonteDepreciacao == 'fipe_curva_real'
                          ? 'Curva FIPE'
                          : v.fonteDepreciacao == 'linear_estimado'
                              ? 'Estimativa linear'
                              : null,
                    ),
                    _componenteCard('💰 Custo de capital', v.custoCapital),
                    _componenteCard(
                      '⏸️ Downtime',
                      v.custoDowntime,
                      selo: v.diasParadoPeriodo > 0
                          ? '${v.diasParadoPeriodo} dia(s) parado'
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dados de aquisição',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                _linhaDado(
                    'Valor de aquisição',
                    v.valorAquisicao != null
                        ? _moeda.format(v.valorAquisicao!)
                        : 'Não cadastrado'),
                _linhaDado(
                  'Data de aquisição',
                  v.dataAquisicao != null
                      ? _dataBr.format(DateTime.parse(v.dataAquisicao!))
                      : 'Não cadastrada',
                ),
                _linhaDado(
                  'Valor residual estimado',
                  v.valorResidualEstimado != null
                      ? _moeda.format(v.valorResidualEstimado!)
                      : v.valorAquisicao != null
                          ? '${_moeda.format(v.valorAquisicao! * 0.2)} (estimado em 20%)'
                          : '—',
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.push('/veiculos'),
                  child: const Text('Editar dados de aquisição em Veículos →',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vínculo FIPE',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 10),
                if (v.codigoFipe != null) ...[
                  _linhaDado('Código FIPE', v.codigoFipe!),
                  _linhaDado('Valor FIPE atual',
                      v.valorFipe != null ? _moeda.format(v.valorFipe!) : '—'),
                ] else
                  const Text(
                    'Este veículo ainda não está vinculado a um código FIPE — a depreciação acima usa a estimativa linear.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.push('/veiculos'),
                  child: const Text('Gerenciar vínculo FIPE em Veículos →',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Km no período: ${v.kmPeriodo != null ? '${_milhar(v.kmPeriodo!.round())} km' : 'sem abastecimentos com hodômetro no período'}.',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _componenteCard(String label, double? valor, {String? selo}) {
    final indisponivel = valor == null;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600))),
              if (selo != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(selo,
                      style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0369A1))),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            indisponivel ? '—' : _moeda.format(valor),
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: indisponivel ? Colors.grey.shade300 : Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _linhaDado(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Text(valor,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
