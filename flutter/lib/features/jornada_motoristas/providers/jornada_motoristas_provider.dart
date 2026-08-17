import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase Painel-Jornada-Motorista (17/08/2026, pedido do Daniel: "crie um
// painel na visao do gestor, web e PWA, para controle da jornada do
// motorista, trazendo indicadores e graficos com os dados registrados nas
// jornadas dos motoristas dos clientes") — porta de jornada-motoristas/
// page.tsx (web). Duas RPCs, ambas SECURITY INVOKER (dependem só do RLS já
// existente em motoristas_jornada_eventos/motoristas, mesmo espírito de
// indicadores_frota_provider.dart):
// 1) jornada_motorista_status_atual — snapshot "ao vivo" por motorista.
// 2) jornada_motorista_indicadores_diarios — histórico agregado por dia,
//    com alertas de aderência à Lei do Motorista (13.103/2015).

class StatusAtualMotorista {
  final String motoristaId;
  final String nomeCompleto;
  final String estado; // 'dirigindo' | 'pausa' | 'descanso' | 'nunca_iniciado'
  final String? ultimoEvento;
  final DateTime? desde;
  final int? duracaoMinutos;
  final bool excedeuLimite;

  const StatusAtualMotorista({
    required this.motoristaId,
    required this.nomeCompleto,
    required this.estado,
    this.ultimoEvento,
    this.desde,
    this.duracaoMinutos,
    required this.excedeuLimite,
  });

  factory StatusAtualMotorista.fromMap(Map<String, dynamic> m) => StatusAtualMotorista(
        motoristaId: m['motorista_id'] as String,
        nomeCompleto: m['nome_completo'] as String,
        estado: m['estado'] as String,
        ultimoEvento: m['ultimo_evento'] as String?,
        desde: m['desde'] != null ? DateTime.parse(m['desde'] as String) : null,
        duracaoMinutos: (m['duracao_minutos'] as num?)?.toInt(),
        excedeuLimite: m['excedeu_limite'] as bool? ?? false,
      );
}

final statusAtualJornadaProvider = FutureProvider.autoDispose<List<StatusAtualMotorista>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client.rpc('jornada_motorista_status_atual', params: {
    'p_empresa_id': empresaId,
  }) as List;
  return rows.map((r) => StatusAtualMotorista.fromMap(r as Map<String, dynamic>)).toList();
});

class IndicadorDiarioMotorista {
  final String motoristaId;
  final String nomeCompleto;
  final DateTime dia;
  final double horasDirigidas;
  final double horasPausa;
  final double horasDescanso;
  final int numPausas;
  final int alertasConducaoContinua;
  final int alertasDescansoInsuficiente;

  const IndicadorDiarioMotorista({
    required this.motoristaId,
    required this.nomeCompleto,
    required this.dia,
    required this.horasDirigidas,
    required this.horasPausa,
    required this.horasDescanso,
    required this.numPausas,
    required this.alertasConducaoContinua,
    required this.alertasDescansoInsuficiente,
  });

  factory IndicadorDiarioMotorista.fromMap(Map<String, dynamic> m) => IndicadorDiarioMotorista(
        motoristaId: m['motorista_id'] as String,
        nomeCompleto: m['nome_completo'] as String,
        dia: DateTime.parse(m['dia'] as String),
        horasDirigidas: (m['horas_dirigidas'] as num?)?.toDouble() ?? 0,
        horasPausa: (m['horas_pausa'] as num?)?.toDouble() ?? 0,
        horasDescanso: (m['horas_descanso'] as num?)?.toDouble() ?? 0,
        numPausas: (m['num_pausas'] as num?)?.toInt() ?? 0,
        alertasConducaoContinua: (m['alertas_conducao_continua'] as num?)?.toInt() ?? 0,
        alertasDescansoInsuficiente: (m['alertas_descanso_insuficiente'] as num?)?.toInt() ?? 0,
      );
}

typedef FiltroJornada = ({String dataInicio, String dataFim});

final indicadoresJornadaProvider = FutureProvider.autoDispose.family<List<IndicadorDiarioMotorista>, FiltroJornada>((ref, filtro) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client.rpc('jornada_motorista_indicadores_diarios', params: {
    'p_empresa_id': empresaId,
    'p_data_inicio': filtro.dataInicio,
    'p_data_fim': filtro.dataFim,
  }) as List;
  return rows.map((r) => IndicadorDiarioMotorista.fromMap(r as Map<String, dynamic>)).toList();
});

// Fase Painel-Jornada-Motorista (17/08/2026, pedido do Daniel: "senti falta
// de um relatório que traga os tempos registrados... como se fosse um
// tracking por motorista") — porta de jornada_motorista_registro_detalhado
// (web). 1 linha por segmento (trecho contínuo dirigindo/pausa/descanso
// entre dois eventos consecutivos), pra montar uma timeline por motorista.
class RegistroDetalhadoMotorista {
  final String motoristaId;
  final String nomeCompleto;
  final String tipoSegmento; // 'dirigindo' | 'pausa' | 'descanso'
  final DateTime inicio;
  final DateTime fim;
  final int duracaoMinutos;
  final bool emAndamento;

  const RegistroDetalhadoMotorista({
    required this.motoristaId,
    required this.nomeCompleto,
    required this.tipoSegmento,
    required this.inicio,
    required this.fim,
    required this.duracaoMinutos,
    required this.emAndamento,
  });

  factory RegistroDetalhadoMotorista.fromMap(Map<String, dynamic> m) => RegistroDetalhadoMotorista(
        motoristaId: m['motorista_id'] as String,
        nomeCompleto: m['nome_completo'] as String,
        tipoSegmento: m['tipo_segmento'] as String,
        inicio: DateTime.parse(m['inicio'] as String),
        fim: DateTime.parse(m['fim'] as String),
        duracaoMinutos: (m['duracao_minutos'] as num?)?.toInt() ?? 0,
        emAndamento: m['em_andamento'] as bool? ?? false,
      );
}

final registroDetalhadoJornadaProvider = FutureProvider.autoDispose.family<List<RegistroDetalhadoMotorista>, FiltroJornada>((ref, filtro) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client.rpc('jornada_motorista_registro_detalhado', params: {
    'p_empresa_id': empresaId,
    'p_data_inicio': filtro.dataInicio,
    'p_data_fim': filtro.dataFim,
  }) as List;
  return rows.map((r) => RegistroDetalhadoMotorista.fromMap(r as Map<String, dynamic>)).toList();
});
