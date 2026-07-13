import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/motoristas_provider.dart';

final _data = DateFormat('dd/MM/yyyy');

String _fmtData(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    return _data.format(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
}

String _somenteDigitos(String s) => s.replaceAll(RegExp(r'\D'), '');

// Fase FLT-3 — Motoristas (cliente). Ver escopo (sem paginação/importação
// por planilha) no comentário de motoristas_provider.dart.
// Pedido do Daniel: filtros de busca na tela. A web busca por nome/CPF
// server-side (paginada); aqui a lista inteira já vem carregada (até 500,
// ver provider), então filtra tudo client-side — busca por nome ou CPF
// (ignorando pontuação) + chips de status (Todos/Ativos/Inativos), sem
// round-trip novo ao banco.
class MotoristasScreen extends ConsumerStatefulWidget {
  const MotoristasScreen({super.key});

  @override
  ConsumerState<MotoristasScreen> createState() => _MotoristasScreenState();
}

class _MotoristasScreenState extends ConsumerState<MotoristasScreen> {
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
    final async = ref.watch(motoristasClienteProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Motoristas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/motoristas/novo'),
        icon: const Icon(Icons.person_add),
        label: const Text('Novo'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (motoristas) {
          if (motoristas.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nenhum motorista cadastrado ainda.', style: TextStyle(color: Colors.grey)),
              ),
            );
          }
          final ativos = motoristas.where((m) => m.ativo).length;

          final buscaLimpa = _busca.trim().toLowerCase();
          final buscaDigitos = _somenteDigitos(_busca);
          final filtrados = motoristas.where((m) {
            if (_filtroStatus == 'ativos' && !m.ativo) return false;
            if (_filtroStatus == 'inativos' && m.ativo) return false;
            if (buscaLimpa.isEmpty) return true;
            final bateNome = m.nomeCompleto.toLowerCase().contains(buscaLimpa);
            final bateCpf = buscaDigitos.isNotEmpty && _somenteDigitos(m.cpf).contains(buscaDigitos);
            return bateNome || bateCpf;
          }).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(motoristasClienteProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                Row(
                  children: [
                    Expanded(child: _indicador('Total', motoristas.length.toString())),
                    const SizedBox(width: 8),
                    Expanded(child: _indicador('Ativos', ativos.toString())),
                    const SizedBox(width: 8),
                    Expanded(child: _indicador('Inativos', (motoristas.length - ativos).toString())),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _buscaCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome ou CPF...',
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
                      onSelected: (_) => setState(() => _filtroStatus = 'todos'),
                    ),
                    ChoiceChip(
                      label: const Text('Ativos'),
                      selected: _filtroStatus == 'ativos',
                      onSelected: (_) => setState(() => _filtroStatus = 'ativos'),
                    ),
                    ChoiceChip(
                      label: const Text('Inativos'),
                      selected: _filtroStatus == 'inativos',
                      onSelected: (_) => setState(() => _filtroStatus = 'inativos'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (filtrados.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Nenhum motorista encontrado com esse filtro.',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ),
                  )
                else
                  ...filtrados.map((m) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () => context.push('/motoristas/${m.id}'),
                          title:
                              Text(m.nomeCompleto, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('CPF ${m.cpf} · ${m.classificacao}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              if (m.cnhVencimento != null)
                                Text('CNH vence em ${_fmtData(m.cnhVencimento)}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (m.ativo ? const Color(0xFF16A34A) : const Color(0xFF64748B)).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(m.status,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: m.ativo ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                    fontWeight: FontWeight.w600)),
                          ),
                          isThreeLine: m.cnhVencimento != null,
                        ),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _indicador(String label, String valor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
