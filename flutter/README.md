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
- **Achado real (Fase FLT-2):** conta vinculada a 2+ empresas (Rede de
  Postos/grupo econômico) tinha "a empresa atual" resolvida por
  `empresasIds.first` — mas a RPC `empresas_do_usuario` não tem `ORDER BY`,
  então a ordem do array não é garantida, e a empresa escolhida variava
  entre recarregamentos de sessão (descoberto quando "Ciclo em andamento"
  de um cliente não batia com o que a tela de Abastecimentos mostrava — as
  duas podiam estar olhando pra empresas diferentes do mesmo grupo).
  Corrigido pra seguir a mesma regra da web
  (`resolverEmpresaAtual`/`empresaAtual.ts`): só resolve sozinho com
  EXATAMENTE 1 empresa; com 2+, `empresaId` fica `null`
  (`SessaoUsuario.precisaEscolherEmpresa`) até o usuário escolher
  explicitamente na nova tela `lib/features/auth/screens/selecionar_empresa_screen.dart`
  (rota `/selecionar-empresa`, nova "Camada 3" do redirect do router — antes
  da separação por perfil). A escolha fica em
  `empresaSelecionadaProvider` (StateProvider) — não persiste entre
  aberturas do app (aceitável por ora, mesmo esperado pela web sem
  `?empresa=` na URL).
- **Pedido do Daniel:** a tela `/selecionar-empresa` não podia mais ser
  reaberta depois da primeira escolha — a Camada 3 sempre redirecionava
  de volta pra `/` assim que `empresaId` deixava de ser `null`. Agora ela
  também funciona como um seletor de "trocar posto" acessível a qualquer
  momento: item "Trocar posto" no cabeçalho do drawer do posto
  (`posto_home_screen.dart`, só aparece com 2+ empresas vinculadas) abre a
  mesma tela via `context.push`, que agora destaca a empresa atual e tem
  botão de voltar (só quando há pra onde voltar — no gate obrigatório
  continua sem botão de voltar, pra não dar pra pular a escolha). A
  Camada 3 do router só bloqueia acesso voluntário quando não há nada pra
  escolher (1 empresa só); nesse caso o `return null` explícito é
  necessário pra não cair na Camada 4 (perfil) e ser redirecionado de
  volta pra `/posto` por engano.

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
- **Negociações (`/posto/negociacoes` + `/posto/negociacoes/:id`)** — real
  desde a Fase FLT-2. Ver `lib/features/posto/providers/negociacoes_provider.dart`
  (lista), `negociacao_detalhe_provider.dart` (detalhe + rodadas) e
  `lib/features/posto/services/negociacoes_service.dart` (ações). Espelha
  `negociacoes/page.tsx` + `[id]/page.tsx` + `FormularioContraproposta.tsx`
  da web, lado posto: listar com indicadores/filtros, ver histórico de
  rodadas, aceitar/recusar/contrapropor/cancelar. **Importante:**
  `negociacoes_service.dart` é uma PORTA MANUAL de
  `src/lib/negociacoesPostos.ts` (não existe RPC pra essa lógica no banco
  — é regra de negócio em TS, replicada função a função no Dart, incluindo
  os gates de assinatura/documentação e a substituição de negociação aceita
  anterior). Web e app não compartilham código aqui — qualquer mudança
  nessa lógica na web precisa ser espelhada manualmente no Dart, ou vice
  versa. Seria mais seguro migrar isso pra uma função Postgres compartilhada
  numa fase futura. Criar negociação nova (`/posto/negociacoes/novo`) também
  já é real — `NegociacoesService.criarNegociacao`, porta de
  `criarNegociacao` (negociacoesPostos.ts) + a parte do lado posto de
  `criarNegociacaoAcao`. Só cobre "cliente já existe na FNI" (informa o
  CNPJ, precisa dar match via `empresa_id_do_cnpj`) — o provisionamento
  automático de posto novo por e-mail (quando é o CLIENTE que cria a
  negociação) não se aplica aqui, é exclusivo do outro lado.
  **Achado real (Fase FLT-2):** criar negociação dava "Empresa não
  encontrada" com uma conta de posto de teste — a checagem de documentação
  (`_exigirDocumentacaoAprovada`) lia a empresa CLIENTE direto da tabela
  `empresas`, e a RLS só libera SELECT pra quem é membro/admin/superusuário
  daquela empresa (o posto nunca é membro do cliente). Corrigido chamando a
  nova RPC `status_documentacao_empresa_publico` (SECURITY DEFINER, mesmo
  padrão de `nome_empresa_publico`) em vez do SELECT direto. Mesmo bug
  existia na função equivalente da web (`exigirDocumentacaoAprovada` em
  `src/lib/empresasDocumentos.ts`) — corrigido lá também, nunca tinha
  aparecido porque só era testado com a conta superusuária.
