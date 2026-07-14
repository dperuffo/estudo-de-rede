import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/grupo_economico_admin_provider.dart';

// Fase FLT-4 — Grupo Econômico (admin, consolidado): lista de TODOS os
// grupos do sistema, porta de grupo-economico/page.tsx. Ver escopo
// completo em grupo_economico_admin_provider.dart.
class GruposEconomicosAdminListaScreen extends ConsumerWidget {
  const GruposEconomicosAdminListaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessao = ref.watch(sessaoProvider).valueOrNull;
    final ehAdmin = sessao?.ehAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Grupo Econômico (todos)')),
      floatingActionButton: !ehAdmin
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/grupos-economicos/novo'),
              icon: const Icon(Icons.add),
              label: const Text('Novo Grupo'),
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
    final kpis = ref.watch(kpisGruposEconomicosProvider);
    final listaAsync = ref.watch(gruposEconomicosAdminListaProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Visão consolidada de toda a plataforma — todos os Grupos Econômicos de clientes de frota, '
          'independente de quem os criou. Diferente de Rede de Postos, aqui só o time interno cria/edita/vincula.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        kpis.when(
          data: (k) => Row(
            children: [
              Expanded(child: _cardKpi('Total de grupos', '${k.total}')),
              const SizedBox(width: 12),
              Expanded(child: _cardKpi('Ativos', '${k.ativos}')),
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
                child: Center(child: Text('Nenhum Grupo Econômico cadastrado ainda.', style: TextStyle(color: Colors.grey))),
              );
            }
            return Column(children: lista.map((g) => _cardGrupo(context, g)).toList());
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

  Widget _cardGrupo(BuildContext context, GrupoEconomicoResumo g) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('/grupos-economicos/${g.id}'),
        title: Text(g.nome, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CNPJ matriz: ${g.cnpjMatriz ?? '—'} · ${g.totalEmpresas} empresa(s) vinculada(s)', style: const TextStyle(fontSize: 11)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: g.ativo ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  g.ativo ? 'Ativo' : 'Inativo',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: g.ativo ? const Color(0xFF15803D) : const Color(0xFF64748B)),
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
