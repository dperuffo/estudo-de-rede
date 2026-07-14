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

  SupabaseClient get _supabase => SupabaseService.client;

  // Espelha entrarComSenha (web/src/app/login/actions.ts).
  Future<void> signInWithPassword({required String email, required String senha}) async {
    await _supabase.auth.signInWithPassword(email: email.trim().toLowerCase(), password: senha);
  }

  // Fase FLT-1b/FLT-3 (hotfix) — troca de estratégia. A versão original
  // usava o pacote google_sign_in (popup imperativo) + signInWithIdToken,
  // igual ao comentário antigo dizia. Achado real testando com o Daniel:
  // no Console do navegador aparecia [GSI_LOGGER-TOKEN_CLIENT] "Starting
  // popup flow" seguido de uma chamada a people.googleapis.com buscando
  // nome/e-mail/foto — ou seja, o Google Identity Services só devolvia um
  // access_token, nunca um id_token, por isso o
  // "Não foi possível obter o idToken do Google." sempre acontecia. Isso é
  // um comportamento conhecido do google_sign_in no Flutter Web (o método
  // signIn() imperativo foi descontinuado pelo Google pra esse fim — só
  // funciona de verdade via um botão renderizado pelo GIS, que dá mais
  // trabalho de implementar). Troca: usar o signInWithOAuth do próprio
  // Supabase (fluxo de redirect PKCE) — a troca do código de autorização
  // pelo token acontece no backend do Supabase, sem depender de idToken
  // nenhum no navegador. Único pré-requisito (fora do código, configuração
  // no Supabase): a URL do app precisa estar na lista de Redirect URLs em
  // Supabase Dashboard → Authentication → URL Configuration (ex.:
  // http://localhost:5173/** pra dev e o domínio do Railway pra produção).
  //
  // Achado real (2ª rodada de teste com o Daniel) — sem `redirectTo`
  // explícito, o Supabase NÃO volta pra página atual: ele manda pra "Site
  // URL" configurada no projeto (que aponta pra landing page da web), daí
  // o Daniel caindo na landing depois de logar com Google. Corrigido
  // passando `redirectTo: Uri.base.origin` — a origem (protocolo+host+
  // porta) de onde o PWA está rodando NA HORA, funciona igual em dev
  // (http://localhost:5173) e produção (domínio do Railway) sem precisar
  // hardcodar nada.
  //
  // Achado real (3ª rodada de teste) — mesmo com `http://localhost:5173/**`
  // cadastrado em Redirect URLs no Supabase, o Daniel continuava caindo na
  // Site URL (landing page da web). Suspeita: `Uri.base.origin` manda a
  // URL SEM barra no final (`http://localhost:5173`), e o padrão `/**`
  // cadastrado no Supabase pode exigir que o valor recebido já comece com
  // a barra (`http://localhost:5173/...`) pra bater — sem ela, não casa
  // com nenhum padrão da lista e o Supabase cai no padrão (Site URL).
  // Corrigido adicionando a barra final explicitamente.
  Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: '${Uri.base.origin}/',
    );
  }

  Future<void> signOut() async {
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
  // Fase FLT-4 (achado real) — o admin (time interno FNI) não é "membro" de
  // nenhuma empresa via usuarios_empresas, então empresas_do_usuario sempre
  // devolvia lista vazia pra ele: `empresaId` ficava permanentemente null
  // (a guarda `perfil != 'admin'` abaixo já evitava um autoseleção errada),
  // mas `precisaEscolherEmpresa` também nunca virava true (dependia de
  // `empresasIds.length > 1`, sempre 0 pro admin) — o app ficava
  // travado/vazio pro admin, sem seletor pra escolher qual cliente ver.
  // Corrigido: pro admin, `empresasIds` passa a listar TODAS as empresas
  // segmento "Frota" (só essas — segmento "Revenda"/postos usa o shell
  // /posto, com telas e tabelas diferentes, fora do que este shell genérico
  // sabe mostrar; RLS de `empresas` já libera SELECT total pro admin, mesmo
  // padrão de resolverEmpresaAtual na web). Com isso, o mecanismo de
  // seleção — já usado pra grupo econômico — funciona pro admin sem
  // precisar de nenhum código novo em SessaoUsuario/app_router além da
  // fórmula de `precisaEscolherEmpresa` (ver sessao_usuario.dart).
  Future<SessaoUsuario> carregarSessao() async {
    final email = emailAtual ?? '';

    final perfil = await _supabase.rpc('perfil_usuario_atual') as String?;

    List<String> empresasIds;
    if (perfil == 'admin') {
      final rows = await _supabase.from('empresas').select('id').eq('segmento', 'Frota').order('nome') as List;
      empresasIds = rows.map((m) => (m as Map<String, dynamic>)['id'] as String).toList();
    } else {
      final empresasIdsRaw = await _supabase.rpc('empresas_do_usuario', params: {'p_email': email});
      empresasIds = (empresasIdsRaw as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    }

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
