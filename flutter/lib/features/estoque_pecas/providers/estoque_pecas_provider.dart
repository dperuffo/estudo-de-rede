import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase Grupo 1 Rodopar item 2 (03/08/2026, benchmark FNI vs Rodopar/Datapar)
// — Estoque de Peças na Manutenção (cliente), porta de estoque-pecas/page.tsx
// + [id]/page.tsx + actions.ts + src/lib/estoquePecas.ts. quantidade_atual e
// custo_unitario_medio NUNCA são escritos direto — só via insert em
// pecas_estoque_movimentos (ledger imutável), aplicado por trigger no banco
// (mesma trava anti-fraude da web: CHECK quantidade_atual >= 0).

const tipoMovimentoLabel = {'entrada': 'Entrada', 'saida': 'Saída'};

const tipoMovimentoCorFundo = {'entrada': Color(0xFFDCFCE7), 'saida': Color(0xFFFEE2E2)};
const tipoMovimentoCorTexto = {'entrada': Color(0xFF166534), 'saida': Color(0xFF991B1B)};

class PecaEstoque {
  final String id;
  final String empresaId;
  final String nome;
  final String? codigo;
  final String unidadeMedida;
  final double quantidadeAtual;
  final double quantidadeMinima;
  final double? custoUnitarioMedio;
  final bool ativa;

  const PecaEstoque({
    required this.id,
    required this.empresaId,
    required this.nome,
    this.codigo,
    required this.unidadeMedida,
    required this.quantidadeAtual,
    required this.quantidadeMinima,
    this.custoUnitarioMedio,
    required this.ativa,
  });

  bool get abaixoDoMinimo => quantidadeAtual <= quantidadeMinima;

  factory PecaEstoque.fromMap(Map<String, dynamic> m) => PecaEstoque(
        id: m['id'] as String,
        empresaId: m['empresa_id'] as String? ?? '',
        nome: m['nome'] as String,
        codigo: m['codigo'] as String?,
        unidadeMedida: m['unidade_medida'] as String? ?? 'un',
        quantidadeAtual: (m['quantidade_atual'] as num?)?.toDouble() ?? 0,
        quantidadeMinima: (m['quantidade_minima'] as num?)?.toDouble() ?? 0,
        custoUnitarioMedio: (m['custo_unitario_medio'] as num?)?.toDouble(),
        ativa: m['ativa'] as bool? ?? true,
      );
}

final pecasEstoqueListProvider = FutureProvider.autoDispose<List<PecaEstoque>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client
      .from('pecas_estoque')
      .select('id, empresa_id, nome, codigo, unidade_medida, quantidade_atual, quantidade_minima, custo_unitario_medio, ativa')
      .eq('empresa_id', empresaId)
      .order('nome') as List;
  return rows.map((r) => PecaEstoque.fromMap(r as Map<String, dynamic>)).toList();
});

final pecaEstoqueDetalheProvider = FutureProvider.autoDispose.family<PecaEstoque?, String>((ref, id) async {
  final row = await SupabaseService.client
      .from('pecas_estoque')
      .select('id, empresa_id, nome, codigo, unidade_medida, quantidade_atual, quantidade_minima, custo_unitario_medio, ativa')
      .eq('id', id)
      .maybeSingle();
  if (row == null) return null;
  return PecaEstoque.fromMap(row);
});

class MovimentoEstoque {
  final String id;
  final String tipoMovimento;
  final double quantidade;
  final double? custoUnitario;
  final String? placa;
  final int? manutencaoId;
  final String? motivo;
  final String? criadoPor;
  final String criadoEm;

  const MovimentoEstoque({
    required this.id,
    required this.tipoMovimento,
    required this.quantidade,
    this.custoUnitario,
    this.placa,
    this.manutencaoId,
    this.motivo,
    this.criadoPor,
    required this.criadoEm,
  });

  factory MovimentoEstoque.fromMap(Map<String, dynamic> m) => MovimentoEstoque(
        id: m['id'] as String,
        tipoMovimento: m['tipo_movimento'] as String,
        quantidade: (m['quantidade'] as num?)?.toDouble() ?? 0,
        custoUnitario: (m['custo_unitario'] as num?)?.toDouble(),
        placa: m['placa'] as String?,
        manutencaoId: (m['manutencao_id'] as num?)?.toInt(),
        motivo: m['motivo'] as String?,
        criadoPor: m['criado_por'] as String?,
        criadoEm: m['criado_em'] as String,
      );
}

final movimentosEstoqueProvider = FutureProvider.autoDispose.family<List<MovimentoEstoque>, String>((ref, pecaId) async {
  final rows = await SupabaseService.client
      .from('pecas_estoque_movimentos')
      .select('id, tipo_movimento, quantidade, custo_unitario, placa, manutencao_id, motivo, criado_por, criado_em')
      .eq('peca_id', pecaId)
      .order('criado_em', ascending: false)
      .limit(100) as List;
  return rows.map((r) => MovimentoEstoque.fromMap(r as Map<String, dynamic>)).toList();
});

// Manutenções recentes da empresa — usadas no form de saída pra vincular o
// consumo de peça a uma OS específica (integração Materiais<->Manutenção,
// gap do benchmark Rodopar/Datapar). Mesma consulta do detalhe web.
class ManutencaoResumo {
  final int id;
  final String placa;
  final String dataManutencao;
  final String? tipo;
  const ManutencaoResumo({required this.id, required this.placa, required this.dataManutencao, this.tipo});
  factory ManutencaoResumo.fromMap(Map<String, dynamic> m) => ManutencaoResumo(
        id: (m['id'] as num).toInt(),
        placa: m['placa'] as String,
        dataManutencao: m['data_manutencao'] as String,
        tipo: m['tipo'] as String?,
      );
}

final manutencoesRecentesProvider = FutureProvider.autoDispose<List<ManutencaoResumo>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client
      .from('manutencoes_realizadas')
      .select('id, placa, data_manutencao, tipo')
      .eq('empresa_id', empresaId)
      .order('data_manutencao', ascending: false)
      .limit(50) as List;
  return rows.map((r) => ManutencaoResumo.fromMap(r as Map<String, dynamic>)).toList();
});
