import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/agendamentos_patio_provider.dart';

import '../../../core/theme/app_theme.dart';

const _corStatus = <String, Color>{
  'agendado': Color(0xFFFEF3C7),
  'confirmado': Color(0xFFDBEAFE),
  'em_andamento': Color(0xFFEDE9FE),
  'concluido': Color(0xFFDCFCE7),
  'cancelado': Color(0xFFF1F5F9),
};
const _corTextoStatus = <String, Color>{
  'agendado': Color(0xFF92400E),
  'confirmado': Color(0xFF1E40AF),
  'em_andamento': Color(0xFF5B21B6),
  'concluido': Color(0xFF166534),
  'cancelado': Color(0xFF475569),
};

// Fase agendamento-patio (04/08/2026) — porta de agendamentos-patio/page.tsx
// (web): agenda do dia com todas as janelas de carga/descarga marcadas.
// Sem seletor de empresa aqui (o app já opera por sessão de 1 empresa).
class AgendamentosPatioScreen extends ConsumerStatefulWidget {
  const AgendamentosPatioScreen({super.key});

  @override
  ConsumerState<AgendamentosPatioScreen> createState() =>
      _AgendamentosPatioScreenState();
}

class _AgendamentosPatioScreenState
    extends ConsumerState<AgendamentosPatioScreen> {
  DateTime _dia = DateTime.now();

  DateTime get _diaSemHora => DateTime(_dia.year, _dia.month, _dia.day);

  String _formatarDia(DateTime d) {
    const meses = [
      'jan',
      'fev',
      'mar',
      'abr',
      'mai',
      'jun',
      'jul',
      'ago',
      'set',
      'out',
      'nov',
      'dez'
    ];
    return '${d.day.toString().padLeft(2, '0')} ${meses[d.month - 1]}';
  }

  String _formatarHora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final agendamentosAsync =
        ref.watch(agendamentosPatioDiaProvider(_diaSemHora));

    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Agendamento de Pátio')),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(agendamentosPatioDiaProvider(_diaSemHora)),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Janelas de carga (coleta) e descarga (entrega) marcadas pros fretes do dia. Status "em andamento" e '
              '"concluído" são preenchidos sozinhos quando o motorista bate o checkpoint no app dele.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(
                      () => _dia = _dia.subtract(const Duration(days: 1))),
                ),
                Text(_formatarDia(_dia),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () =>
                      setState(() => _dia = _dia.add(const Duration(days: 1))),
                ),
                TextButton(
                    onPressed: () => setState(() => _dia = DateTime.now()),
                    child: const Text('Hoje')),
              ],
            ),
            const SizedBox(height: 8),
            agendamentosAsync.when(
              loading: () => const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Erro ao carregar: $e')),
              data: (agendamentos) {
                final agora = DateTime.now();
                final atrasados = agendamentos
                    .where((a) =>
                        ['agendado', 'confirmado'].contains(a.status) &&
                        a.janelaFim.isBefore(agora))
                    .length;
                final confirmados =
                    agendamentos.where((a) => a.status == 'confirmado').length;
                final emAndamento = agendamentos
                    .where((a) => a.status == 'em_andamento')
                    .length;

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: _cardResumo(
                                'No dia', '${agendamentos.length}', null)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _cardResumo(
                                'Confirmados', '$confirmados', Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                            child: _cardResumo('Em andamento', '$emAndamento',
                                Colors.deepPurple)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _cardResumo('Atrasados', '$atrasados',
                                atrasados > 0 ? Colors.red : null)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (agendamentos.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Text(
                            'Nenhum agendamento pra este dia. Agende dentro da tela de um frete.',
                            style: TextStyle(color: Colors.black54)),
                      )
                    else
                      ...agendamentos.map((a) {
                        final atrasado =
                            ['agendado', 'confirmado'].contains(a.status) &&
                                a.janelaFim.isBefore(agora);
                        return Card(
                          child: ListTile(
                            onTap: () => context.push('/fretes/${a.freteId}'),
                            title: Text(a.freteTitulo ?? 'Frete'),
                            subtitle: Text(
                              '${labelTipoAgendamentoPatio[a.tipo] ?? a.tipo} · ${_formatarHora(a.janelaInicio)}–${_formatarHora(a.janelaFim)}'
                              '${a.doca != null ? ' · doca ${a.doca}' : ''}',
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _corStatus[a.status] ??
                                        const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    labelStatusAgendamentoPatio[a.status] ??
                                        a.status,
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: _corTextoStatus[a.status] ??
                                            Colors.black54),
                                  ),
                                ),
                                if (atrasado)
                                  const Padding(
                                      padding: EdgeInsets.only(top: 3),
                                      child: Text('Atrasado',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.red))),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardResumo(String label, String valor, Color? cor) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(fontSize: 10.5, color: Colors.black45)),
              const SizedBox(height: 2),
              Text(valor,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: cor ?? Colors.black87)),
            ],
          ),
        ),
      );
}
