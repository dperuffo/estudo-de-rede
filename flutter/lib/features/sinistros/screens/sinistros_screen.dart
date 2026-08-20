import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/sinistros_provider.dart';

import '../../../core/theme/app_theme.dart';

// Fase Indicadores-da-Frota C (30/07/2026) — porta de sinistros/page.tsx:
// lista + KPIs (total, com vítima, custo estimado).
class SinistrosScreen extends ConsumerStatefulWidget {
  const SinistrosScreen({super.key});

  @override
  ConsumerState<SinistrosScreen> createState() => _SinistrosScreenState();
}

class _SinistrosScreenState extends ConsumerState<SinistrosScreen> {
  final _buscaCtrl = TextEditingController();
  String _busca = '';

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  String _fmtData(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _fmtMoeda(double? v) {
    if (v == null) return '—';
    return 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  @override
  Widget build(BuildContext context) {
    final sinistrosAsync = ref.watch(sinistrosListProvider);

    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Sinistros e Acidentes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/sinistros/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Novo Sinistro'),
      ),
      body: sinistrosAsync.when(
        data: (lista) {
          final termo = _busca.trim().toLowerCase();
          final filtrados = termo.isEmpty
              ? lista
              : lista
                  .where((s) =>
                      s.placa.toLowerCase().contains(termo) ||
                      s.tipo.toLowerCase().contains(termo) ||
                      (s.motoristaNome?.toLowerCase().contains(termo) ??
                          false) ||
                      (s.localOcorrencia?.toLowerCase().contains(termo) ??
                          false))
                  .toList();
          final comVitima = lista.where((s) => s.houveVitima).length;
          final custoTotal =
              lista.fold<double>(0, (s, x) => s + (x.custoEstimado ?? 0));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  _kpi('Total no período', '${lista.length}'),
                  const SizedBox(width: 8),
                  _kpi('Com vítima', '$comVitima', destaque: comVitima > 0),
                  const SizedBox(width: 8),
                  _kpi('Custo estimado', _fmtMoeda(custoTotal)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _buscaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Buscar',
                  hintText: 'Placa, tipo, motorista ou local...',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _busca = v),
              ),
              const SizedBox(height: 16),
              if (filtrados.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                      child: Text(
                          'Nenhum sinistro registrado para esse filtro.',
                          style: TextStyle(color: Colors.grey))),
                )
              else
                ...filtrados.map(_card),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: destaque ? const Color(0xFFB91C1C) : Colors.black87),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _card(Sinistro s) {
    final cor = s.gravidade != null ? gravidadeSinistroCor[s.gravidade] : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Row(
          children: [
            Expanded(
                child: Text('${s.placa} · ${s.tipo}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14))),
            if (s.houveVitima)
              const Icon(Icons.warning_amber,
                  size: 16, color: Color(0xFFB91C1C)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_fmtData(s.dataSinistro)}${s.localOcorrencia != null ? ' · ${s.localOcorrencia}' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                '${s.motoristaNome ?? 'Sem motorista informado'} · ${_fmtMoeda(s.custoEstimado)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              if (s.gravidade != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: cor?.fundo ?? const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(s.gravidade!,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: cor?.texto ?? Colors.grey.shade700)),
                ),
              ],
            ],
          ),
        ),
        isThreeLine: true,
      ),
    );
  }
}
