import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/crm_provider.dart';

// Fase Grupo 2 (Rodopar/Datapar, item 5, 03/08/2026) — CRM Comercial
// (cliente): carteira de clientes-tomadores, porta de
// crm-comercial/page.tsx (aba Carteira de Clientes).
class CrmClientesScreen extends ConsumerStatefulWidget {
  const CrmClientesScreen({super.key});

  @override
  ConsumerState<CrmClientesScreen> createState() => _CrmClientesScreenState();
}

class _CrmClientesScreenState extends ConsumerState<CrmClientesScreen> {
  final _buscaCtrl = TextEditingController();
  String _busca = '';

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  String _fmtCnpjCpf(String v) {
    final d = v.replaceAll(RegExp(r'\D'), '');
    if (d.length == 14) return d.replaceAllMapped(RegExp(r'(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})'), (m) => '${m[1]}.${m[2]}.${m[3]}/${m[4]}-${m[5]}');
    if (d.length == 11) return d.replaceAllMapped(RegExp(r'(\d{3})(\d{3})(\d{3})(\d{2})'), (m) => '${m[1]}.${m[2]}.${m[3]}-${m[4]}');
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(clientesCrmListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('CRM Comercial')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/crm-comercial/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Novo Cliente'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(clientesCrmListProvider),
        child: clientesAsync.when(
          data: (lista) {
            final termo = _busca.trim().toLowerCase();
            final filtrados = termo.isEmpty
                ? lista
                : lista.where((c) => c.razaoSocial.toLowerCase().contains(termo) || c.cnpjCpf.contains(termo.replaceAll(RegExp(r'\D'), ''))).toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Clientes-tomadores cadastrados. Propostas (Cotações) e histórico de relacionamento ficam no detalhe de cada cliente.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _buscaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Buscar',
                    hintText: 'Nome ou CNPJ/CPF...',
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
                    child: Center(child: Text('Nenhum cliente cadastrado ainda.', style: TextStyle(color: Colors.grey))),
                  )
                else
                  ...filtrados.map(_card),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        ),
      ),
    );
  }

  Widget _card(ClienteCrm c) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('/crm-comercial/${c.id}'),
        title: Text(c.razaoSocial, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_fmtCnpjCpf(c.cnpjCpf), style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
