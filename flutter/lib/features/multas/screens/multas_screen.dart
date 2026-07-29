import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/multas_provider.dart';

// Fase Onda-2 (benchmark TicketLog, item #4) — Gestão de Multas (cliente):
// lista + KPIs + filtro de status, porta de multas/page.tsx.
class MultasScreen extends ConsumerStatefulWidget {
  const MultasScreen({super.key});

  @override
  ConsumerState<MultasScreen> createState() => _MultasScreenState();
}

class _MultasScreenState extends ConsumerState<MultasScreen> {
  String? _status;
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
    final multasAsync = ref.watch(multasListProvider((status: _status)));

    return Scaffold(
      appBar: AppBar(title: const Text('Gestão de Multas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/multas/nova'),
        icon: const Icon(Icons.add),
        label: const Text('Nova Multa'),
      ),
      body: multasAsync.when(
        data: (lista) {
          final termo = _busca.trim().toLowerCase();
          final filtradas = termo.isEmpty
              ? lista
              : lista
                  .where((m) =>
                      m.placa.toLowerCase().contains(termo) ||
                      (m.numeroAit?.toLowerCase().contains(termo) ?? false) ||
                      (m.descricao?.toLowerCase().contains(termo) ?? false) ||
                      (m.motoristaNome?.toLowerCase().contains(termo) ?? false))
                  .toList();

          final hoje = DateTime.now().toIso8601String().substring(0, 10);
          final pendentesIndicacao = lista.where((m) => m.status == 'pendente_indicacao').length;
          final vencendoEmBreve = lista
              .where((m) =>
                  m.status == 'pendente_indicacao' &&
                  m.dataLimiteIndicacao != null &&
                  m.dataLimiteIndicacao!.compareTo(hoje) >= 0)
              .length;
          final valorEmAberto = lista
              .where((m) => m.status != 'paga' && m.status != 'cancelada')
              .fold<double>(0, (s, m) => s + (m.valorParaExibir ?? 0));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  _kpi('Pendentes', '$pendentesIndicacao'),
                  const SizedBox(width: 8),
                  _kpi('Vencendo (7d)', '$vencendoEmBreve', destaque: vencendoEmBreve > 0),
                  const SizedBox(width: 8),
                  _kpi('Em aberto', _fmtMoeda(valorEmAberto)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _buscaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Buscar',
                  hintText: 'Placa, AIT, descrição ou motorista...',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _busca = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos')),
                  for (final s in statusMultaLabel.entries) DropdownMenuItem(value: s.key, child: Text(s.value)),
                ],
                onChanged: (v) => setState(() => _status = v),
              ),
              const SizedBox(height: 16),
              if (filtradas.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Nenhuma multa encontrada para esse filtro.', style: TextStyle(color: Colors.grey))),
                )
              else
                ...filtradas.map(_card),
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

  Widget _card(Multa m) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('/multas/${m.id}'),
        title: Row(
          children: [
            Expanded(child: Text(m.placa, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
            if (m.numeroAit != null) Text('AIT ${m.numeroAit}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_fmtData(m.dataInfracao)}${m.descricao != null ? ' · ${m.descricao}' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                '${m.motoristaNome ?? 'Sem condutor indicado'} · ${_fmtMoeda(m.valorParaExibir)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusMultaCorFundo[m.status] ?? const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusMultaLabel[m.status] ?? m.status,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusMultaCorTexto[m.status] ?? Colors.grey.shade700),
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