- **Abastecimentos (`/posto/abastecimentos`)** — real desde a Fase FLT-2.
  Ver `lib/features/posto/services/abastecimentos_posto_service.dart` e
  `lib/features/posto/screens/abastecimentos_posto_screen.dart`. Espelha
  (com escopo reduzido) `AbastecimentosPosto.tsx` da web: abastecimentos
  fornecidos por este posto via `abastecimentos_unificado` (multi-provedor
  — PróFrotas + externos), com indicadores, filtro de combustível/meio de
  pagamento/cliente/busca/data, e badge de NF-e (emitida/rejeitada/
  pendente) + bolinha de ajuste pendente por linha. Fora do escopo desta
  versão (fica pra uma próxima iteração): paginação de verdade (só traz os
  50 mais recentes que baterem com o filtro), os botões de filtro por
  status de NF-e com contador (só o badge informativo em cada linha), e
  navegação pra tela de detalhe/ajuste do abastecimento (ainda não existe
  no Flutter). **Achado real:** tela quebrava com `type 'int' is not a
  subtype of type 'String?'` — `numero_nf` (`notas_fiscais_abastecimento`/
  `notas_fiscais_pendencias`) é `integer` no banco, não texto; o código
  fazia `as String?` direto. Corrigido pra `?.toString()`. **Achado real
  (2):** não dava pra ver o detalhe do abastecimento nem abrir o fluxo de
  solicitação de ajuste a partir desta tela — corrigido, ver
  "Abastecimento — detalhe/ajuste" abaixo. Cada linha da lista agora navega
  pro detalhe (`context.push('/posto/abastecimentos/\${r.chave}')`).
  **Achado real (3):** nome do cliente aparecia sempre como "—" — mesmo bug
  de RLS cruzada de sempre (`empresas_select_membro` só libera SELECT pra
  membro/admin/superusuário; o posto não é membro das empresas-clientes).
  Atingia dois pontos: a resolução de `clientesOpcoes` (SELECT direto em
  `empresas`) e a busca por nome de cliente no campo de busca livre (`ilike`
  direto em `empresas`). Corrigido: `clientesOpcoes` agora usa a nova RPC
  SECURITY DEFINER `nomes_empresas_publico` (lote); a busca por nome agora
  filtra em memória sobre `clientesOpcoes` já resolvido, em vez de bater de
  novo em `empresas`. Mesmo bug existia na web (`AbastecimentosPosto.tsx`) —
  corrigido lá também.
- **Abastecimento — detalhe/ajuste (`/posto/abastecimentos/:chave`, chave =
  "provedor:id")** — real desde a Fase FLT-2. Ver
  `lib/features/posto/providers/ajuste_abastecimento_provider.dart`,
  `lib/features/posto/services/ajustes_abastecimentos_service.dart` e
  `lib/features/posto/screens/abastecimento_detalhe_screen.dart`. Espelha
  (com escopo reduzido) `abastecimentos/[id]/page.tsx` +
  `abastecimentos/externo/[id]/page.tsx` + `PainelAjusteAbastecimento.tsx` +
  `FormularioSolicitarAjuste.tsx` da web: valores atuais do abastecimento
  (PróFrotas ou externo, via `abastecimentos_unificado`) e o painel de
  ajuste completo — solicitar, ver histórico de rodadas, aprovar/recusar/
  contrapropor/cancelar. `ajustes_abastecimentos_service.dart` é PORTA
  MANUAL de `src/lib/ajustesAbastecimentos.ts` (mesmo aviso de
  `negociacoes_service.dart`: não é RPC, é regra de negócio replicada à mão
  — só `decidirAjuste` chama RPC de verdade, `decidir_ajuste_abastecimento`,
  porque só ela precisa aplicar o valor de fato na tabela de origem).
  Diferente da web (que serve os dois lados e precisa resolver quem é
  posto/cliente por CNPJ), aqui já sabemos: esta tela só existe dentro do
  shell `/posto`, então `empresaPostoId` é sempre a empresa da sessão
  logada — sem precisar de `resolver_empresa_por_cnpj_segmento` nem
  `empresas_do_usuario`. Fora do escopo desta versão: notificação por
  e-mail ao cliente (a web também não tem isso pra ajustes, só pra
  negociações). **Achado real:** `LateInitializationError: Field
  '_dataHora' has already been initialized` ao abrir "Solicitar ajuste",
  cancelar e abrir de novo — o código resetava `_controllersProntos` pra
  `false` sem descartar os controllers `late final` já criados, e
  `_prepararControllers` tentava reatribuí-los (campo `late final` só
  aceita 1 atribuição por instância). Corrigido removendo o reset — os
  controllers são preparados uma única vez por tela (mesmo padrão, sem essa
  falha, já usado em `negociacao_detalhe_screen.dart`).
