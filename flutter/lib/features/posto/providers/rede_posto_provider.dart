import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — porta de src/app/(dashboard)/rede-postos/[id]/page.tsx +
// src/lib/gruposEconomicos.ts pro lado posto do Flutter. Espelha a mesma
// mecânica "Rede de Postos" = tabela grupos_economicos/
// grupos_economicos_empresas filtrada a segmento='Revenda' (ver comentário
// completo em gruposEconomicos.ts — é a MESMA tabela do Grupo Econômico do
// lado Frota, só muda o segmento).
class PostoVinculado {
  final String vinculoId;
  final String empresaId;
  final String nome;
  const PostoVinculado({required this.vinculoId, required this.empresaId, required this.nome});
}

class RedePostoDetalhe {
  final String id;
  final String nome;
  final String? cnpjMatriz;
  final bool ativo;
  final List<PostoVinculado> vinculos;
  const RedePostoDetalhe({
    required this.id,
    required this.nome,
    required this.cnpjMatriz,
    required this.ativo,
    required this.vinculos,
  });
}

// Acha a Rede da empresa atual (se houver) e já traz os vínculos junto.
// Achado real: não precisamos filtrar por segmento='Revenda' na primeira
// consulta (grupos_economicos_empresas por empresa_id) — o Flutter só
// existe pro shell /posto, então a empresa atual já é sempre Revenda; a
// checagem de segmento acontece depois, ao ler o grupo em si, só por
// segurança (mesmo espírito do "trata como não encontrado" do page.tsx
// original quando o id é de um Grupo Econômico de Frota).
final redePostoProvider = FutureProvider.autoDispose<RedePostoDetalhe?>((ref) async {
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
  final redeId = meusVinculos.first['grupo_economico_id'] as String;

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

// Todos os postos que este login controla (sessao.empresasIds já é
// exatamente isso — mesma RPC empresas_do_usuario que a web usa em
// /rede-postos/novo e /rede-postos/[id] pra montar "postosOpcoes"/
// "postosDisponiveis" de quem não é admin). Usado tanto pra escolher o
// posto fundador ao criar quanto pra vincular mais postos depois.
final postosProprioProvider = FutureProvider.autoDispose<List<({String id, String nome})>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  if (sessao.empresasIds.isEmpty) return [];
  final rows = await SupabaseService.client
      .from('empresas')
      .select('id, nome, segmento')
      .inFilter('id', sessao.empresasIds)
      .order('nome') as List;
  return rows
      .where((m) => (m as Map<String, dynamic>)['segmento'] == 'Revenda')
      .map((m) => (id: (m as Map<String, dynamic>)['id'] as String, nome: m['nome'] as String? ?? '—'))
      .toList();
});
