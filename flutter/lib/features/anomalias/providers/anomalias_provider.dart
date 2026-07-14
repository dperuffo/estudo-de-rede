import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — Anomalias (cliente), porta de anomalias/page.tsx +
// actions.ts. RLS conferida antes de portar: `anomalias_abastecimento` tem
// self-service COMPLETO (select/update/insert/delete) via
// `empresas_do_usuario` — o cliente pode ler e revisar as próprias
// anomalias direto, sem RPC (mesmo padrão da web). A detecção
// (`detectar_anomalias_abastecimento`) é SECURITY DEFINER mas sempre
// chamada aqui com `p_empresa_id` preenchido (nunca null — o "rodar pra
// todos os clientes" é só do admin, fora de escopo do lado cliente).
//
// Escopo reduzido: sem seletor de cliente (a web mostra isso pro admin
// escolher; aqui a sessão já resolve a empresa sozinha) e sem paginação de
// verdade (a web pagina 30 em 30; aqui traz até 100, suficiente pro
// celular).
const tipoLabelAnomalia = {
  'volume_tanque': 'Volume x tanque',
  'geo_distancia': 'Postos distantes',
  'hodometro': 'Hodômetro',
  'preco_regiao': 'Preço regional',
};

class Anomalia {
  final int id;
  final String tipo;
  final String severidade;
  final String? placa;
  final String? motoristaNome;
  final String? dataAbastecimento;
  final String descricao;
  final String? revisadoEm;
  final String? revisadoPor;
  final String criadoEm;

  const Anomalia({
    required this.id,
    required this.tipo,
    required this.severidade,
    this.placa,
    this.motoristaNome,
    this.dataAbastecimento,
    required this.descricao,
    this.revisadoEm,
    this.revisadoPor,
    required this.criadoEm,
  });

  factory Anomalia.fromMap(Map<String, dynamic> m) {
    return Anomalia(
      id: (m['id'] as num).toInt(),
      tipo: m['tipo'] as String? ?? '',
      severidade: m['severidade'] as String? ?? '',
      placa: m['placa'] as String?,
      motoristaNome: m['motorista_nome'] as String?,
      dataAbastecimento: m['data_abastecimento'] as String?,
      descricao: m['descricao'] as String? ?? '',
      revisadoEm: m['revisado_em'] as String?,
      revisadoPor: m['revisado_por'] as String?,
      criadoEm: m['criado_em'] as String,
    );
  }
}

class FiltrosAnomalias {
  final String? tipo;
  // 'pendentes' | 'revisadas' | 'todas'
  final String status;
  const FiltrosAnomalias({this.tipo, this.status = 'pendentes'});

  @override
  bool operator ==(Object other) =>
      other is FiltrosAnomalias && other.tipo == tipo && other.status == status;
  @override
  int get hashCode => Object.hash(tipo, status);
}

final anomaliasProvider =
    FutureProvider.autoDispose.family<List<Anomalia>, FiltrosAnomalias>((ref, filtros) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];

  var query = SupabaseService.client
      .from('anomalias_abastecimento')
      .select('id, tipo, severidade, placa, motorista_nome, data_abastecimento, descricao, revisado_em, revisado_por, criado_em')
      .eq('empresa_id', empresaId);

  if (filtros.tipo != null) query = query.eq('tipo', filtros.tipo!);
  if (filtros.status == 'pendentes') query = query.isFilter('revisado_em', null);
  if (filtros.status == 'revisadas') query = query.not('revisado_em', 'is', null);

  final rows = await query.order('criado_em', ascending: false).limit(100);
  return (rows as List).map((m) => Anomalia.fromMap(m as Map<String, dynamic>)).toList();
});

class KpisAnomalias {
  final int naoRevisadas;
  final int criticasNaoRevisadas;
  const KpisAnomalias({required this.naoRevisadas, required this.criticasNaoRevisadas});
}

final kpisAnomaliasProvider = FutureProvider.autoDispose<KpisAnomalias>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return const KpisAnomalias(naoRevisadas: 0, criticasNaoRevisadas: 0);

  final rows = await SupabaseService.client
      .from('anomalias_abastecimento')
      .select('severidade')
      .eq('empresa_id', empresaId)
      .isFilter('revisado_em', null) as List;

  final criticas = rows.where((r) => (r as Map<String, dynamic>)['severidade'] == 'critica').length;
  return KpisAnomalias(naoRevisadas: rows.length, criticasNaoRevisadas: criticas);
});
