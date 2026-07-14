import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../posto/providers/rede_posto_provider.dart' show PostoVinculado, RedePostoDetalhe;

// Fase FLT-4 — Rede de Postos (visão admin, consolidada), porta de
// src/app/(dashboard)/rede-postos/page.tsx + [id]/page.tsx (caminho
// ehAdmin) + src/lib/gruposEconomicos.ts. Achado ao ler o Next.js: NÃO
// existe página admin separada — é a MESMA rota /rede-postos pra posto e
// admin; o que muda é (1) a RLS de `grupos_economicos`/
// `grupos_economicos_empresas` (perfil_usuario_atual() = 'admin' libera
// SELECT/INSERT/UPDATE/DELETE total nas duas tabelas, conferido via
// pg_policies antes de portar) e (2) em [id]/page.tsx e novo/page.tsx, a
// lista de postos disponíveis pra vincular (admin vê TODOS os postos
// Revenda do sistema via `empresas`, não só os próprios via
// `empresas_do_usuario`).
//
// Por isso esta tela reaproveita 100% do `RedePostosService` já portado
// na Fase FLT-2 (posto/services/rede_postos_service.dart) — criarRede/
// atualizarRede/vincularPosto/desvincularPosto já operam por id
// arbitrário, sem nenhum acoplamento a `sessao.empresaId` — e reaproveita
// as classes `RedePostoDetalhe`/`PostoVinculado` via `show`. Só o que é
// realmente novo aqui: a LISTA de todas as redes (o posto só vê a
// própria), a busca de detalhe por id arbitrário (o posto só busca a
// própria), e a lista de TODOS os postos pra vincular (o posto só vê os
// que ele mesmo controla, via postosProprioProvider).

class RedePostoResumo {
  final String id;
  final String nome;
  final String? cnpjMatriz;
  final bool ativo;
  final int totalPostos;
  const RedePostoResumo({
    required this.id,
    required this.nome,
    this.cnpjMatriz,
    required this.ativo,
    required this.totalPostos,
  });
}

class KpisRedesPostos {
  final int total;
  final int ativas;
  const KpisRedesPostos({required this.total, required this.ativas});
}

// Espelha a query de rede-postos/page.tsx: grupos_economicos +
// grupos_economicos_empresas(count), segmento='Revenda'.
final redesPostosAdminListaProvider = FutureProvider.autoDispose<List<RedePostoResumo>>((ref) async {
  final rows = await SupabaseService.client
      .from('grupos_economicos')
      .select('id, nome, cnpj_matriz, ativo, grupos_economicos_empresas(count)')
      .eq('segmento', 'Revenda')
      .order('nome') as List;

  return rows.map((r) {
    final m = r as Map<String, dynamic>;
    final contagem = m['grupos_economicos_empresas'] as List?;
    final total = (contagem != null && contagem.isNotEmpty) ? ((contagem.first['count'] as num?)?.toInt() ?? 0) : 0;
    return RedePostoResumo(
      id: m['id'] as String,
      nome: m['nome'] as String? ?? '—',
      cnpjMatriz: m['cnpj_matriz'] as String?,
      ativo: m['ativo'] as bool? ?? true,
      totalPostos: total,
    );
  }).toList();
});

final kpisRedesPostosProvider = Provider.autoDispose<AsyncValue<KpisRedesPostos>>((ref) {
  final listaAsync = ref.watch(redesPostosAdminListaProvider);
  return listaAsync.whenData((lista) => KpisRedesPostos(
        total: lista.length,
        ativas: lista.where((r) => r.ativo).length,
      ));
});

// Todos os postos (Revenda) do sistema — espelha `todosPostos` de
// novo/page.tsx e [id]/page.tsx quando `ehAdmin`.
final postosTodosProvider = FutureProvider.autoDispose<List<({String id, String nome})>>((ref) async {
  final rows = await SupabaseService.client
      .from('empresas')
      .select('id, nome')
      .eq('segmento', 'Revenda')
      .order('nome') as List;
  return rows
      .map((m) => (id: (m as Map<String, dynamic>)['id'] as String, nome: m['nome'] as String? ?? '—'))
      .toList();
});

// Busca uma Rede por id arbitrário (não precisa ser da empresa atual —
// diferença central pro redePostoProvider do lado posto).
final redePostoAdminDetalheProvider =
    FutureProvider.autoDispose.family<RedePostoDetalhe?, String>((ref, redeId) async {
  final supabase = SupabaseService.client;

  final rede = await supabase
      .from('grupos_economicos')
      .select('id, nome, cnpj_matriz, ativo, segmento')
      .eq('id', redeId)
      .maybeSingle();
  if (rede == null || rede['segmento'] != 'Revenda') return null;

  final vinculosRaw = await supabase
      .from('grupos_economicos_empresas')
      .select('id, empresa:empresas(id, nome)')
      .eq('grupo_economico_id', redeId) as List;

  final vinculos = vinculosRaw.map((v) {
    final m = v as Map<String, dynamic>;
    final empresa = m['empresa'] as Map<String, dynamic>?;
    return PostoVinculado(
      vinculoId: m['id'] as String,
      empresaId: empresa?['id'] as String? ?? '',
      nome: empresa?['nome'] as String? ?? '(posto removido)',
    );
  }).toList();

  return RedePostoDetalhe(
    id: rede['id'] as String,
    nome: rede['nome'] as String,
    cnpjMatriz: rede['cnpj_matriz'] as String?,
    ativo: rede['ativo'] as bool? ?? true,
    vinculos: vinculos,
  );
});
