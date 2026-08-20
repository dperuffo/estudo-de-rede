import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'supabase_service.dart';

// Fase enforcement-permissoes (04/08/2026, pedido do Daniel: "as permissoes
// deveriam travar se estiverem desligadas, tanto na web quanto no PWA") —
// porta 1:1 de src/lib/permissoes.ts (web). Mesmo raciocínio, mesmas
// limitações documentadas lá:
//   - só olha o padrão GLOBAL (empresa_id = empresaIdGlobal) — a
//     customização por empresa que gestor_frota/analista/posto fazem em
//     /permissoes continua gravando normal, só não afeta o bloqueio
//     automático de rota (mesma decisão da web, mesmo motivo: saber "qual
//     empresa está ativa" em toda navegação exigiria complexidade extra
//     fora de escopo por ora).
//   - "colaborador" não existe como perfil próprio neste PWA (não tem
//     shell dedicado — ver sessao_usuario.dart: ehAdmin/ehPosto/ehCliente),
//     então não se aplica aqui.
//   - linha ausente = liberado (fail-open), igual à web.
//
// ROTA aqui é o `matchedLocation` do go_router — cobre os dois shells
// (cliente "/x" e posto "/posto/x") na MESMA tabela, já que os prefixos não
// colidem entre si. Slugs idênticos aos de HREF_FUNCIONALIDADE na web
// (src/lib/permissoes.ts) — um toggle em /permissoes tem que travar do
// mesmo jeito nos dois lados.
const rotaFuncionalidade = <String, String>{
  // Shell cliente.
  '/dashboard': 'aba_dashboard',
  '/assistente': 'aba_assistente_ia',
  '/assinatura': 'aba_minha_assinatura',
  '/avaliar': 'aba_avaliar_plataforma',
  '/financeiro': 'aba_financeiro',
  '/inteligencia-rede': 'aba_inteligencia',
  '/lgpd': 'aba_lgpd',
  '/clientes': 'aba_clientes',
  '/grupo-economico': 'aba_grupo_economico',
  '/usuarios': 'aba_usuarios',
  '/motoristas': 'aba_motoristas',
  '/veiculos': 'aba_veiculos',
  '/centros-custo': 'aba_centros_custo',
  '/postos': 'aba_postos',
  '/abastecimentos': 'aba_abastecimentos',
  '/notas-fiscais': 'aba_notas_fiscais',
  '/acoes-sugeridas': 'aba_anomalias',
  '/parcerias-locais': 'aba_parcerias_locais',
  '/fretes': 'aba_fretes',
  '/torre-de-controle': 'aba_torre_controle',
  '/programacao': 'aba_programacao_frota',
  '/agendamentos-patio': 'aba_agendamento_patio',
  '/pisos-antt': 'aba_pisos_antt',
  '/crm-comercial': 'aba_crm_comercial',
  '/motoristas-parceiros': 'aba_motoristas_parceiros',
  '/roteirizacao': 'aba_roteirizacao',
  '/rotograma': 'aba_rotograma',
  '/planos-viagem': 'aba_planos_viagem',
  '/negociacoes': 'aba_negociacoes',
  '/precos-postos': 'aba_precos_postos',
  '/combustivel-ideal': 'aba_combustivel_ideal',
  '/manutencao-preditiva': 'aba_manutencao',
  '/estoque-pecas': 'aba_estoque_pecas',
  '/tco': 'aba_tco',
  '/patrimonio': 'aba_patrimonio',
  '/indicadores-frota': 'aba_indicadores_frota',
  '/checklist-veiculos': 'aba_checklist_veiculos',
  '/sinistros': 'aba_sinistros',
  '/multas': 'aba_multas',
  '/oficinas': 'aba_oficinas',
  '/parametros-uso': 'aba_parametros_uso',
  '/parametros-nf': 'aba_parametros_nf',
  '/relatorios': 'aba_relatorios',
  '/pegada-carbono': 'aba_pegada_carbono',
  '/permissoes': 'aba_permissoes',
  '/configuracoes': 'aba_configuracoes_sistema',
  '/avaliacoes': 'aba_avaliacoes_clientes',
  '/assinaturas': 'aba_assinaturas_clientes',
  // Shell posto.
  '/posto/rede-postos': 'aba_rede_postos',
  '/posto/assistente': 'aba_assistente_ia',
  '/posto/assinatura': 'aba_minha_assinatura',
  '/posto/avaliar': 'aba_avaliar_plataforma',
  '/posto/financeiro': 'aba_financeiro_posto',
  '/posto/lgpd': 'aba_lgpd',
  '/posto/meus-dados': 'aba_meus_dados_pix',
  '/posto/usuarios': 'aba_usuarios',
  '/posto/negociacoes': 'aba_negociacoes',
  '/posto/abastecimentos': 'aba_abastecimentos',
  '/posto/parcerias-locais': 'aba_parcerias_locais',
  '/posto/clientes': 'aba_clientes_posto',
  '/posto/precos': 'aba_precos_postos',
  '/posto/pre-pedidos': 'aba_pre_pedidos',
};