- **Meus Preços (`/posto/precos`)** — real desde a Fase FLT-2. Ver
  `lib/features/posto/providers/precos_posto_provider.dart` e
  `lib/features/posto/screens/precos_posto_screen.dart`. Espelha (só o lado
  posto — `PainelPosto`, o lado cliente não se aplica aqui) `precos-postos/page.tsx`
  + `FormularioPrecosPosto.tsx` da web: 1 preço por combustível
  (`upsert` em `precos_postos`, sem histórico — campo em branco não grava,
  e também não apaga um preço já salvo, mesma regra da web). Fora do
  escopo desta versão: resolver o NOME de quem atualizou por último (a web
  faz um lookup extra em `usuarios_app`) — mostra só o e-mail.
- **Clientes (`/posto/clientes` + `/posto/clientes/:id`)** — real desde a
  Fase FLT-2. Ver `lib/features/posto/providers/clientes_posto_provider.dart`
  (lista, RPC `clientes_do_posto`) e
  `lib/features/posto/providers/cliente_posto_detalhe_provider.dart`
  (detalhe: negociações + faturas + ciclo em andamento via RPC
  `ciclos_abertos_postos`). Espelha (com escopo reduzido)
  `clientes-posto/page.tsx` + `[clienteId]/page.tsx` +
  `CicloAbastecimentoPagamento.tsx` da web: lista de transportadoras que já
  negociaram com o posto (qualquer status), com cadastro, ciclo atual,
  faturas e negociações no detalhe. Fora do escopo desta versão: geração
  manual de fatura, edição de ciclo/prazo — só leitura.
  - **Detalhe da fatura (`/posto/faturas/:id`)** — pedido do Daniel: clicar
    numa fatura e ver o extrato. Ver
    `lib/features/posto/providers/fatura_posto_detalhe_provider.dart` +
    `lib/features/posto/screens/fatura_posto_detalhe_screen.dart`. Porta
    (com escopo reduzido) de `faturas-postos/[id]/page.tsx`: período,
    vencimento, valor, status e o detalhamento linha a linha dos
    abastecimentos, via a mesma RPC `abastecimentos_da_fatura` (SECURITY
    DEFINER) usada na web. Fora do escopo desta versão: boleto/PDF, QR
    Code PIX, dados de cedente/sacado (CNPJ/endereço completo).
  - **Detalhe do ciclo em andamento (`/posto/ciclos-abertos/:negociacaoId`)**
    — pedido do Daniel: clicar no card "Ciclo em andamento" e ver quais
    abastecimentos compõem o valor acumulado. Ver
    `lib/features/posto/providers/ciclo_aberto_detalhe_provider.dart` +
    `lib/features/posto/screens/ciclo_aberto_detalhe_screen.dart`. Porta de
    `ciclo-aberto/[negociacaoId]/page.tsx`: período/vencimento/valor
    PREVISTOS (o robô fecha automaticamente quando o ciclo termina) + lista
    de abastecimentos com filtro Todos/Com NF-e/Pendente NF-e, via RPC
    `abastecimentos_do_ciclo_aberto` — paginada em lotes de 1000 (mesmo
    achado real da Fase 27.123 na web: o limite padrão do PostgREST,
    db-max-rows, corta silenciosamente ciclos com mais de 1000 linhas).

