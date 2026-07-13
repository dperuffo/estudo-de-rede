import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — Centros de Custo (cliente), porta de
// src/app/(dashboard)/centros-custo/page.tsx + [id]/page.tsx + actions.ts.
// Escopo reduzido: mantém cadastro (nome/código/responsável/descrição/
// ativo) e alocação de MOTORISTAS (só um UPDATE em lote — igual à web).
// Fora do escopo: alocação de VEÍCULOS (a web mantém histórico completo
// via `centros_custo_veiculos`, com alocação/desalocação em massa — mais
// natural de portar junto com a própria tela de Veículos, que ainda não
// existe no Flutter) e importação por planilha
// (`/centros-custo/importar`). A contagem "Veículos alocados" no card
// ainda é mostrada (dado real, já existe via `cadastro_veiculos`,
// alimentado pela web), só não dá pra alocar por aqui ainda.
class CentroCusto {
  final String id;
  final String nome;
  final String? codigo;
  final String? responsavel;
  final String? descricao;
  final bool ativo;
  final int veiculosAlocados;

  const CentroCusto({
    required this.id,
    required this.nome,
    this.codigo,
    this.responsavel,
    this.descricao,
    required this.ativo,
    required this.veiculosAlocados,
  });

  factory CentroCusto.fromMap(Map<String, dynamic> m) {
    final veiculosRaw = m['cadastro_veiculos'] as List?;
    final count = veiculosRaw != null && veiculosRaw.isNotEmpty ? (veiculosRaw.first['count'] as num?)?.toInt() : null;
    return CentroCusto(
      id: m['id'] as String,
      nome: m['nome'] as String? ?? '—',
      codigo: m['codigo'] as String?,
      responsavel: m['responsavel'] as String?,
      descricao: m['descricao'] as String?,
      ativo: m['ativo'] as bool? ?? true,
      veiculosAlocados: count ?? 0,
    );
  }
}

final centrosCustoClienteProvider = FutureProvider.autoDispose<List<CentroCusto>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client
      .from('centros_custo')
      .select('id, nome, codigo, responsavel, descricao, ativo, cadastro_veiculos(count)')
      .eq('empresa_id', empresaId)
      .order('nome') as List;
  return rows.map((m) => CentroCusto.fromMap(m as Map<String, dynamic>)).toList();
});

final centroCustoDetalheProvider = FutureProvider.autoDispose.family<CentroCusto?, String>((ref, id) async {
  final lista = await ref.watch(centrosCustoClienteProvider.future);
  for (final c in lista) {
    if (c.id == id) return c;
  }
  return null;
});
