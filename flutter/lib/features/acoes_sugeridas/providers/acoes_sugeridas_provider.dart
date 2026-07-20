import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-Ações-Sugeridas — porta de acoes-sugeridas/page.tsx. Mesmo
// escopo reduzido do que já foi feito em Anomalias (Fase FLT-3): sem
// seletor de cliente (a sessão já resolve a empresa) e sem paginação de
// verdade (traz até 100, suficiente pro celular).
const tipoLabelAcaoSugerida = {
  'cnh_vencida': 'CNH vencida',
  'posto_acima_media': 'Posto acima da média',
  'hodometro_fora_padrao': 'Hodômetro fora do padrão',
  'volume_tanque': 'Volume acima do tanque',
  'geo_distancia': 'Postos distantes no mesmo dia',
  'preco_regiao': 'Preço fora da média regional',
};

// Mesmo texto de confirmação por tipo da web (CardAcaoSugerida.tsx) —
// mostrado antes de aprovar/executar, pra deixar claro que a ação é real
// (bloqueia motorista, remove posto, cadastra regra) e não reversível com
// um simples toque.
const confirmacaoPorTipoAcaoSugerida = {
  'cnh_vencida': 'Bloquear este motorista agora? O status dele vai para Inativo até você reverter manualmente.',
  'posto_acima_media': 'Remover este posto da rede negociada agora? Ele deixa de contar como posto ativo da empresa.',
  'hodometro_fora_padrao': 'Cadastrar esse limite de variação de hodômetro para a placa agora?',
  'volume_tanque': 'Cadastrar esse limite de volume diário para a placa agora?',
  'geo_distancia': 'Cadastrar esse intervalo mínimo entre abastecimentos para a placa agora?',
  'preco_regiao': 'Marcar todos os abastecimentos com preço fora da média desta placa como revisados?',
};

class AcaoSugerida {
  final int id;
  final String tipo;
  final String alvoTipo;
  final String alvoLabel;
  final String titulo;
  final String descricao;
  final String severidade;
  final String status;
  final String? decididoEm;
  final String? decididoPor;
  final String? erroExecucao;
  final String criadoEm;

  const AcaoSugerida({
    required this.id,
    required this.tipo,
    required this.alvoTipo,
    required this.alvoLabel,
    required this.titulo,
    required this.descricao,
    required this.severidade,
    required this.status,
    this.decididoEm,
    this.decididoPor,
    this.erroExecucao,
    required this.criadoEm,
  });

  factory AcaoSugerida.fromMap(Map<String, dynamic> m) {
    return AcaoSugerida(
      id: (m['id'] as num).toInt(),
      tipo: m['tipo'] as String? ?? '',
      alvoTipo: m['alvo_tipo'] as String? ?? '',
      alvoLabel: m['alvo_label'] as String? ?? '',
      titulo: m['titulo'] as String? ?? '',
      descricao: m['descricao'] as String? ?? '',
      severidade: m['severidade'] as String? ?? '',
      status: m['status'] as String? ?? '',
      decididoEm: m['decidido_em'] as String?,
      decididoPor: m['decidido_por'] as String?,
      erroExecucao: m['erro_execucao'] as String?,
      criadoEm: m['criado_em'] as String,
    );
  }
}

class FiltrosAcoesSugeridas {
  final String? tipo;
  // 'pendentes' | 'decididas' | 'todas'
  final String status;
  const FiltrosAcoesSugeridas({this.tipo, this.status = 'pendentes'});

  @override
  bool operator ==(Object other) =>
      other is FiltrosAcoesSugeridas && other.tipo == tipo && other.status == status;
  @override
  int get hashCode => Object.hash(tipo, status);
}

final acoesSugeridasProvider =
    FutureProvider.autoDispose.family<List<AcaoSugerida>, FiltrosAcoesSugeridas>((ref, filtros) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];

  var query = SupabaseService.client
      .from('acoes_sugeridas')
      .select(
          'id, tipo, alvo_tipo, alvo_label, titulo, descricao, severidade, status, decidido_em, decidido_por, erro_execucao, criado_em')
      .eq('empresa_id', empresaId);

  if (filtros.tipo != null) query = query.eq('tipo', filtros.tipo!);
  if (filtros.status == 'pendentes') query = query.eq('status', 'pendente');
  if (filtros.status == 'decididas') query = query.neq('status', 'pendente');

  final rows = await query.order('severidade', ascending: true).order('criado_em', ascending: false).limit(100);
  return (rows as List).map((m) => AcaoSugerida.fromMap(m as Map<String, dynamic>)).toList();
});

class KpisAcoesSugeridas {
  final int pendentes;
  final int criticasPendentes;
  const KpisAcoesSugeridas({required this.pendentes, required this.criticasPendentes});
}

final kpisAcoesSugeridasProvider = FutureProvider.autoDispose<KpisAcoesSugeridas>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return const KpisAcoesSugeridas(pendentes: 0, criticasPendentes: 0);

  final rows = await SupabaseService.client
      .from('acoes_sugeridas')
      .select('severidade')
      .eq('empresa_id', empresaId)
      .eq('status', 'pendente') as List;

  final criticas = rows.where((r) => (r as Map<String, dynamic>)['severidade'] == 'critica').length;
  return KpisAcoesSugeridas(pendentes: rows.length, criticasPendentes: criticas);
});