- **Chamados (`/posto/chamados` + `/posto/chamados/novo` +
  `/posto/chamados/:id`)** — real desde a Fase FLT-2. Ver
  `lib/features/posto/providers/chamados_provider.dart` e
  `lib/features/posto/services/chamados_service.dart`. Espelha (com escopo
  reduzido) `chamados/page.tsx` + `chamados/[id]/page.tsx` +
  `ThreadChamado.tsx` + `ChamadoForm.tsx` + `lib/chamados.ts` da web:
  indicadores (abertos/em análise/resolvidos/não vistos), filtro por
  status, abrir chamado (tipo/título/descrição/prioridade/anexo opcional),
  thread de mensagens tipo chat + anexos, botão "marcar como resolvido".
  Sem o seletor de "Cliente" da listagem web (só existe pra admin, que
  enxerga tickets de todos os clientes — a visão posto já é uma única
  empresa) e sem `ControlesAdminChamado` (status/prioridade manuais são
  decisão da equipe FNI, não do posto). **Importante:**
  `chamados_service.dart` é uma PORTA MANUAL de `chamados/actions.ts`
  (mesmo aviso de `negociacoes_service.dart`/
  `ajustes_abastecimentos_service.dart` — não existe RPC pra essa lógica,
  é regra de negócio replicada à mão, incluindo a resolução de "papel"
  do usuário — admin/time FNI vs. usuário comum — usada pra rotular autor
  de comentário e decidir qual coluna de "visto" atualizar). Upload de
  anexo usa `file_picker` (já dependência do projeto, antes só usado pela
  tela legada `/tickets` do shell genérico, que fala com a API Python
  antiga e não deve ser confundida com esta) + `Supabase.storage` no
  bucket privado `ticket-anexos`, com URL assinada (1h) pra download —
  mesmo padrão da web. Fora do escopo desta versão: a bolinha de
  notificação de "não vistos" no item do menu lateral (Fase 27.150 na
  web só existe pra Aprovação de Documentos do admin; aqui o contador só
  aparece dentro da própria tela de Chamados, nos indicadores).

- **Rede de Postos (`/posto/rede-postos` + `/posto/rede-postos/nova`)** —
  real desde a Fase FLT-2. Ver `lib/features/posto/providers/
  rede_posto_provider.dart` e `lib/features/posto/services/
  rede_postos_service.dart`. Espelha (com escopo reduzido)
  `rede-postos/[id]/page.tsx` + `rede-postos/novo/page.tsx` +
  `RedeForm.tsx` + `VincularPostoForm.tsx` + `NovaRedeForm.tsx` +
  `src/lib/gruposEconomicos.ts` da web: se a empresa atual ainda não
  pertence a nenhuma Rede, mostra estado vazio com botão "Criar Rede de
  Postos" (nome + CNPJ da matriz opcional + posto fundador, via RPC
  `criar_rede_posto_self_service`); se já pertence, mostra os dados da
  Rede (editáveis: nome/CNPJ/ativa) + lista de postos vinculados, com
  vincular/desvincular (usando só os postos que o próprio login já
  controla — `sessao.empresasIds`, a mesma lista da RPC
  `empresas_do_usuario` que a web usa em "postosDisponiveis" pra quem não
  é admin). Sem o caminho admin (visão global de todas as Redes, escolher
  qualquer posto Revenda como fundador de outro) — não se aplica, o
  Flutter só existe pro shell `/posto`. **Importante:**
  `rede_postos_service.dart` replica em código a checagem de documentação
  societária aprovada (`_exigirDocumentacaoAprovada`, mesmo padrão de
  `negociacoes_service.dart`) — confirmado lendo a função
  `criar_rede_posto_self_service` no banco que essa checagem só existe na
  camada TS/Dart, não na RPC nem na RLS.

- **Assistente FNI (`/posto/assistente`)** — real desde a Fase FLT-2. Ver
  `lib/features/posto/services/assistente_service.dart` e
  `lib/features/posto/screens/assistente_screen.dart`. Porta de
  `ChatAssistente.tsx` da web, mas com uma diferença de arquitetura em
  relação a TODAS as outras telas do Flutter: as demais falam direto com o
  Supabase (RLS cuida da segurança); esta chama a IA (Claude, via API da
  Anthropic) que roda com uma chave secreta (`ANTHROPIC_API_KEY`) —
  segredo que nunca pode ir pro bundle JS do app. Por isso foi criada uma
  rota nova no site (`POST /api/assistente`, ver `route.ts` no repo Gestão
  de Frotas), autenticada com o próprio access_token da sessão Supabase do
  usuário (`Authorization: Bearer <token>` em vez de cookies — o app não
  compartilha domínio com o site) — a rota valida o token, monta um client
  Supabase "como" aquele usuário (RLS aplica normalmente) e chama a MESMA
  `perguntarAssistente()` já usada pela web. Chat com histórico só em
  memória (fecha a tela, perde a conversa — igual a web), perguntas
  sugeridas, indicação de quantas consultas SQL o Assistente rodou por
  resposta. Fora do escopo desta versão: exportar a conversa em PDF
  (`BotaoBaixarPdfAssistente*.tsx` na web).

