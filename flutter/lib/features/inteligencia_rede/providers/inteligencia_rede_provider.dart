import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — porta de src/app/(dashboard)/inteligencia-rede/page.tsx pro
// Flutter (visão Cliente). Escopo DRASTICAMENTE reduzido em relação à web:
// a página lá tem 941 linhas, ~15 RPCs em paralelo e 20 componentes (mapas
// Leaflet, cobertura por macrorregião, score de oportunidade de expansão,
// modo comparativo, sazonalidade, cruzamentos avançados...) — nível
// "painel executivo admin", não cabe (nem faz sentido) numa tela só de
// celular. Esta v1 traz só o que dá pra consumir direto num scroll:
//   - 3 KPIs (total de postos na rede, municípios únicos, UFs cobertas);
//   - preço médio da rede por combustível (sem comparação com ANP — a web
//     calcula esse delta no cliente com uma resolução de referência
//     bem elaborada; câmbio pra depois);
//   - postos com preço acima da referência ANP (`postos_gf_desvio_anp`
//     já traz TUDO calculado no banco — preço próprio, preço ANP, % de
//     desvio — nenhuma lógica extra necessária aqui, só ordenar e mostrar);
//   - top municípios da rede.
// Fora do escopo (fica pra quando/se fizer sentido): os mapas, cobertura
// por macrorregião, score de oportunidades de expansão, modo comparativo,
// tendência de sazonalidade, cruzamentos avançados, cobertura x demanda.
//
// Igual à web (ver comentário da Fase 27.151 em page.tsx): as RPCs que
// aceitam `p_empresa_id` são SECURITY DEFINER e fazem a checagem de
// permissão elas mesmas — sempre mandamos o id, nunca null (never client
// vê "toda a plataforma"). As que NÃO aceitam parâmetro (postos_gf_por_uf,
// postos_gf_municipios_unicos, postos_gf_top_municipios) rodam direto
// sobre a tabela `postos_gf`, cuja RLS (`postos_gf_tenant_all`) já restringe
// pra só a própria empresa — seguras sem parâmetro extra.

class PrecoPorCombustivelRede {
  final String combustivel;
  final double precoMedio;
  final int qtdPostos;
  const PrecoPorCombustivelRede({required this.combustivel, required this.precoMedio, required this.qtdPostos});
  factory PrecoPorCombustivelRede.fromMap(Map<String, dynamic> m) => PrecoPorCombustivelRede(
        combustivel: m['combustivel'] as String? ?? '—',
        precoMedio: (m['preco_medio'] as num?)?.toDouble() ?? 0,
        qtdPostos: (m['qtd_postos'] as num?)?.toInt() ?? 0,
      );
}

class PostoDesvioAnp {
  final String cnpj;
  final String razaoSocial;
  final String? municipio;
  final String? uf;
  final String combustivel;
  final double precoGf;
  final double? precoAnp;
  final String? nivelAnp;
  final double diffPct;
  final double diffRs;
  const PostoDesvioAnp({
    required this.cnpj,
    required this.razaoSocial,
    required this.municipio,
    required this.uf,
    required this.combustivel,
    required this.precoGf,
    required this.precoAnp,
    required this.nivelAnp,
    required this.diffPct,
    required this.diffRs,
  });
  factory PostoDesvioAnp.fromMap(Map<String, dynamic> m) => PostoDesvioAnp(
        cnpj: m['cnpj'] as String? ?? '',
        razaoSocial: m['razao_social'] as String? ?? '—',
        municipio: m['municipio'] as String?,
        uf: m['uf'] as String?,
        combustivel: m['combustivel'] as String? ?? '—',
        precoGf: (m['preco_gf'] as num?)?.toDouble() ?? 0,
        precoAnp: (m['preco_anp'] as num?)?.toDouble(),
        nivelAnp: m['nivel_anp'] as String?,
        diffPct: (m['diff_pct'] as num?)?.toDouble() ?? 0,
        diffRs: (m['diff_rs'] as num?)?.toDouble() ?? 0,
      );
}

class MunicipioRede {
  final String municipio;
  final String uf;
  final int total;
  const MunicipioRede({required this.municipio, required this.uf, required this.total});
  factory MunicipioRede.fromMap(Map<String, dynamic> m) => MunicipioRede(
        municipio: m['municipio'] as String? ?? '—',
        uf: m['uf'] as String? ?? '',
        total: (m['total'] as num?)?.toInt() ?? 0,
      );
}

class InteligenciaRedeDados {
  final int totalPostos;
  final int municipiosUnicos;
  final int estadosCobertos;
  final List<PrecoPorCombustivelRede> precoPorCombustivel;
  final List<PostoDesvioAnp> alertas;
  final List<MunicipioRede> topMunicipios;
  const InteligenciaRedeDados({
    required this.totalPostos,
    required this.municipiosUnicos,
    required this.estadosCobertos,
    required this.precoPorCombustivel,
    required this.alertas,
    required this.topMunicipios,
  });
}

final inteligenciaRedeClienteProvider = FutureProvider.autoDispose<InteligenciaRedeDados?>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return null;
  final supabase = SupabaseService.client;

  // Chamadas sequenciais (não Future.wait) — mesmo padrão do resto do app:
  // tipos de retorno diferentes por consulta (count vs RPC list).
  final totalPostosResp = await supabase.from('postos_gf').select('cnpj').eq('empresa_id', empresaId).count(CountOption.exact);

  final municipiosUnicos = await supabase.rpc('postos_gf_municipios_unicos') as int? ?? 0;

  final porUfRaw = await supabase.rpc('postos_gf_por_uf') as List;

  final precoRaw = await supabase.rpc('preco_medio_por_combustivel', params: {'p_empresa_id': empresaId}) as List;
  final precoPorCombustivel = precoRaw
      .map((m) => PrecoPorCombustivelRede.fromMap(m as Map<String, dynamic>))
      .toList()
    ..sort((a, b) => b.qtdPostos.compareTo(a.qtdPostos));

  final desvioRaw = await supabase.rpc('postos_gf_desvio_anp', params: {'p_empresa_id': empresaId}) as List;
  final alertas = desvioRaw
      .map((m) => PostoDesvioAnp.fromMap(m as Map<String, dynamic>))
      .where((a) => a.diffPct > 0)
      .toList()
    ..sort((a, b) => b.diffPct.compareTo(a.diffPct));

  final municipiosRaw = await supabase.rpc('postos_gf_top_municipios', params: {'p_limit': 10}) as List;
  final topMunicipios = municipiosRaw.map((m) => MunicipioRede.fromMap(m as Map<String, dynamic>)).toList();

  return InteligenciaRedeDados(
    totalPostos: totalPostosResp.count,
    municipiosUnicos: municipiosUnicos,
    estadosCobertos: porUfRaw.length,
    precoPorCombustivel: precoPorCombustivel,
    alertas: alertas.take(20).toList(),
    topMunicipios: topMunicipios,
  );
});
