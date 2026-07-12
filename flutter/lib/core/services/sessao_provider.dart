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
final sessaoProvider = FutureProvider<SessaoUsuario>((ref) {
  return AuthService().carregarSessao();
});
