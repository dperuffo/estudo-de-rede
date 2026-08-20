import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase agendamento-patio (04/08/2026, item 8 do benchmark FNI vs KMM, Grupo
// 2) — porta de agendamentos-patio (web) pro PWA Cliente. YMS leve: janela
// de carga (coleta) ou descarga (entrega) agendada pra um frete, no máximo
// 1 de cada tipo por frete. Status "em_andamento"/"concluido" são
// preenchidos sozinhos pela RPC registrar_evento_frete (banco) a partir dos
// checkpoints que o motorista já registra — sem tela nova no PWA motorista.
class AgendamentoPatio {
  final String id;
  final String tipo; // 'coleta' | 'entrega'
  final String? doca;
  final DateTime janelaInicio;
  final DateTime janelaFim;
  final String
      status; // 'agendado' | 'confirmado' | 'em_andamento' | 'concluido' | 'cancelado'
  final String? observacoes;
  final String freteId;
  final String? freteTitulo;

  const AgendamentoPatio({
    required this.id,
    required this.tipo,
    this.doca,
    required this.janelaInicio,
    required this.janelaFim,
    required this.status,
    this.observacoes,
    required this.freteId,
    this.freteTitulo,
  });

  factory AgendamentoPatio.fromMap(Map<String, dynamic> m) {
    final frete = m['fretes'] as Map<String, dynamic>?;
    return AgendamentoPatio(
      id: m['id'] as String,
      tipo: m['tipo'] as String? ?? 'coleta',
      doca: m['doca'] as String?,
      janelaInicio: DateTime.parse(m['janela_inicio'] as String),
      janelaFim: DateTime.parse(m['janela_fim'] as String),
      status: m['status'] as String? ?? 'agendado',
      observacoes: m['observacoes'] as String?,
      freteId: m['frete_id'] as String,
      freteTitulo: frete?['titulo'] as String?,
    );
  }
}

const labelStatusAgendamentoPatio = <String, String>{
  'agendado': 'Agendado',
  'confirmado': 'Confirmado',
  'em_andamento': 'Em andamento',
  'concluido': 'Concluído',
  'cancelado': 'Cancelado',
};

const labelTipoAgendamentoPatio = <String, String>{
  'coleta': 'Carga (coleta)',
  'entrega': 'Descarga (entrega)',
};

// Usado dentro da tela de detalhe do frete: no máximo 2 linhas (1 coleta +
// 1 entrega).
final agendamentosPatioFreteProvider = FutureProvider.autoDispose
    .family<List<AgendamentoPatio>, String>((ref, freteId) async {
  final rows = await SupabaseService.client
      .from('agendamentos_patio')
      .select(
          'id, tipo, doca, janela_inicio, janela_fim, status, observacoes, frete_id')
      .eq('frete_id', freteId);
  return (rows as List)
      .map((r) => AgendamentoPatio.fromMap(r as Map<String, dynamic>))
      .toList();
});

// Usado na agenda do dia: todos os agendamentos da empresa numa data.
final agendamentosPatioDiaProvider = FutureProvider.autoDispose
    .family<List<AgendamentoPatio>, DateTime>((ref, dia) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];

  final inicioDia = DateTime(dia.year, dia.month, dia.day);
  final fimDia = inicioDia.add(const Duration(days: 1));

  final rows = await SupabaseService.client
      .from('agendamentos_patio')
      .select(
          'id, tipo, doca, janela_inicio, janela_fim, status, observacoes, frete_id, fretes(titulo)')
      .eq('empresa_id', empresaId)
      .gte('janela_inicio', inicioDia.toIso8601String())
      .lt('janela_inicio', fimDia.toIso8601String())
      .order('janela_inicio');
  return (rows as List)
      .map((r) => AgendamentoPatio.fromMap(r as Map<String, dynamic>))
      .toList();
});
