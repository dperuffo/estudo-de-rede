import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase Torre-de-Controle-Leve (03/08/2026) — porta de torre-de-controle/page.tsx
// (web, Grupo 1 item 1 do benchmark FNI vs KMM) pro PWA Cliente. Mesma RPC
// (fretes_em_andamento_empresa, SECURITY DEFINER), mesmo espírito "leve": não
// é rastreamento por GPS, só agrega o último checkpoint que o motorista
// confirmou em fretes_eventos, com alerta de prazo e de pânico.
class FreteAndamento {
  final String id;
  final String titulo;
  final String status;
  final String origemLabel;
  final String destinoLabel;
  final String? motoristaId;
  final String? nomeMotorista;
  final String? telefoneMotorista;
  final DateTime criadoEm;
  final DateTime? prazoLimite;
  final String? ultimoEventoTipo;
  final DateTime? ultimoEventoEm;
  final String? ultimoEventoObservacao;
  final bool tevePanico;

  const FreteAndamento({
    required this.id,
    required this.titulo,
    required this.status,
    required this.origemLabel,
    required this.destinoLabel,
    this.motoristaId,
    this.nomeMotorista,
    this.telefoneMotorista,
    required this.criadoEm,
    this.prazoLimite,
    this.ultimoEventoTipo,
    this.ultimoEventoEm,
    this.ultimoEventoObservacao,
    required this.tevePanico,
  });

  factory FreteAndamento.fromMap(Map<String, dynamic> m) => FreteAndamento(
        id: m['id'] as String,
        titulo: m['titulo'] as String,
        status: m['status'] as String,
        origemLabel: (m['origem_label'] as String?) ?? '',
        destinoLabel: (m['destino_label'] as String?) ?? '',
        motoristaId: m['motorista_id'] as String?,
        nomeMotorista: m['nome_motorista'] as String?,
        telefoneMotorista: m['telefone_motorista'] as String?,
        criadoEm: DateTime.parse(m['criado_em'] as String),
        prazoLimite: m['prazo_limite'] != null ? DateTime.parse(m['prazo_limite'] as String) : null,
        ultimoEventoTipo: m['ultimo_evento_tipo'] as String?,
        ultimoEventoEm: m['ultimo_evento_em'] != null ? DateTime.parse(m['ultimo_evento_em'] as String) : null,
        ultimoEventoObservacao: m['ultimo_evento_observacao'] as String?,
        tevePanico: (m['teve_panico'] as bool?) ?? false,
      );

  bool get atrasado => prazoLimite != null && prazoLimite!.isBefore(DateTime.now());

  bool get vencendoEmBreve {
    if (atrasado || prazoLimite == null) return false;
    return prazoLimite!.difference(DateTime.now()) <= const Duration(hours: 6);
  }
}

final torreDeControleProvider = FutureProvider.autoDispose<List<FreteAndamento>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client.rpc('fretes_em_andamento_empresa', params: {
    'p_empresa_id': empresaId,
  }) as List;
  return rows.map((r) => FreteAndamento.fromMap(r as Map<String, dynamic>)).toList();
});

// Fase Grupo 2 (Rodopar/Datapar, item 4, 03/08/2026) — mapa ao vivo,
// alimentado pelo endpoint GENÉRICO de ingestão GPS
// (/api/integracoes/gps, escopo gps:write) — qualquer sistema de
// rastreamento (Sascar, Positron, Onixsat, Autotrac ou outro) que o
// cliente conectar. Porta de torre-de-controle/page.tsx (web).
class PosicaoVeiculo {
  final String placa;
  final double lat;
  final double lon;
  final double? velocidadeKmh;
  final DateTime timestampGps;
  final String? provedor;

  const PosicaoVeiculo({
    required this.placa,
    required this.lat,
    required this.lon,
    this.velocidadeKmh,
    required this.timestampGps,
    this.provedor,
  });

  factory PosicaoVeiculo.fromMap(Map<String, dynamic> m) => PosicaoVeiculo(
        placa: m['placa'] as String,
        lat: (m['lat'] as num).toDouble(),
        lon: (m['lon'] as num).toDouble(),
        velocidadeKmh: (m['velocidade_kmh'] as num?)?.toDouble(),
        timestampGps: DateTime.parse(m['timestamp_gps'] as String),
        provedor: m['provedor'] as String?,
      );
}

final posicoesVeiculosProvider = FutureProvider.autoDispose<List<PosicaoVeiculo>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client
      .from('veiculos_posicoes')
      .select('placa, lat, lon, velocidade_kmh, timestamp_gps, provedor')
      .eq('empresa_id', empresaId)
      .order('timestamp_gps', ascending: false)
      .limit(500) as List;

  // Última posição por placa — mesmo dedupe em memória da web (sem
  // DISTINCT ON via PostgREST).
  final ultimaPorPlaca = <String, PosicaoVeiculo>{};
  for (final r in rows) {
    final p = PosicaoVeiculo.fromMap(r as Map<String, dynamic>);
    ultimaPorPlaca.putIfAbsent(p.placa, () => p);
  }
  return ultimaPorPlaca.values.toList();
});
