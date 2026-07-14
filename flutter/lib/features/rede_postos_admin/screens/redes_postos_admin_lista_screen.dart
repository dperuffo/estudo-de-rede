import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/rede_postos_admin_provider.dart';

// Fase FLT-4 — Rede de Postos (admin, consolidada): lista de TODAS as
// Redes do sistema, porta de rede-postos/page.tsx. Ver escopo completo em
// rede_postos_admin_provider.dart.
class RedesPostosAdminListaScreen extends ConsumerWidget {
  const RedesPostosAdminListaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessaoProvider).valueOrNull;
    final ehAdmin = sessao?.ehAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Rede de Postos (todas)')),
      floatingActionButton: !ehAdmin
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/redes-postos/nova'),
              icon: const Icon(Icons.add),
              label: const Text('Nova Rede'),
            ),
      body: !ehAdmin ? _acessoRestrito() : _conteudo(context, ref),
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

  Widget _conteudo(BuildContext context, WidgetRef ref) {
    final kpis = ref.watch(kpisRedesPostosProvider);
    final listaAsync = ref.watch(redesPostosAdminListaProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Visão consolidada de toda a plataforma — todas as Redes de Postos (bandeiras/grupos), '
          'independente de quem as criou.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        kpis.when(
          data: (k) => Row(
            children: [
              Expanded(child: _cardKpi('Total de redes', '${k.total}')),
              const SizedBox(width: 12),
              Expanded(child: _cardKpi('Ativas', '${k.ativas}')),
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox(),
        ),
        const SizedBox(height: 16),
        listaAsync.when(
          data: (lista) {
            if (lista.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Nenhuma Rede de Postos cadastrada ainda.', style: TextStyle(color: Colors.grey))),
              );
            }
            return Column(children: lista.map((r) => _cardRede(context, r)).toList());
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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(valor, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _cardRede(BuildContext context, RedePostoResumo r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('/redes-postos/${r.id}'),
        title: Text(r.nome, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CNPJ matriz: ${r.cnpjMatriz ?? '—'} · ${r.totalPostos} posto(s) vinculado(s)', style: const TextStyle(fontSize: 11)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: r.ativo ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  r.ativo ? 'Ativa' : 'Inativa',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: r.ativo ? const Color(0xFF15803D) : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
