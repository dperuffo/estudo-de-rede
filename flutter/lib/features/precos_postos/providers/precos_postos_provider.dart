import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — Preços dos Postos Parceiros (cliente), porta de
// precos-postos/page.tsx — só o painel CLIENTE (`PainelCliente`); o painel
// POSTO (`PainelPosto`, cadastro do próprio preço) já existe desde a FLT-2
// em lib/features/posto/screens/precos_posto_screen.dart. RLS conferida
// antes de portar: `precos_postos_leitura` já dá exatamente o recorte que
// a web usa (preços do próprio posto do usuário OU de qualquer posto com
// quem a empresa do usuário tenha negociação) — dá pra consultar direto,
// sem RPC, igual à web.
//
// Redução: a web resolve o nome de quem atualizou o preço via
// `usuarios_app` (só funciona pra admin/analista — a RLS de
// `usuarios_app_select` só libera a própria linha pra outros perfis, então
// pro cliente a web já cai no fallback de mostrar o e-mail cru). Aqui o
// app já mostra direto o e-mail, sem a tentativa de resolução que nunca
// funcionaria pro cliente de qualquer forma.

class PrecoPostoParceiro {
  final String combustivel;
  final double preco;
  final String? atualizadoEm;
  final String? atualizadoPor;
  const PrecoPostoParceiro({required this.combustivel, required this.preco, this.atualizadoEm, this.atualizadoPor});
  factory PrecoPostoParceiro.fromMap(Map<String, dynamic> m) => PrecoPostoParceiro(
        combustivel: m['combustivel'] as String,
        preco: (m['preco'] as num).toDouble(),
        atualizadoEm: m['atualizado_em'] as String?,
        atualizadoPor: m['atualizado_por'] as String?,
      );
}

class PostoComPrecos {
  final String idPosto;
  final String nome;
  final List<PrecoPostoParceiro> precos;
  const PostoComPrecos({required this.idPosto, required this.nome, required this.precos});
}

final precosPostosParceirosProvider = FutureProvider.autoDispose<List<PostoComPrecos>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final supabase = SupabaseService.client;

  final negociacoes = await supabase
      .from('negociacoes_postos')
      .select('empresa_posto_id, posto_nome')
      .eq('empresa_cliente_id', empresaId)
      .not('empresa_posto_id', 'is', null) as List;

  final postosMap = <String, String>{};
  for (final n in negociacoes) {
    final m = n as Map<String, dynamic>;
    final idPosto = m['empresa_posto_id'] as String?;
    if (idPosto != null) postosMap[idPosto] = m['posto_nome'] as String? ?? 'Posto';
  }
  final idsPostos = postosMap.keys.toList();
  if (idsPostos.isEmpty) return [];

  final precosRows = await supabase
      .from('precos_postos')
      .select('empresa_posto_id, combustivel, preco, atualizado_em, atualizado_por')
      .inFilter('empresa_posto_id', idsPostos)
      .order('combustivel', ascending: true) as List;

  final porPosto = <String, List<PrecoPostoParceiro>>{};
  for (final r in precosRows) {
    final m = r as Map<String, dynamic>;
    final idPosto = m['empresa_posto_id'] as String;
    porPosto.putIfAbsent(idPosto, () => []).add(PrecoPostoParceiro.fromMap(m));
  }

  return idsPostos.map((id) => PostoComPrecos(idPosto: id, nome: postosMap[id]!, precos: porPosto[id] ?? [])).toList();
});
