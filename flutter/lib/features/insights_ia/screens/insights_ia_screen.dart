import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/insights_ia_provider.dart';
import '../services/insights_ia_service.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

// Fase FLT-Insights-IA (02/09/2026) — porta de insights-ia/page.tsx.
// Atualizado 1x/dia pelo cron do servidor — não há geração sob demanda
// aqui, só listar/marcar lido/dispensar.
class InsightsIaScreen extends ConsumerWidget {
  const InsightsIaScreen({super.key});

  Future<void> _marcarLido(WidgetRef ref, InsightIA i) async {
    if (i.status != 'novo') return;
    await InsightsIaService().marcarLido(i.id);
    ref.invalidate(insightsIaListaProvider);
  }

  Future<void> _dispensar(BuildContext context, WidgetRef ref, InsightIA i) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dispensar insight'),
        content: const Text(
            'Dispensar este insight? Ele deixará de aparecer na lista.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Voltar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Dispensar')),
        ],
      ),
    );
    if (confirmado != true) return;
    await InsightsIaService().dispensar(i.id);
    ref.invalidate(insightsIaListaProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acesso = ref.watch(insightsIaAcessoProvider);
    final lista = ref.watch(insightsIaListaProvider);

    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Insights de IA')),
      body: acesso.when(
        data: (temAcesso) {
          if (!temAcesso) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                        'Este recurso está disponível para empresas no plano Enterprise, ou com liberação manual. Fale com o time comercial para saber mais.',
                        style: TextStyle(color: Colors.grey.shade600)),
                  ),
                ),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(insightsIaListaProvider),
            child: lista.when(
              data: (insights) {
                final novos = insights.where((i) => i.status == 'novo');
                final impactoNovos = novos.fold<double>(
                    0, (s, i) => s + (i.valorImpactoEstimado ?? 0));
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                        'Sinais cruzados entre combustível, manutenção, pneus, sinistros, multas, aprovações, seguro e motoristas — gerados 1x/dia.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text('${novos.length}',
                                      style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold)),
                                  Text('Novos',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(_moeda.format(impactoNovos),
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                  Text('Impacto estimado (novos)',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (insights.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                              'Nenhum insight no momento. Volte amanhã — os sinais são atualizados 1x por dia.',
                              style: TextStyle(color: Colors.grey.shade600)),
                        ),
                      )
                    else
                      ...insights.map((i) => _card(context, ref, i)),
                  ],
                );
              },
              loading: () => const Center(
                  child: Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: CircularProgressIndicator())),
              error: (e, _) => ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text('Não deu pra carregar: $e', textAlign: TextAlign.center)
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Não deu pra carregar: $e')),
      ),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, InsightIA i) {
    final corSeveridade = switch (i.severidade) {
      'critica' => Colors.red.shade700,
      'alta' => Colors.orange.shade700,
      'media' => Colors.amber.shade700,
      _ => Colors.blueGrey,
    };
    final labelSeveridade = switch (i.severidade) {
      'critica' => 'Crítica',
      'alta' => 'Alta',
      'media' => 'Média',
      _ => 'Baixa',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _marcarLido(ref, i),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: corSeveridade.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(labelSeveridade,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: corSeveridade)),
                  ),
                  const SizedBox(width: 6),
                  if (i.status == 'novo')
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Text('Novo',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1D4ED8))),
                    ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Dispensar',
                    onPressed: () => _dispensar(context, ref, i),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(i.titulo,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(categoriaLabel[i.categoria] ?? i.categoria,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 6),
              Text(i.descricao, style: const TextStyle(fontSize: 13)),
              if (i.recomendacao != null && i.recomendacao!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Recomendação: ${i.recomendacao}',
                    style: const TextStyle(
                        fontSize: 12, fontStyle: FontStyle.italic)),
              ],
              if (i.valorImpactoEstimado != null) ...[
                const SizedBox(height: 6),
                Text(
                    'Impacto estimado: ${_moeda.format(i.valorImpactoEstimado)}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
