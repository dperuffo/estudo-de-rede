import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../grupo_economico/providers/grupo_economico_provider.dart' show EmpresaVinculadaGrupo, GrupoEconomicoDetalhe;

// Fase FLT-4 — Grupo Econômico (admin, consolidado — menu "Cadastros" da
// web), porta de grupo-economico/page.tsx + [id]/page.tsx + novo/page.tsx
// + src/lib/gruposEconomicos.ts. Mesma mecânica de rede_postos_admin
// (tabela `grupos_economicos`/`grupos_economicos_empresas` compartilhada,
// só muda o `segmento` — aqui 'Frota' em vez de 'Revenda'), mas com uma
// diferença importante confirmada lendo a web e o comentário já existente
// em grupo_economico_provider.dart (FLT-3, versão cliente, só leitura):
// pra segmento='Frota' a RLS de escrita (`grupos_insert`/`grupos_update`/
// `gee_insere`) só libera pra admin — NUNCA há self-service pro cliente
// (diferente de Rede de Postos, onde o posto-membro pode editar a
// própria Rede). Por isso esta tela de admin é o ÚNICO lugar do sistema
// (fora o service role) que consegue criar/editar/vincular Grupo
// Econômico de verdade.
//
// IMPORTANTE (achado real desta sessão, ver documentos_empresas_admin_
// provider.dart): as telas importam `EmpresaVinculadaGrupo`/
// `GrupoEconomicoDetalhe` DIRETO de `grupo_economico_provider.dart`
// (não deste arquivo) — `import ... show` não repassa símbolos pra quem
// importa ESTE arquivo, só pra quem importa o original.
class GrupoEconomicoResumo {
  final String id;
  final String nome;
  final String? cnpjMatriz;
  final bool ativo;
  final int totalEmpresas;
  const GrupoEconomicoResumo({
    required this.id,
    required this.nome,
    this.cnpjMatriz,
    required this.ativo,
    required this.totalEmpresas,
  });
}

class KpisGruposEconomicos {
  final int total;
  final int ativos;
  const KpisGruposEconomicos({required this.total, required this.ativos});
}

// Espelha a query de grupo-economico/page.tsx: grupos_economicos +
// grupos_economicos_empresas(count), segmento='Frota'.
final gruposEconomicosAdminListaProvider = FutureProvider.autoDispose<List<GrupoEconomicoResumo>>((ref) async {
  final rows = await SupabaseService.client
      .from('grupos_economicos')
      .select('id, nome, cnpj_matriz, ativo, grupos_economicos_empresas(count)')
      .eq('segmento', 'Frota')
      .order('nome') as List;

  return rows.map((r) {
    final m = r as Map<String, dynamic>;
    final contagem = m['grupos_economicos_empresas'] as List?;
    final total = (contagem != null && contagem.isNotEmpty) ? ((contagem.first['count'] as num?)?.toInt() ?? 0) : 0;
    return GrupoEconomicoResumo(
      id: m['id'] as String,
      nome: m['nome'] as String? ?? '—',
      cnpjMatriz: m['cnpj_matriz'] as String?,
      ativo: m['ativo'] as bool? ?? true,
      totalEmpresas: total,
    );
  }).toList();
});

final kpisGruposEconomicosProvider = Provider.autoDispose<AsyncValue<KpisGruposEconomicos>>((ref) {
  final listaAsync = ref.watch(gruposEconomicosAdminListaProvider);
  return listaAsync.whenData((lista) => KpisGruposEconomicos(
        total: lista.length,
        ativos: lista.where((g) => g.ativo).length,
      ));
});

// Todos os clientes (Frota) do sistema — espelha `empresasDisponiveis`
// de [id]/page.tsx (segmento='Frota', menos as já vinculadas, calculado
// na tela).
final empresasFrotaTodasProvider = FutureProvider.autoDispose<List<({String id, String nome})>>((ref) async {
  final rows = await SupabaseService.client
      .from('empresas')
      .select('id, nome')
      .eq('segmento', 'Frota')
      .order('nome') as List;
  return rows
      .map((m) => (id: (m as Map<String, dynamic>)['id'] as String, nome: m['nome'] as String? ?? '—'))
      .toList();
});

// Busca um Grupo por id arbitrário (não precisa ser o da empresa atual —
// diferença central pro grupoEconomicoClienteProvider, que só lê o
// próprio e é read-only).
final grupoEconomicoAdminDetalheProvider =
    FutureProvider.autoDispose.family<GrupoEconomicoDetalhe?, String>((ref, grupoId) async {
  final supabase = SupabaseService.client;

  final grupo = await supabase
      .from('grupos_economicos')
      .select('id, nome, cnpj_matriz, ativo, segmento')
      .eq('id', grupoId)
      .maybeSingle();
  if (grupo == null || grupo['segmento'] != 'Frota') return null;

  final vinculosRaw = await supabase
      .from('grupos_economicos_empresas')
      .select('id, empresa:empresas(id, nome)')
      .eq('grupo_economico_id', grupoId) as List;

  final vinculos = vinculosRaw.map((v) {
    final m = v as Map<String, dynamic>;
    final empresa = m['empresa'] as Map<String, dynamic>?;
    return EmpresaVinculadaGrupo(
      vinculoId: m['id'] as String,
      empresaId: empresa?['id'] as String? ?? '',
      nome: empresa?['nome'] as String? ?? '(empresa removida)',
    );
  }).toList();

  return GrupoEconomicoDetalhe(
    id: grupo['id'] as String,
    nome: grupo['nome'] as String,
    cnpjMatriz: grupo['cnpj_matriz'] as String?,
    ativo: grupo['ativo'] as bool? ?? true,
    vinculos: vinculos,
  );
});
