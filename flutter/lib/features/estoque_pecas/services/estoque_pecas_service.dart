import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

// Fase Grupo 1 Rodopar item 2 (03/08/2026) — porta de estoque-pecas/actions.ts.
// O saldo (quantidade_atual) nunca é editado direto: entra sempre via insert
// em pecas_estoque_movimentos, aplicado por trigger no banco (mesma trava
// anti-fraude da web — CHECK quantidade_atual >= 0 bloqueia saída maior que
// o saldo disponível).
class EstoquePecasService {
  final _supabase = SupabaseService.client;

  Future<String> criarPeca({
    required String empresaId,
    required String nome,
    String? codigo,
    required String unidadeMedida,
    required double quantidadeMinima,
    double? quantidadeInicial,
    double? custoUnitario,
    String? criadoPor,
  }) async {
    final peca = await _supabase
        .from('pecas_estoque')
        .insert({
          'empresa_id': empresaId,
          'nome': nome,
          'codigo': codigo,
          'unidade_medida': unidadeMedida,
          'quantidade_minima': quantidadeMinima,
          'criado_por': criadoPor,
        })
        .select('id')
        .single();
    final pecaId = peca['id'] as String;

    if (quantidadeInicial != null && quantidadeInicial > 0) {
      try {
        await _supabase.from('pecas_estoque_movimentos').insert({
          'empresa_id': empresaId,
          'peca_id': pecaId,
          'tipo_movimento': 'entrada',
          'quantidade': quantidadeInicial,
          'custo_unitario': custoUnitario,
          'motivo': 'Estoque inicial',
          'criado_por': criadoPor,
        });
      } catch (e) {
        throw Exception(
            'Peça cadastrada, mas não foi possível lançar o estoque inicial: $e');
      }
    }

    return pecaId;
  }

  // Lança joga o erro de saldo negativo (CHECK 23514 do Postgres) como uma
  // mensagem que faz sentido pro usuário — mesma tradução da web.
  Future<void> registrarMovimento({
    required String pecaId,
    required String empresaId,
    required String tipoMovimento,
    required double quantidade,
    double? custoUnitario,
    String? placa,
    int? manutencaoId,
    String? motivo,
    String? criadoPor,
  }) async {
    try {
      await _supabase.from('pecas_estoque_movimentos').insert({
        'empresa_id': empresaId,
        'peca_id': pecaId,
        'tipo_movimento': tipoMovimento,
        'quantidade': quantidade,
        'custo_unitario': tipoMovimento == 'entrada' ? custoUnitario : null,
        'placa': placa,
        'manutencao_id': manutencaoId,
        'motivo': motivo,
        'criado_por': criadoPor,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23514') {
        throw Exception('Saída maior que o saldo disponível em estoque.');
      }
      throw Exception(e.message);
    }
  }

  Future<void> alterarAtiva(String pecaId, bool ativa) async {
    await _supabase.from('pecas_estoque').update({
      'ativa': ativa,
      'atualizado_em': DateTime.now().toIso8601String()
    }).eq('id', pecaId);
  }
}
