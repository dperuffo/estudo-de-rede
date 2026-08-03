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
