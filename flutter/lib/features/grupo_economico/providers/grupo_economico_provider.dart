import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — Grupo Econômico (cliente), porta de
// src/app/(dashboard)/grupo-economico/page.tsx + [id]/page.tsx. Mesma
// mecânica de `rede_posto_provider.dart` (FLT-2, lado posto) — a tabela
// `grupos_economicos`/`grupos_economicos_empresas` é COMPARTILHADA entre
// Rede de Postos (segmento='Revenda') e Grupo Econômico (segmento='Frota'),
// só muda o filtro.
//
// Achado real na RLS (checado direto no banco antes de portar): pra
// segmento='Frota', tanto `grupos_economicos_empresas` (`gee_insere`)
// quanto `grupos_economicos` (`grupos_insert`/`grupos_update`) só
// permitem escrita self-service quando `grupo_economico_e_revenda(...)`
// é verdadeiro OU o usuário é admin — ou seja, um cliente comum NUNCA
// consegue criar/editar/vincular grupo pela RLS, mesmo que a UI da web
// mostre o botão "+ Novo Grupo" (ele simplesmente falharia no servidor).
// Por isso esta porta é só leitura: mostra o(s) grupo(s) que a empresa
// atual já integra (RLS `grupos_select`/`gee_membro_select` já escopam
// isso sozinhas) e as empresas vinculadas. Sem criação/edição/vínculo —
// diferente da Rede de Postos, que É self-service pro posto (Fase 27.139).
class EmpresaVinculadaGrupo {
  final String vinculoId;
  final String empresaId;
  final String nome;
  const EmpresaVinculadaGrupo({required this.vinculoId, required this.empresaId, required this.nome});
}

class GrupoEconomicoDetalhe {
  final String id;
  final String nome;
  final String? cnpjMatriz;
  final bool ativo;
  final List<EmpresaVinculadaGrupo> vinculos;
  const GrupoEconomicoDetalhe({
    required this.id,
    required this.nome,
    required this.cnpjMatriz,
    required this.ativo,
    required this.vinculos,
  });
}

final grupoEconomicoClienteProvider = FutureProvider.autoDispose<GrupoEconomicoDetalhe?>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return null;
  final supabase = SupabaseService.client;

  final meusVinculos = await supabase
      .from('grupos_economicos_empresas')
      .select('grupo_economico_id')
      .eq('empresa_id', empresaId)
      .limit(1) as List;
  if (meusVinculos.isEmpty) return null;
  final grupoId = meusVinculos.first['grupo_economico_id'] as String;

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