- **Minha Assinatura (`/posto/assinatura`)** — real desde a Fase FLT-2. Ver
  `lib/features/posto/providers/assinatura_provider.dart`,
  `lib/features/posto/services/assinatura_service.dart` e
  `lib/core/constants/termo_adesao.dart`. Porta de
  `assinatura/page.tsx` + `BotaoAssinarPlano.tsx` + `ModalTermoAdesao.tsx` +
  `BotaoPortalPagamento.tsx`, escopo reduzido ao caminho POSTO (a web tem
  dois critérios de dimensionamento de plano — usuários/veículos pra
  frota, tamanho da Rede de Postos pra posto, Fase 27.125 — aqui só o
  segundo se aplica). Mostra plano atual/status/postos na Rede, banner de
  trial, os 3 planos com preço real (buscado da Edge Function
  `planos-precos`, nunca hardcoded) e destaque do recomendado pelo tamanho
  da Rede, histórico de faturas. Botão "Assinar" abre o Termo de Adesão
  (texto legal completo, igual à web) — só depois de marcar "li e aceito"
  chama a MESMA Edge Function `create-checkout-session` da web (com
  `aceite_termo: true`) e abre a URL do Stripe Checkout no navegador
  externo (`url_launcher`, `LaunchMode.externalApplication` — o app não
  processa pagamento, só entrega pro Stripe). Botão "Gerenciar pagamento"
  idem, via `create-billing-portal-session`. **Importante:** não gera nem
  sobe o comprovante em PDF do aceite do termo (`@react-pdf/renderer` não
  tem equivalente direto no Flutter) — confirmado lendo o código da Edge
  Function que o registro de aceite (hash/versão/IP/timestamp — o que
  importa legalmente) é gravado no banco (`termos_aceite`) ANTES da sessão
  do Stripe ser criada, então não depende do PDF pra ser válido; na web o
  PDF é só um comprovante anexado depois no e-mail de confirmação. Outra
  observação: como a Edge Function usa uma URL de retorno fixa
  (`DASHBOARD_URL`, o site Next.js), depois do checkout o usuário é
  redirecionado pro site — não volta direto pro app.

- **Avaliar Plataforma (`/posto/avaliar`)** — real desde a Fase FLT-2. Ver
  `lib/features/posto/providers/avaliacoes_provider.dart`,
  `lib/features/posto/services/avaliacoes_service.dart`. Porta de
  `avaliar/page.tsx` + `FormularioAvaliacao.tsx` + `src/lib/avaliacoes.ts`:
  estrelas (1 a 5) + observações opcionais, histórico das avaliações
  anteriores com a resposta da equipe FNI quando houver. Sem o seletor de
  "sobre qual cliente é esta avaliação" (só faz sentido pra quem enxerga
  vários clientes — o shell `/posto` sempre tem uma única empresa atual).
  Tela mais simples desta fase: sem gates de documentação/assinatura, RLS
  (`avaliacoes_insert_proprio`) já garante que o insert vale só com o
  próprio e-mail.

- **Financeiro (`/posto/financeiro`)** — real desde a Fase FLT-2. Ver
  `lib/features/posto/providers/financeiro_posto_provider.dart`,
  `lib/features/posto/services/financeiro_posto_service.dart`. Porta de
  `financeiro-posto/page.tsx` + `src/lib/financeiroPostos.ts` +
  `financeiro-posto/actions.ts` — a tela mais complexa da web até agora,
  então esta versão tem escopo bem reduzido: seletor de período (Hoje/7
  dias/15 dias/Mês atual — sem "personalizado"), os 6 indicadores
  principais (a receber em aberto, vencido, recebido no período, a pagar
  em aberto, pago no período, saldo previsto — calculados no cliente, mesma
  lógica de `.reduce()` da web), consolidado por meio de pagamento
  (`abastecimentos_unificado` por `posto_cnpj`) e contas a pagar (despesas)
  com lançar/marcar paga/excluir. **Fora do escopo desta versão:** gráfico
  de fluxo de caixa por dia (`GraficoFluxoCaixaPosto`), tabela de aging
  (faixas de atraso), visão agrupada por cliente
  (`VisaoCiclosPorContraparte` — já dá pra ver o ciclo/fatura de cada
  cliente em `/posto/clientes/:id`) e o resumo de ajustes de abastecimento
  (`SecaoAjustesAbastecimentos` — cada ajuste específico já é visto no
  detalhe do abastecimento). Faturas são só leitura aqui (mudar status de
  fatura continua sendo via `/posto/clientes/:id` → `/posto/faturas/:id`,
  já construído em fase anterior).

As demais telas viram funcionalidade real uma de cada vez, nas próximas
fases. **Exceção — decisão do Daniel:** "Notas Fiscais" e "Integrações"
ficam só na visão web, não fazem parte do escopo do PWA — removidas do
menu (`posto_home_screen.dart`) e das rotas (`app_router.dart`), em vez de
placeholder.

## Telas
- Login (e-mail/senha e Google)
- Abastecimentos
- Frota
- Financeiro
- Tickets
