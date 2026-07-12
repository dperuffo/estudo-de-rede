import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/dashboard_posto_provider.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _numero = NumberFormat.decimalPattern('pt_BR');
final _dataBr = DateFormat('dd/MM/yyyy');

String _formatarData(String? iso) {
  if (iso == null) return '—';
  try {
    return _dataBr.format(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
}

// Fase FLT-2 — primeira tela real da visão Posto (as outras 16 continuam
// placeholder). Espelha DashboardPosto.tsx da web: indicadores de venda dos
// últimos 30 dias (via RPC resumo_vendas_diarias_posto), desempenho por
// combustível, e indicadores/listas de negociações (negociacoes_postos).
// O gráfico evolutivo diário da web fica pra uma próxima iteração — aqui
// entram números e tabelas, que já cobrem o essencial do painel.
class PostoDashboardScreen extends ConsumerWidget {
  const PostoDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dadosAsync = ref.watch(dashboardPostoProvider);
    final sessao = ref.watch(sessaoProvider).valueOrNull;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(dashboardPostoProvider),
      child: dadosAsync.when(
        loading: () => const Center(child: Padding(
          padding: EdgeInsets.only(top: 80),
          child: CircularProgressIndicator(),
        )),
        error: (e, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.error_outline, size: 40, color: Colors.red),
            const SizedBox(height: 12),
            Text('Não deu pra carregar o painel.\n$e', textAlign: TextAlign.center),
          ],
        ),
        data: (dados) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              sessao?.nomeEmpresa != null ? 'Dashboard — ${sessao!.nomeEmpresa}' : 'Dashboard',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text('Desempenho de vendas e negociações.',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 20),

            _tituloSecao('Vendas — últimos 30 dias'),
            _gradeIndicadores([
              _Indicador('Abastecimentos', _numero.format(dados.totalAbastecimentos)),
              _Indicador('Volume', '${_numero.format(dados.volumeVendido.round())} L'),
              _Indicador('Receita', _moeda.format(dados.receitaVendida)),
              _Indicador('Preço médio', _moeda.format(dados.precoMedioGeral)),
              _Indicador('Ticket médio', _moeda.format(dados.ticketMedio)),
            ]),

            const SizedBox(height: 20),
            _tituloSecao('Desempenho por combustível'),
            if (dados.desempenhoPorCombustivel.isEmpty)
              _cardVazio('Nenhum abastecimento no período.')
            else
              Card(
                child: Column(
                  children: dados.desempenhoPorCombustivel
                      .map((d) => ListTile(
                            dense: true,
                            title: Text(d.combustivel),
                            subtitle: Text(
                              '${_numero.format(d.volume.round())} L · ${_moeda.format(d.precoMedio)}/L',
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_moeda.format(d.receita),
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text('${d.participacao.toStringAsFixed(0)}%',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),

            const SizedBox(height: 20),
            _tituloSecao('Negociações'),
            _gradeIndicadores([
              _Indicador('Aguardando resposta', '${dados.pendentes}'),
              _Indicador('Vigentes', '${dados.vigentes}'),
              _Indicador('Clientes ativos', '${dados.clientesAtivos}'),
              _Indicador('Vol. mín./mês', '${_numero.format(dados.volumeContratado.round())} L'),
            ]),

            const SizedBox(height: 20),
            _tituloSecao('Negociações vigentes agora'),
            if (dados.vigentesLista.isEmpty)
              _cardVazio('Nenhuma negociação vigente no momento.')
            else
              Card(
                child: Column(
                  children: dados.vigentesLista
                      .map((n) => ListTile(
                            dense: true,
                            title: Text(n.clienteNome ?? '—'),
                            subtitle: Text(
                              '${n.combustivel ?? '—'} · ${_formatarData(n.vigenciaInicio)} – ${_formatarData(n.vigenciaFim)}\n'
                              '${n.volumeMinimoMensal != null ? '${_numero.format(n.volumeMinimoMensal!.round())} L/mês' : '—'}'
                              '${n.precoUnitario != null ? ' · ${_moeda.format(n.precoUnitario)}/L' : ''}',
                            ),
                            isThreeLine: true,
                            onTap: () => context.push('/posto/negociacoes'),
                          ))
                      .toList(),
                ),
              ),

            if (dados.pendentesLista.isNotEmpty) ...[
              const SizedBox(height: 20),
              _tituloSecao('Aguardando sua resposta'),
              Card(
                child: Column(
                  children: dados.pendentesLista
                      .map((n) => ListTile(
                            dense: true,
                            title: Text(n.clienteNome ?? '—'),
                            trailing: TextButton(
                              onPressed: () => context.push('/posto/negociacoes'),
                              child: const Text('Responder'),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tituloSecao(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          texto.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      );

  Widget _cardVazio(String texto) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text(texto, style: const TextStyle(color: Colors.grey))),
        ),
      );

  Widget _gradeIndicadores(List<_Indicador> itens) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        children: itens
            .map((i) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(i.label,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(i.valor,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ))
            .toList(),
      );
}

class _Indicador {
  final String label;
  final String valor;
  const _Indicador(this.label, this.valor);
}
