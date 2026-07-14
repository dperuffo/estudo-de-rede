import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../clientes/providers/cliente_cadastro_provider.dart' show ClienteCadastro, statusEmpresaLabel, planoLabel;
import '../providers/clientes_admin_provider.dart';
import '../services/clientes_admin_service.dart';

String _formatarCnpj(String? cnpj) {
  if (cnpj == null || cnpj.isEmpty) return '—';
  final d = cnpj.replaceAll(RegExp(r'\D'), '');
  if (d.length != 14) return cnpj;
  return '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/${d.substring(8, 12)}-${d.substring(12, 14)}';
}

// Fase FLT-4 — Clientes (admin, consolidado): lista de TODOS os clientes
// de frota do sistema, porta de clientes/page.tsx. Ver escopo completo
// em clientes_admin_provider.dart.
class ClientesAdminListaScreen extends ConsumerStatefulWidget {
  const ClientesAdminListaScreen({super.key});

  @override
  ConsumerState<ClientesAdminListaScreen> createState() => _ClientesAdminListaScreenState();
}

class _ClientesAdminListaScreenState extends ConsumerState<ClientesAdminListaScreen> {
  final _buscaCtrl = TextEditingController();
  String _busca = '';
  final Set<String> _alternando = {};

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  Future<void> _alternarAtivo(ClienteCadastro c) async {
    setState(() => _alternando.add(c.id));
    final vaiAtivar = c.status != 'ativo';
    final erro = await ClientesAdminService().alternarAtivo(empresaId: c.id, ativar: vaiAtivar);
    if (!mounted) return;
    setState(() => _alternando.remove(c.id));
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    ref.invalidate(clientesAdminListaProvider(_busca));
    ref.invalidate(kpisClientesAdminProvider);
  }

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessaoProvider).valueOrNull;
    final ehAdmin = sessao?.ehAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Clientes (todos)')),
      body: !ehAdmin ? _acessoRestrito() : _conteudo(),
    );
  }

  Widget _acessoRestrito() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Acesso restrito', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              SizedBox(height: 8),
              Text('Esta tela é exclusiva do time interno (perfil administrador).', style: TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conteudo() {
    final kpis = ref.watch(kpisClientesAdminProvider);
    final listaAsync = ref.watch(clientesAdminListaProvider(_busca));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Visão consolidada de toda a plataforma — todos os clientes de frota, independente da empresa '
          'selecionada no momento.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        kpis.when(
          data: (k) => Row(
            children: [
              Expanded(child: _cardKpi('Total', '${k.total}')),
              const SizedBox(width: 8),
              Expanded(child: _cardKpi('Ativos', '${k.ativos}')),
              const SizedBox(width: 8),
              Expanded(child: _cardKpi('Outros status', '${k.outros}')),
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _buscaCtrl,
          decoration: const InputDecoration(
            hintText: 'Buscar por nome ou CNPJ...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (v) => setState(() => _busca = v),
          onChanged: (v) {
            if (v.isEmpty) setState(() => _busca = '');
          },
        ),
        const SizedBox(height: 16),
        listaAsync.when(
          data: (lista) {
            if (lista.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Nenhum cliente encontrado.', style: TextStyle(color: Colors.grey))),
              );
            }
            return Column(children: lista.map(_cardCliente).toList());
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        ),
      ],
    );
  }

  Widget _cardKpi(String label, String valor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(valor, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _cardCliente(ClienteCadastro c) {
    final corStatus = switch (c.status) {
      'ativo' || 'trial' => const Color(0xFF15803D),
      'suspenso' => const Color(0xFFB45309),
      _ => const Color(0xFF64748B),
    };
    final alternando = _alternando.contains(c.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.nome, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Text(_formatarCnpj(c.cnpj), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: corStatus.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(statusEmpresaLabel[c.status] ?? c.status,
                      style: TextStyle(fontSize: 10, color: corStatus, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${c.municipio == null ? '—' : '${c.municipio}/${c.uf ?? ''}'} · '
              '${c.plano == null ? 'Sem plano' : (planoLabel[c.plano] ?? c.plano!)}',
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: alternando ? null : () => _alternarAtivo(c),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.status == 'ativo' ? Colors.red : const Color(0xFF15803D),
                ),
                child: Text(alternando ? 'Aguarde...' : (c.status == 'ativo' ? 'Suspender' : 'Ativar')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
