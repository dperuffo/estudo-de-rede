import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/checklist_veiculos_provider.dart';

// Fase Indicadores-da-Frota C (30/07/2026) — porta de checklist-veiculos/
// page.tsx: lista de veículos com última inspeção e pendências abertas.
class ChecklistVeiculosScreen extends ConsumerStatefulWidget {
  const ChecklistVeiculosScreen({super.key});

  @override
  ConsumerState<ChecklistVeiculosScreen> createState() => _ChecklistVeiculosScreenState();
}

class _ChecklistVeiculosScreenState extends ConsumerState<ChecklistVeiculosScreen> {
  final _buscaCtrl = TextEditingController();
  String? _busca;

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  String _fmtData(String? iso) {
    if (iso == null) return 'Nunca inspecionado';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final listaAsync = ref.watch(checklistVeiculosListProvider(_busca));

    return Scaffold(
      appBar: AppBar(title: const Text('Checklist de Inspeção')),
      body: listaAsync.when(
        data: (lista) {
          final comPendencia = lista.where((v) => v.pendenciasAbertas > 0).length;
          final nuncaInspecionados = lista.where((v) => v.ultimaInspecao == null).length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Registro de inspeções periódicas (pneus, freios, luzes, documentação e outros itens de segurança), '
                'com histórico de não conformidades e tempo de resolução.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _kpi('Veículos', '${lista.length}'),
                  const SizedBox(width: 8),
                  _kpi('Com pendência', '$comPendencia', destaque: comPendencia > 0),
                  const SizedBox(width: 8),
                  _kpi('Nunca inspecionados', '$nuncaInspecionados'),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _buscaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Buscar',
                  hintText: 'Placa, marca ou modelo...',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                ),
                onSubmitted: (v) => setState(() => _busca = v.trim().isEmpty ? null : v.trim()),
              ),
              const SizedBox(height: 16),
              if (lista.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Nenhum veículo encontrado.', style: TextStyle(color: Colors.grey))),
                )
              else
                ...lista.map(_card),
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
          border: Border.all(color: destaque ? const Color(0xFFFECACA) : Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(valor,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: destaque ? const Color(0xFFB91C1C) : Colors.black87),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _card(VeiculoChecklist v) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('/checklist-veiculos/${v.placa}'),
        title: Text(v.placa, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${[v.marca, v.modelo].where((s) => s != null && s.isNotEmpty).join(' ')}${v.centroCustoNome != null ? ' · ${v.centroCustoNome}' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text('Última inspeção: ${_fmtData(v.ultimaInspecao)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        trailing: v.pendenciasAbertas > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12)),
                child: Text('${v.pendenciasAbertas} pendente(s)', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF991B1B))),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12)),
                child: const Text('OK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF166534))),
              ),
      ),
    );
  }
}
