import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';
import 'sessao_usuario.dart';

// Fase FLT-1 — carrega perfil/empresa/segmento uma vez por login (ver
// AuthService.carregarSessao) pra decidir roteamento (app_router.dart) e
// pros shells de cada perfil saberem o que mostrar (nome da empresa,
// esconder itens que não fazem sentido pro perfil, etc. — mesmo espírito
// de perfilUsuario/ehAdmin/ehPosto no layout.tsx da web).
//
// invalidate(sessaoProvider) depois de logout/login pra forçar recarregar.
//
// Fase FLT-2 (achado real) — usuário vinculado a 2+ empresas (Rede de
// Postos/grupo econômico) tinha a "empresa atual" escolhida por
// `empresasIds.first`, mas essa lista não tem ORDER BY garantido — dados
// inconsistentes entre telas (ex: "Ciclo em andamento" de um cliente não
// batendo com o que Abastecimentos mostrava). Corrigido: com 2+ empresas,
// `carregarSessao()` agora devolve `empresaId: null`
// (`precisaEscolherEmpresa` vira true) até o usuário escolher explicitamente
// — mesma regra da web (resolverEmpresaAtual só resolve sozinho com
// EXATAMENTE 1 empresa). A escolha fica neste provider (não persiste entre
// aberturas do app — aceitável por ora, mesmo espírito do TODO que já
// existia aqui antes desse achado).
final empresaSelecionadaProvider = StateProvider<String?>((ref) => null);

final sessaoProvider = FutureProvider<SessaoUsuario>((ref) async {
  final override = ref.watch(empresaSelecionadaProvider);
  final base = await AuthService().carregarSessao();

  if (override == null || !base.empresasIds.contains(override)) return base;

  final empresa = await AuthService().buscarEmpresa(override);
  return SessaoUsuario(
    email: base.email,
    perfil: base.perfil,
    empresaId: override,
    nomeEmpresa: empresa?['nome'] as String?,
    segmento: empresa?['segmento'] as String?,
    empresasIds: base.empresasIds,
  );
});
