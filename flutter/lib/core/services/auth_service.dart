import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'sessao_usuario.dart';

// Fase FLT-1 — pedido do Daniel: "PWA precisa direcionar cada usuário pro
// seu perfil (posto/cliente/admin) e operar de acordo com as permissões",
// igual a web já faz (Auth + RLS no Supabase). Trocamos a autenticação da
// API Python própria (JWT customizado em api.fxgestaodefrotasonline.com)
// por Supabase Auth direto — mesmo projeto, mesmas tabelas/RPCs/RLS que o
// app Next.js usa (ver src/app/login/actions.ts na web: entrarComSenha +
// entrarComGoogle são o espelho exato do que fazemos aqui).
//
// IMPORTANTE (pendência de configuração, não é código): o Client ID do
// Google usado abaixo era o da API antiga — pra signInWithIdToken funcionar
// de verdade, o provider "Google" precisa estar habilitado no Supabase
// Auth (Dashboard → Authentication → Providers) com um Client ID Web
// autorizado pra esse app. Se ainda não estiver, o login por Google vai
// falhar mesmo com o código certo — o login por e-mail/senha funciona
// independente disso.
// Fase FLT-1b — ver comentário de statusMfa() abaixo.
class MfaStatus {
  final bool temFatorVerificado;
  final bool precisaVerificarCodigo;
  final String? factorId;
  const MfaStatus({
    required this.temFatorVerificado,
    required this.precisaVerificarCodigo,
    this.factorId,
  });
  bool get bloqueado => !temFatorVerificado || precisaVerificarCodigo;
}

class AuthService {
  static final AuthService _i = AuthService._();
  factory AuthService() => _i;
  AuthService._();

  final _g = GoogleSignIn(
    clientId: '629066078340-h9o6518gmnf5lsu6a8n606d4dsva65tn.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

  SupabaseClient get _supabase => SupabaseService.client;

  // Espelha entrarComSenha (web/src/app/login/actions.ts).
  Future<void> signInWithPassword({required String email, required String senha}) async {
    await _supabase.auth.signInWithPassword(email: email.trim().toLowerCase(), password: senha);
  }

  // Espelha entrarComGoogle (web/src/app/login/actions.ts) — lá o nonce é
  // gerado no browser (Google Identity Services); aqui o google_sign_in
  // nativo já cuida da emissão do idToken, sem precisar desse passo manual.
  Future<void> signInWithGoogle() async {
    final account = await _g.signIn();
    if (account == null) return; // usuário cancelou
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw Exception('Não foi possível obter o idToken do Google.');
    }
    await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: auth.accessToken,
    );
  }

  Future<void> signOut() async {
    try {
      await _g.signOut();
    } catch (_) {
      // usuário pode não ter entrado via Google — ignora.
    }
    await _supabase.auth.signOut();
  }

  bool get isLoggedIn => _supabase.auth.currentSession != null;

  String? get emailAtual => _supabase.auth.currentUser?.email;

  // Fase FLT-1 — mesmo gate de MFA obrigatório do layout.tsx da web:
  //   const { data: aal } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
  //   const { data: factors } = await supabase.auth.mfa.listFactors();
  //   temFatorVerificado = factors?.totp?.some(f => f.status === "verified")
  //   precisaSubirNivel = aal?.nextLevel === "aal2" && aal.currentLevel !== "aal2"
  //
  // Fase FLT-1b — isso sozinho não bastava: "tem fator verificado" (já
  // cadastrou o TOTP alguma vez, via web) é diferente de "esta sessão já
  // subiu pro aal2" (precisa digitar o código de 6 dígitos a cada novo
  // login — desafio normal de qualquer 2FA, não é a mesma coisa que
  // cadastro). statusMfa() agora separa os dois casos pra a tela decidir
  // qual UI mostrar (orientar a configurar x pedir o código).
  Future<MfaStatus> statusMfa() async {
    final fatoresResp = await _supabase.auth.mfa.listFactors();
    Factor? fatorVerificado;
    for (final f in fatoresResp.totp) {
      if (f.status == FactorStatus.verified) {
        fatorVerificado = f;
        break;
      }
    }

    final aal = _supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    final precisaSubirNivel = aal.nextLevel == AuthenticatorAssuranceLevels.aal2 &&
        aal.currentLevel != AuthenticatorAssuranceLevels.aal2;

    return MfaStatus(
      temFatorVerificado: fatorVerificado != null,
      precisaVerificarCodigo: fatorVerificado != null && precisaSubirNivel,
      factorId: fatorVerificado?.id,
    );
  }

  Future<bool> precisaConfigurarOuVerificarMfa() async => (await statusMfa()).bloqueado;

  // Desafio de login TOTP: pega o código de 6 dígitos atual do app
  // autenticador do usuário e eleva a sessão pro nível aal2. Precisa do
  // factorId que vem de statusMfa().
  Future<void> verificarCodigoMfa({required String factorId, required String code}) async {
    await _supabase.auth.mfa.challengeAndVerify(factorId: factorId, code: code);
  }

  // Resolve perfil + empresa atual, mesmo espírito de
  // src/lib/empresaAtual.ts::resolverEmpresaAtual na web.
  //
  // Achado real (Fase FLT-2) — testando com uma conta vinculada a 2 empresas
  // (Rede de Postos/grupo econômico: "Posto Teste 2" + "Posto Teste", via
  // empresas_do_usuario), os dados de "Ciclo em andamento" de um cliente não
  // batiam com o que a tela de Abastecimentos mostrava. Causa: este código
  // pegava `empresasIds.first` — mas a RPC `empresas_do_usuario` não tem
  // ORDER BY, então a ordem do array não é garantida (pode variar entre
  // chamadas), então "a empresa atual" era escolhida meio ao acaso a cada
  // carregamento de sessão. A web NUNCA faz isso: `resolverEmpresaAtual` só
  // resolve sozinho quando há EXATAMENTE 1 empresa; com 2+, fica sem empresa
  // selecionada até o usuário escolher explicitamente. Corrigido pra seguir
  // a mesma regra — com 2+ empresas, `empresaId` fica null
  // (`SessaoUsuario.precisaEscolherEmpresa` vira true) até o usuário
  // escolher na tela `/selecionar-empresa` (ver sessao_provider.dart).
  Future<SessaoUsuario> carregarSessao() async {
    final email = emailAtual ?? '';

    final perfil = await _supabase.rpc('perfil_usuario_atual') as String?;

    final empresasIdsRaw = await _supabase.rpc('empresas_do_usuario', params: {'p_email': email});
    final empresasIds = (empresasIdsRaw as List?)?.map((e) => e.toString()).toList() ?? const <String>[];

    String? empresaId;
    String? nomeEmpresa;
    String? segmento;

    if (perfil != 'admin' && empresasIds.length == 1) {
      empresaId = empresasIds.first;
      final empresa = await buscarEmpresa(empresaId);
      nomeEmpresa = empresa?['nome'] as String?;
      segmento = empresa?['segmento'] as String?;
    }

    return SessaoUsuario(
      email: email,
      perfil: perfil,
      empresaId: empresaId,
      nomeEmpresa: nomeEmpresa,
      segmento: segmento,
      empresasIds: empresasIds,
    );
  }

  Future<Map<String, dynamic>?> buscarEmpresa(String id) {
    return _supabase.from('empresas').select('nome, segmento').eq('id', id).maybeSingle();
  }
}
