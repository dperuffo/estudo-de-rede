# FNI Gestao de Frotas - Flutter

## Setup
```
cd flutter
flutter pub get
flutter run
```

## Backend

**Fase FLT-1 (em andamento):** migrando de uma API Python própria
(`api.fxgestaodefrotasonline.com`) para o Supabase direto — mesmo projeto
usado pela aplicação web Next.js (`nedthbeekvwzcjrhsghp`), com Auth + RLS +
as mesmas RPCs já documentadas no README da web.

- URL/anon key do Supabase: `lib/core/services/supabase_service.dart`.
- Login: `lib/core/services/auth_service.dart` — e-mail/senha e Google,
  espelhando `src/app/login/actions.ts` da web (`entrarComSenha` /
  `entrarComGoogle`).
- MFA (TOTP) obrigatório, mesmo gate do `layout.tsx` da web — ver
  `lib/features/mfa/screens/mfa_pendente_screen.dart`. Fase FLT-1b: a tela
  já pede o código de 6 dígitos (desafio de login, `challengeAndVerify`)
  pra quem já tem fator verificado; só o CADASTRO do fator (QR code)
  continua só na web por enquanto.
- Roteamento por perfil: `lib/core/router/app_router.dart` resolve
  perfil/segmento (`lib/core/services/sessao_provider.dart`) e manda quem é
  "posto" pro shell próprio (`/posto/...`); cliente/admin continuam no shell
  genérico existente por enquanto.

A API Python antiga (`ApiConstants.baseUrl`) continua sendo usada pelas
telas que ainda não foram migradas (Abastecimentos, Frota, Financeiro,
Tickets, etc. — ver `lib/core/services/api_service.dart`). Migrar cada uma
pro Supabase é o trabalho da Fase FLT-2 em diante.

## Pendência de configuração (não é código)

Login com Google via `signInWithIdToken` só funciona de verdade se o
provider "Google" estiver habilitado no Supabase (Dashboard → Authentication
→ Providers) com um Client ID Web autorizado pra este app — o Client ID
hoje hardcoded em `auth_service.dart` era da integração com a API antiga.
Login por e-mail/senha não depende disso.

## Visão Posto (Fase FLT-1/FLT-2)

Shell novo em `lib/features/posto/`, espelhando o menu
`menuPostoGestao`/`menuPostoOperacao` de `src/app/(dashboard)/layout.tsx` na
web. Telas ainda placeholders (`EmConstrucaoScreen`), exceto:

- **Dashboard (`/posto`)** — real desde a Fase FLT-2. Ver
  `lib/features/posto/providers/dashboard_posto_provider.dart` (busca via
  Supabase: `negociacoes_postos` + RPC `resumo_vendas_diarias_posto`) e
  `lib/features/posto/screens/posto_dashboard_screen.dart`. Espelha
  `DashboardPosto.tsx` da web (indicadores de venda 30 dias, desempenho por
  combustível, indicadores/listas de negociações). Não incluído ainda: o
  gráfico evolutivo diário (`GraficoEvolutivoPostos`) e a seção de Ajustes
  de Abastecimentos — ficam pra uma próxima iteração.
- **Meu Posto (`/posto/meu-posto`)** — real desde a Fase FLT-2. Ver
  `lib/features/posto/providers/meu_posto_provider.dart` e
  `lib/features/posto/screens/meu_posto_screen.dart`. Espelha
  `MeuPostoForm.tsx` da web (Fase 27.137): cadastro do estabelecimento
  (CNPJ, razão social, endereço, contatos, lat/long) verificado contra a
  base ANP via a mesma RPC `verificar_e_registrar_posto_anp`. Não incluído
  ainda: o botão "usar minha localização atual" (Geolocation API do
  navegador na web) — lat/long são preenchidos à mão por enquanto.

As demais telas viram funcionalidade real uma de cada vez, nas próximas
fases.

## Telas
- Login (e-mail/senha e Google)
- Abastecimentos
- Frota
- Financeiro
- Tickets