// Nunca bloqueadas, mesmo que a matriz diga "desligado" — evita loop de
// redirecionamento (destino do bloqueio) e travar quem precisa da tela pra
// sair de qualquer bloqueio, mesmo espírito de ROTAS_NUNCA_BLOQUEADAS na
// web (src/lib/permissoes.ts) + as rotas de gate do próprio app_router.dart
// (login, MFA, seleção de empresa).
const rotasNuncaBloqueadas = <String>{
  '/',
  '/dashboard',
  '/posto',
  '/chamados',
  '/posto/chamados',
  '/assinatura',
  '/posto/assinatura',
  '/mfa-pendente',
  '/login',
  '/selecionar-empresa',
};

String? resolverFuncionalidadeDaRota(String pathname) {
  if (rotasNuncaBloqueadas.contains(pathname)) return null;

  String? melhorHref;
  String? melhorFuncionalidade;
  for (final entry in rotaFuncionalidade.entries) {
    final bate = pathname == entry.key || pathname.startsWith('${entry.key}/');
    if (bate && (melhorHref == null || entry.key.length > melhorHref.length)) {
      melhorHref = entry.key;
      melhorFuncionalidade = entry.value;
    }
  }
  return melhorFuncionalidade;
}

// Time interno (admin ou o e-mail do Daniel) nunca é bloqueado — mesmo
// espírito de ehBypassPermissao na web.
bool ehBypassPermissao(String? perfil, String? email) {
  return perfil == 'admin' || email == 'd.peruffo@gmail.com';
}

bool temAcesso(Map<String, bool> mapa, String? funcionalidade) {
  if (funcionalidade == null) return true;
  return mapa[funcionalidade] ?? true;
}

// Carrega o padrão GLOBAL de permissões pro perfil informado. Cacheado por
// perfil pelo próprio Riverpod (FutureProvider.family) — a mesma instância
// serve tanto o redirect do go_router (chamado a cada navegação) quanto o
// filtro de menu dos dois shells, sem repetir a consulta ao Supabase em
// toda troca de tela. `ref.invalidate` no logout (mesmo padrão de
// sessaoProvider) evita vazar sessão de um usuário pro próximo login.
final permissoesMapaProvider =
    FutureProvider.family<Map<String, bool>, String?>((ref, perfil) async {
  final mapa = <String, bool>{};
  if (perfil == null) return mapa;
  const empresaIdGlobal = '00000000-0000-0000-0000-000000000000';
  try {
    final linhas = await SupabaseService.client
        .from('permissoes_perfil')
        .select('funcionalidade, permitido')
        .eq('empresa_id', empresaIdGlobal)
        .eq('perfil', perfil);
    for (final m in linhas) {
      mapa[m['funcionalidade'] as String] = m['permitido'] as bool? ?? false;
    }
  } catch (e) {
    // Fail-open — mesmo espírito de carregarMapaPermissoes na web: uma
    // falha de rede/banco não deve travar o app inteiro, só deixa de
    // aplicar o filtro desta vez (mapa vazio = tudo liberado).
  }
  return mapa;
});
