import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase 27.15x — "Regras Antifraude" (PWA), porta de
// src/app/(dashboard)/antifraude/* (web). Diferente de Parâmetros de Uso
// (10 tabelas, uma por tipo), aqui os 3 tipos moram na MESMA tabela
// (regras_antifraude, condições em jsonb) — 1 único model + 1 único
// provider (family por tipo, mesmo padrão de variacoesHodometroProvider em
// parametros_uso_provider.dart).

const tiposRegraAntifraude = [
  ('limite_valor_quantidade', 'Limite de valor/quantidade'),
  ('janela_tempo_frequencia', 'Janela de tempo/frequência'),
  ('localizacao_posto', 'Localização/posto'),
];

const labelEscopoAntifraude = {
  'motorista': 'Motorista',
  'veiculo': 'Veículo',
  'empresa': 'Empresa toda',
};

class RegraAntifraudeRow {
  final String id;
  final String nome;
  final String tipo;
  final String escopo;
  final String? escopoReferencia;
  final Map<String, dynamic> condicoes;
  final String vigenciaInicio;
  final String? vigenciaFim;
  final String status;

  const RegraAntifraudeRow({
    required this.id,
    required this.nome,
    required this.tipo,
    required this.escopo,
    this.escopoReferencia,
    required this.condicoes,
    required this.vigenciaInicio,
    this.vigenciaFim,
    required this.status,
  });

  bool get ativo => status == 'Ativo';

  factory RegraAntifraudeRow.fromMap(Map<String, dynamic> m) {
    return RegraAntifraudeRow(
      id: m['id'] as String,
      nome: m['nome'] as String? ?? '',
      tipo: m['tipo'] as String? ?? '',
      escopo: m['escopo'] as String? ?? 'empresa',
      escopoReferencia: m['escopo_referencia'] as String?,
      condicoes: (m['condicoes'] as Map?)?.cast<String, dynamic>() ?? const {},
      vigenciaInicio: m['vigencia_inicio'] as String? ?? '',
      vigenciaFim: m['vigencia_fim'] as String?,
      status: m['status'] as String? ?? 'Ativo',
    );
  }
}

final regrasAntifraudeProvider =
    FutureProvider.autoDispose.family<List<RegraAntifraudeRow>, String>((ref, tipo) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];

  final rows = await SupabaseService.client
      .from('regras_antifraude')
      .select('id, nome, tipo, escopo, escopo_referencia, condicoes, vigencia_inicio, vigencia_fim, status')
      .eq('empresa_id', empresaId)
      .eq('tipo', tipo)
      .order('criado_em', ascending: false) as List;

  return rows.map((r) => RegraAntifraudeRow.fromMap(r as Map<String, dynamic>)).toList();
});

// Contagem de falhas de verificação (fail-open) ainda não lidas — mesma
// tabela usada pro badge no menu da web (antifraude_verificacoes_falhas).
final falhasVerificacaoAntifraudeCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  if (sessao.empresaId == null) return 0;
  final resp = await SupabaseService.client
      .from('antifraude_verificacoes_falhas')
      .select('id')
      .isFilter('lida_em', null)
      .count(CountOption.exact);
  return resp.count;
});
