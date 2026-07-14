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

Login com Google via `signInWithOAuth` (ver hotfix na seção FLT-3 abaixo) só
funciona de verdade se: (1) o provider "Google" estiver habilitado no
Supabase (Dashboard → Authentication → Providers), e (2) a URL do app
estiver cadastrada em Supabase Dashboard → Authentication → URL
Configuration → Redirect URLs (ex.: `http://localhost:5173/**` pra dev e o
domínio do Railway pra produção — sem isso o Supabase recusa o redirect de
volta). Login por e-mail/senha não depende disso.

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
  `src/lib/ciclosAbertos.ts` + `financeiro-posto/actions.ts` — a tela mais
  complexa da web até agora, então esta versão tem escopo reduzido:
  seletor de período (Hoje/7 dias/15 dias/Mês atual — sem
  "personalizado"), os 6 indicadores principais (a receber em aberto,
  vencido, recebido no período, a pagar em aberto, pago no período, saldo
  previsto — calculados no cliente, mesma lógica de `.reduce()` da web),
  consolidado por meio de pagamento (`abastecimentos_unificado` por
  `posto_cnpj`), **Ciclos por Cliente** (`VisaoCiclosPorContraparte` na
  web — 1 linha por cliente com o ciclo atual em andamento + resumo de
  faturas por status, filtros Todos/Em andamento/Em aberto/Vencida/Paga +
  busca por nome, com "Ver detalhamento" abrindo
  `/posto/ciclos-abertos/:negociacaoId` e "Ver histórico" abrindo
  `/posto/clientes/:id` — porta fiel de `agruparCiclosPorContraparte`,
  inclusive a ordem de prioridade vencida > aberta > ciclo em andamento >
  histórico) e contas a pagar (despesas) com lançar/marcar paga/excluir.
  **Fora do escopo desta versão:** gráfico de fluxo de caixa por dia
  (`GraficoFluxoCaixaPosto`), tabela de aging (faixas de atraso) e o
  resumo de ajustes de abastecimento (`SecaoAjustesAbastecimentos` — cada
  ajuste específico já é visto no detalhe do abastecimento). Faturas são
  só leitura aqui (mudar status de fatura continua sendo via
  `/posto/clientes/:id` → `/posto/faturas/:id`, já construído em fase
  anterior).

- **Privacidade (LGPD) (`/posto/lgpd`)** — real desde a Fase FLT-2. Ver
  `lib/features/posto/providers/lgpd_provider.dart`,
  `lib/features/posto/services/lgpd_service.dart`. Porta de
  `lgpd/page.tsx` + `lgpd/actions.ts`. **Achado real:** na web é UMA ÚNICA
  rota (`/lgpd`) compartilhada por cliente e posto — o conteúdo é idêntico
  pros dois perfis, só o link no menu muda de lugar; a única bifurcação de
  UI de verdade é admin x não-admin. Como o shell `/posto` nunca é acessado
  por admin, portamos só os 4 blocos "não-admin": dados cadastrais
  (leitura de `usuarios_app`), revogar consentimento (grava em
  `lgpd_consents`), solicitar exclusão dos meus dados (grava em
  `lgpd_exclusoes`, com checagem de duplicidade pendente + histórico das
  próprias solicitações) e histórico de consentimento. **Escopo
  reduzido:** a Server Action da web captura IP/user-agent a partir dos
  headers da requisição (só possível rodando no servidor Next.js) — sem
  equivalente no Flutter, que fala direto com o Supabase; os registros
  gravados pelo app ficam com esses dois campos nulos (o que importa
  legalmente — e-mail, tipo, timestamp — continua gravado normalmente). O
  bloco "todas as solicitações de exclusão" (admin) não existe aqui, nem
  a ação de marcar como executada (RLS já bloqueia isso pra quem não é
  admin, mesmo que tentasse).

- **Meus Dados / PIX (`/posto/meus-dados`)** — real desde a Fase FLT-2.
  Ver `lib/features/posto/providers/meus_dados_provider.dart`,
  `lib/features/posto/services/meus_dados_service.dart`. Porta de
  `minha-empresa/page.tsx` + `minha-empresa/actions.ts` (`FormularioPix` +
  `FormularioDadosBancarios`) — mesma tabela `empresas` de "Meu Posto",
  colunas diferentes: `pix_chave` (Fase 27.92, usada como cedente no
  boleto) e as 9 colunas de dados bancários da Fase 27.141 (`banco_codigo`,
  `banco_nome`, `agencia`, `agencia_digito`, `conta`, `conta_digito`,
  `tipo_conta` — só aceita "corrente"/"poupanca" — `titular_nome`,
  `titular_documento`), com os mesmos limites de tamanho por campo
  validados client-side da web. Nome/CNPJ do posto aparecem só como
  referência (somente leitura) — editar isso continua sendo em "Meu
  Posto". **Fora do escopo:** o seletor de posto que a web mostra quando o
  usuário tem 2+ postos Revenda ou é admin — o shell `/posto` só resolve
  UMA empresa atual por vez (troca pelo seletor já existente no shell,
  Fase FLT-2 "seletor de empresa").

- **Documentos (`/posto/documentos`)** — real desde a Fase FLT-2. Ver
  `lib/features/posto/providers/documentos_provider.dart`,
  `lib/features/posto/services/documentos_service.dart`. Porta de
  `documentos/page.tsx` + `documentos/actions.ts` +
  `src/lib/empresasDocumentos.ts` (Fase 27.149) — documentação societária
  self-service: 2 documentos de empresa (Contrato Social/Estatuto,
  comprovante de endereço), quadro de sócios (nome + CPF, criar/remover)
  com 3 documentos cada (CPF, RG/CNH, comprovante de endereço), upload
  pro bucket privado `documentos-empresas` (mesmo path convencionado da
  web: `{empresa_id}/{tipo}[-{socio_id}].{ext}`, reenvio substitui o
  anterior via `upsert:true`, limite de 5 MB, `.pdf/.jpg/.jpeg/.png`,
  link de abrir via URL assinada de 1h) e botão "Enviar para análise" com
  a mesma validação de completude da web
  (`validarDocumentacaoCompleta`) rodando client-side antes de marcar
  `documentacao_status='pendente'`. Badge + banner de status
  (não iniciada/em análise/aprovada/rejeitada com motivo). **Fora do
  escopo:** o lado admin (fila de aprovação, `/documentos-empresas`) —
  isso é ferramenta interna da equipe FNI, nunca acessada pelo shell
  `/posto`. Os 4 "gates de bloqueio" que exigem documentação aprovada
  (criar/vincular Rede de Postos, criar/aceitar negociação) já estavam
  replicados em fases anteriores deste app (`rede_postos_service.dart`,
  `negociacoes_service.dart`) via a mesma RPC pública
  `status_documentacao_empresa_publico` da web — nada novo aqui, só
  documentando a ligação.

- **Usuários (`/posto/usuarios`)** — real desde a Fase FLT-2, a última aba
  desta fase. Ver `lib/features/posto/providers/usuarios_provider.dart`,
  `lib/features/posto/services/usuarios_service.dart`. Porta de
  `usuarios/page.tsx` + `usuarios/[email]/page.tsx` +
  `usuarios/novo/page.tsx` + `usuarios/actions.ts`. **Achado real +
  decisão confirmada com o Daniel:** convidar usuário usa a Auth Admin API
  do Supabase (`inviteUserByEmail`), que exige a SERVICE ROLE KEY — chave
  secreta que nunca pode ir pro bundle do app (mesma situação do
  Assistente FNI). Criada a rota `POST /api/usuarios/convidar` (repo
  `Gestão de Frotas`, `src/app/api/usuarios/convidar/route.ts`),
  autenticada por Bearer token da sessão Supabase, que replica os mesmos 3
  passos de `criarUsuario()`: convite no Auth → upsert `usuarios_app` →
  upsert `usuarios_empresas` (`role = perfil`). Endurecimento em relação à
  web (não um bug corrigido, um cuidado a mais por esta ser uma rota HTTP
  nova, chamável por qualquer posto autenticado): a rota confere, com o
  client RLS-scoped do próprio chamador, que ele pertence à empresa pra
  qual está convidando, antes de trocar pro client admin — a Server Action
  original não tinha essa checagem porque só é alcançável hoje por quem já
  é admin dentro do dashboard autenticado por sessão. Lista: usuários
  vinculados ao posto atual (via `usuarios_empresas` filtrado por
  `empresa_id` — nisso diverge da web, que lista "o que a RLS deixa ver",
  sem filtro de empresa no código; aqui filtramos explicitamente pra ficar
  mais útil: "quem tem acesso ao MEU posto"), com indicadores de
  total/ativos/com MFA. Editar: nome/CPF/telefone/ativo (perfil e segmento
  ficam fixos em "posto"/"Revenda", definidos no convite — sem o dropdown
  de perfil da web, que também atende Frota/admin na mesma tela). MFA é
  só leitura (nem a web tem resetar MFA de terceiros). **Fora do escopo:**
  importação de usuários em lote via planilha (`/usuarios/importar`).

As demais telas viram funcionalidade real uma de cada vez, nas próximas
fases. **Exceção — decisão do Daniel:** "Notas Fiscais" e "Integrações"
ficam só na visão web, não fazem parte do escopo do PWA — removidas do
menu (`posto_home_screen.dart`) e das rotas (`app_router.dart`), em vez de
placeholder.

## Indicadores gráficos (Dashboard + Financeiro, visão Posto)

Pedido do Daniel: "começar a desenvolver indicadores gráficos" no PWA,
citando Dashboard e Financeiro como exemplos. `fl_chart` já era dependência
usada no shell genérico/cliente (`dashboard_screen.dart`,
`financeiro_screen.dart`, `precos_screen.dart`, `analise_cliente_screen.dart`)
— nada disso existia ainda na visão Posto, que só tinha números em cards.
Confirmado com o Daniel: os 2 gráficos com equivalente na web + 2 donuts
novos (sem equivalente na web ainda), só nessas 2 telas por ora.

- **Dashboard (`posto_dashboard_screen.dart`/`dashboard_posto_provider.dart`)**
  — linha "Venda diária por combustível" (porta de `GraficoEvolutivoPostos.tsx`
  da web): 1 linha por combustível, últimos `janelaGraficoDias` (14) dias,
  reaproveitando a MESMA resposta da RPC `resumo_vendas_diarias_posto` que
  já alimentava os KPIs (só precisou agregar por dia+combustível em vez de
  só por combustível total — novo campo `serieDiariaPorCombustivel`). Donut
  de participação por combustível (novo, sem equivalente na web) usando
  `desempenhoPorCombustivel`, já calculado.
- **Financeiro (`financeiro_posto_screen.dart`/`financeiro_posto_provider.dart`)**
  — barras agrupadas "Fluxo de caixa previsto" (porta de
  `GraficoFluxoCaixaPosto.tsx`): a receber (verde) x a pagar (vermelho) por
  dia de vencimento, na MESMA janela prospectiva (`janelaPrevista`) que já
  alimentava os KPIs "vencendo no período"/"saldo previsto" — só quebrada
  por dia em vez de só o total (`_dadosFluxoCaixa`, calculado na tela, não
  no provider, por depender do período selecionado). Donut de consolidado
  por meio de pagamento (novo) usando `indicadoresPorProvedor`, já
  calculado — paleta sólida separada (`_corSolidaMeioPagamento`) da paleta
  pastel já usada nos avatares da lista, só pro gráfico/legenda (mais
  contraste).

Mesmo padrão visual dos gráficos já existentes no app (cor azul/gradiente
nas barras, curva suave com área leve nas linhas, tooltip formatado em
R$/L, legenda manual). **Fora do escopo desta rodada:** gráficos em outras
telas (Preços, Abastecimentos) — Daniel optou por fechar só Dashboard e
Financeiro por ora.

## Telas
- Login (e-mail/senha e Google)
- Abastecimentos
- Frota
- Financeiro
- Tickets

## Fase FLT-3 — visão Cliente (reconstrução do zero)

Pedido do Daniel: "vamos partir para o desenvolvimento da visão de cliente
no PWA". **Achado real, antes de escrever qualquer código:** o "shell
genérico" (usado até então por qualquer perfil não-posto — cliente ou
admin) tinha 18 telas com CARA de reais (StatefulWidget, chamadas de rede,
centenas de linhas), mas todas usavam um backend Python legado
(`api.fxgestaodefrotasonline.com`, ver `api_service.dart`) autenticado por
um `jwt_token` gravado no `FlutterSecureStorage` — mecanismo apagado no
commit da migração pra Supabase Auth (Fase FLT-1, `78c181a`), sem nunca ter
sido substituído. Ou seja: nenhuma dessas 18 telas funcionava de fato,
todo request protegido caía em 401 em silêncio. "Visão cliente" não
existia — decisão do Daniel (confirmada antes de começar) foi reconstruir
do zero, mesmo padrão da Fase FLT-2 (Riverpod + Supabase direto/RLS), tela
por tela, igual foi feito pro Posto.

**Escopo:** espelha exatamente o menu cliente da web
(`src/app/(dashboard)/layout.tsx`: seções Gestão, Cadastros, Operação,
Configurações). **Descartadas** (sem equivalente no menu cliente atual —
sobras de uma versão mais antiga do produto): Frota (`/frota`, nunca teve
link no menu nem na web), Manutenção antiga (`/manutencao` — diferente de
"Manutenção Preditiva", que É real na web e está na lista de tarefas),
Variação de Preços como página própria (`/precos` — na web é só um widget
dentro do Dashboard), Análise de Cliente (`/analise-cliente`) e Acordos de
Preço (`/acordos`). A separação cliente × admin dentro do shell genérico
(hoje qualquer perfil "não-posto" vê o mesmo menu) segue fora de escopo —
mesma decisão da Fase FLT-1, revisitada e mantida ao iniciar a FLT-3.

- **Shell/menu** (`lib/features/home/screens/home_screen.dart`) — reescrito
  do zero, mesma identidade visual do menu do Posto (fundo `frota-950`,
  card branco com a logo, "Trocar empresa" pra quem tem 2+ empresas
  vinculadas). Cada rota do menu cliente vira `EmConstrucaoScreen` até
  virar tela de verdade, uma de cada vez (ver `app_router.dart`).
- **Dashboard** (`lib/features/dashboard/`) — primeira tela reconstruída,
  porta de `dashboard/page.tsx` (ramo cliente/frota — o ramo posto já foi
  portado à parte na FLT-2). **Escopo bem reduzido em relação à web**, que
  tem MUITO mais coisa nessa página só (seletor de cliente+período no
  topo, "Primeiros Passos", seção de Ajustes de Abastecimento, Desempenho
  por Centro de Custo, KPIs de Manutenção Preditiva, e 8 "Indicadores
  avançados" — cada um com sua própria RPC e gráfico). Esta primeira
  versão traz: 6 KPIs do mês, consolidado por meio de pagamento, gráfico
  de consumo dos últimos 6 meses (litros — a web usa 2 eixos Y, litros e
  valor; simplificado aqui pra 1 eixo + valor no tooltip, mais legível em
  tela pequena), CNH vencendo em 30 dias e Top 5 clientes por gasto (rede
  toda, não escopado ao cliente selecionado — mesmo comportamento
  intencional da web). O resto fica para as próximas iterações.
  **Otimização em relação à web:** o "Top 5 clientes por gasto" na web
  busca TODOS os campos de `abastecimentos_unificado` da rede inteira só
  pra somar por empresa; aqui a consulta busca só `empresa_id` e
  `valor_total` — mesmo resultado, payload bem menor (relevante no
  celular).
- **Assistente FNI, Minha Assinatura, Avaliar Plataforma** — reaproveitam
  direto as telas/providers/services já portados pro Posto na FLT-2 (eram
  100% genéricos, não específicos de perfil): `AssistenteClienteScreen`,
  `AssinaturaClienteScreen` (com `assinatura_cliente_provider.dart` novo,
  dimensionamento por usuários/veículos em vez de Rede de Postos) e
  `AvaliacaoScreen`.
- **Painel Financeiro** (`lib/features/financeiro/`) — porta reduzida de
  `financeiro/page.tsx`. Mantém os 7 KPIs do mês (`indicadores_
  financeiros`), consolidado por meio de pagamento (donut, mesmo padrão do
  Financeiro Posto), evolução mensal de 6 meses (combustível/manutenção/
  custos fixos, gráfico de barras agrupadas) e "Cobrança em Aberto" — esta
  última reaproveitando DIRETO `agruparPorContraparte`/`LinhaContraparte`
  já portados pro Financeiro do Posto (lá a contraparte é o cliente, aqui é
  o posto; a função é agnóstica, só lê os campos do mapa que a gente
  monta). Fora do escopo: os 2 formulários de CRUD (Planejar orçamento /
  Lançar custo fixo — cada um merece sua própria iteração), a tabela de
  Orçamento por categoria, o link pra Planos de Viagem (tela que nem existe
  ainda) e o ramo só-admin de indicadores FNI. Período fixo (mês atual pros
  KPIs/provedor, 6 meses pra evolução) — sem seletor customizado por ora.
  **Drill-down** (pedido do Daniel, adicionado depois do v1): "Ver
  detalhamento" no ciclo em andamento e lista "Últimas faturas" (10 mais
  recentes) levam pras telas de detalhe, reaproveitando DIRETO
  `faturaPostoDetalheProvider`/`cicloAbertoDetalheProvider` (FLT-2) — a
  consulta já era genérica (busca por id, RLS decide quem vê); só
  adicionamos o campo `postoNome` no provider de fatura (via
  `nome_empresa_publico`, já que `faturas_postos` só tinha `cliente_nome`
  denormalizado) e trocamos o rótulo "Cliente" por "Posto" nas telas novas
  (`fatura_detalhe_screen.dart`, `ciclo_aberto_detalhe_screen.dart` — esta
  com a classe renomeada pra `CicloAbertoClienteDetalheScreen` pra não
  colidir com a homônima do Posto). "Ver histórico" (pedido do Daniel, 2ª
  rodada) leva pro `PostoCobrancaDetalheScreen` novo (rota
  `/postos-cobranca/detalhe`, sem `:id` de propósito — os dados (ciclo +
  TODAS as faturas do posto, não só as 10 mais recentes) já estavam
  carregados na tela de Financeiro, passados via `extra` do GoRouter em
  vez de uma consulta nova). Escopo mais enxuto que `/posto/clientes/:id`:
  sem cadastro do posto nem negociações — isso fica pra futura tela
  Postos Revendedores.
- **Documentos** (`/documentos`) — porta 1:1, sem tela nova nenhuma: o
  próprio `documentos_provider.dart` da FLT-2 já documentava "mesma tela
  pra posto e cliente na web (só muda o grupo do menu onde o link
  aparece) — não há bifurcação de campos/fluxo por segmento". Bastou
  trocar a rota `/documentos` de `EmConstrucaoScreen` pra
  `DocumentosScreen` (mesma classe usada em `/posto/documentos`) direto no
  `app_router.dart`.
- **Inteligência de Rede** (`lib/features/inteligencia_rede/`) — porta
  **drasticamente reduzida** de `inteligencia-rede/page.tsx`: a página na
  web tem 941 linhas, ~15 RPCs em paralelo e 20 componentes (mapas
  Leaflet, cobertura por macrorregião, score de oportunidade de expansão,
  modo comparativo, tendência de sazonalidade, cruzamentos avançados...) —
  nível painel executivo admin, não cabe numa tela de celular. Esta v1
  traz só: 3 KPIs (postos na rede, municípios únicos, UFs cobertas via
  `postos_gf_municipios_unicos`/`postos_gf_por_uf`, RLS de `postos_gf` já
  escopando por empresa sem precisar de parâmetro), preço médio da rede
  por combustível (`preco_medio_por_combustivel`, sem comparação com ANP —
  a web calcula esse delta com uma resolução de referência client-side
  meio elaborada, fica pra depois) e postos com preço acima da referência
  ANP (`postos_gf_desvio_anp` já traz preço próprio, preço ANP e % de
  desvio calculados no banco — zero lógica extra aqui, só ordenar/mostrar)
  e top municípios da rede (`postos_gf_top_municipios`). Fora do escopo:
  os mapas, cobertura por macrorregião, score de expansão, modo
  comparativo, sazonalidade, cruzamentos avançados, cobertura x demanda.
  Existe também um `lib/features/inteligencia/inteligencia_screen.dart`
  antigo (herdado do backend Python legado, usa `ApiService`) — não tem
  rota nenhuma, ficou morto no código; não usar/reaproveitar.
- **Privacidade (LGPD)** (`/lgpd`) — porta 1:1, sem tela nova: o próprio
  `lgpd_provider.dart` da FLT-2 já documenta que na web é uma ÚNICA rota
  compartilhada por cliente/posto (conteúdo idêntico, só muda onde o link
  aparece no menu — a única bifurcação real é admin x não-admin, e o shell
  Flutter cliente nunca é admin). Bastou trocar a rota `/lgpd` de
  `EmConstrucaoScreen` pra `LgpdScreen` (mesma classe usada em
  `/posto/lgpd`) direto no `app_router.dart`.
- **Chamados** (`lib/features/chamados/`) — diferente de Documentos/LGPD,
  aqui NÃO deu pra reaproveitar as telas em si (`chamados_posto_screen.dart`/
  `chamado_novo_screen.dart` têm rotas `/posto/chamados/...` hardcoded nos
  `context.push`/`pushReplacement`) — só o provider/service
  (`chamadosPostoProvider`/`ChamadosService`/`Ticket`/`statusTicket`/
  `tiposTicket`/`prioridadesTicket`, todos genéricos, filtram só por
  `sessao.empresaId`). Solução: `ChamadosClienteScreen`/
  `ChamadoNovoClienteScreen` novas (cópia adaptada, só trocando as rotas
  pra sem o prefixo `/posto`), importando os providers do Posto direto.
  `ChamadoDetalheScreen` (tela de detalhe + thread de mensagens/anexos) já
  não tinha NENHUMA rota hardcoded — reaproveitada 100% direto, sem cópia,
  em `/chamados/:id`.
- **Clientes** (`lib/features/clientes/`) — achado real: a RLS de
  `empresas` (`empresas_select_membro`) só deixa um usuário ver a(s)
  própria(s) empresa(s); a página `/clientes` da web faz um SELECT sem
  filtro nenhum e depende 100% disso — pra um cliente comum ela NUNCA
  mostra outras empresas, é na prática um "cadastro da minha empresa", não
  uma lista de clientes de verdade (isso só existe pro admin, via seções
  condicionadas a `ehAdmin` que nem chegam a renderizar pro cliente: "+
  Novo Cliente", toggle Ativar/Suspender, "Últimos acessos"). Por isso a
  porta aqui é bem mais simples: mostra o cadastro (nome, CNPJ, status,
  plano, cidade/UF, segmento, porte, limites de veículos/usuários,
  contato) da empresa atual, read-only. Fora do escopo: o formulário de
  edição (`ClienteForm` — poucos campos editáveis pelo próprio cliente,
  vale uma iteração própria) e o widget `CicloAbastecimentoPagamento`
  (resumo cruzando todos os postos negociados) — dado redundante com a
  "Cobrança em Aberto" que o Painel Financeiro já mostra.
- **Grupo Econômico** (`lib/features/grupo_economico/`) — mesma mecânica
  de "Rede de Postos" (FLT-2, lado posto): a tabela `grupos_economicos`/
  `grupos_economicos_empresas` é compartilhada entre as duas, só muda o
  filtro de `segmento` (`Revenda` × `Frota`). Achado real checando a RLS
  direto no banco antes de portar: pra `segmento='Frota'`, tanto
  `grupos_economicos_empresas` (`gee_insere`) quanto `grupos_economicos`
  (`grupos_insert`/`grupos_update`) só permitem escrita self-service
  quando `grupo_economico_e_revenda(...)` é verdadeiro (ou admin) — ou
  seja, diferente do posto (self-service completo desde a Fase 27.139),
  um cliente comum NUNCA consegue criar/editar/vincular grupo, mesmo que a
  web mostre o botão "+ Novo Grupo" (falharia no servidor). Por isso a
  porta aqui é só leitura: nome do grupo, CNPJ matriz, status e lista de
  empresas vinculadas (RLS já escopa pro(s) grupo(s) que a empresa atual
  integra). Sem criação/edição/vínculo.
- **Usuários** (`lib/features/usuarios/`) — mesmo padrão de Chamados:
  telas próprias (`UsuariosClienteScreen`/`UsuarioNovoClienteScreen`, só
  rotas sem prefixo `/posto`), mas provider 100% compartilhado
  (`usuariosPostoProvider`, já genérico). `UsuarioEditarScreen` é
  reaproveitada DIRETO — não tem rota hardcoded. Único ajuste real:
  `UsuariosService.convidarUsuario` ganhou parâmetros opcionais
  `perfil`/`segmento` (default `'posto'`/`'Revenda'`, preservando o
  comportamento do Posto) — o convite do cliente passa
  `'gestor_frota'`/`'Frota'` (perfil padrão pra quem não é admin
  escolhendo outro papel, mesmo default do dropdown da web em
  `UsuarioForm.tsx`). Sem seletor de perfil (Analista/Admin) — mesma
  simplificação "sem dropdown" já usada pro convite do Posto.
- **Motoristas** (`lib/features/motoristas/`) — porta de
  `motoristas/page.tsx` + `[id]/page.tsx` + `actions.ts`. Conceito só
  existe do lado Frota (posto não tem motoristas, tem Usuários) — feature
  nova, sem equivalente FLT-2 pra reaproveitar. CRUD completo: lista com
  indicadores (total/ativos/inativos), cadastro
  (nome/CPF/telefone/e-mail/classificação/CNH+vencimento/centro de custo,
  com checagem de CPF duplicado via RPC `motorista_duplicado`, mesma da
  web) e edição + ativar/inativar. Fora do escopo: paginação (a web pagina
  de 30 em 30; aqui traz até 500 — suficiente pro celular) e importação
  por planilha (`/motoristas/importar`). **Filtros de busca** (pedido do
  Daniel, adicionado depois do v1): campo de busca por nome/CPF (ignora
  pontuação) + chips Todos/Ativos/Inativos, tudo client-side sobre a lista
  já carregada — sem round-trip novo ao banco.
- **Centros de Custo** (`lib/features/centros_custo/`) — porta de
  `centros-custo/page.tsx` + `[id]/page.tsx` + `actions.ts`. Cadastro
  completo (nome*/código/responsável/descrição/ativo) + alocação de
  **motoristas** (um `UPDATE` em lote na coluna `centro_custo_id` de
  `motoristas`, igual à web — sem tabela de histórico). A tela de edição
  mostra os motoristas já alocados (com botão pra desalocar) e uma lista
  de disponíveis com checkbox pra alocar em lote. Fora do escopo: alocação
  de **veículos** em lote nesta tela — a web mantém histórico completo via
  `centros_custo_veiculos` (`AlocarVeiculoForm` separado, aloca vários de
  uma vez). Essa alocação COM histórico acabou portada, sim, mas na tela
  de Veículos (um veículo por vez, ver bullet abaixo) — mesmo espírito da
  web, que também faz a alocação individual em `VeiculoForm`. Também fora:
  importação por planilha (`/centros-custo/importar`).
- **Postos Revendedores** (`lib/features/postos/`) — porta de
  `postos/page.tsx` + `[cnpj]/page.tsx` + `actions.ts`. RLS conferida antes
  de portar: `postos_gf`/`historico_precos` têm CRUD self-service completo
  pra empresa do usuário (igual à web), então o v1 já sai com ações reais,
  não só leitura. 3 telas: lista "Rede do cliente" (busca por
  nome/município/CNPJ, indicadores Na rede/Liberados/Bloqueados), busca no
  universo ANP (`/postos/buscar` — só dispara com 3+ letras digitadas,
  capado em 30 resultados, sem paginação; botão "Ativar" copia os dados
  básicos do posto ANP pra rede do cliente) e detalhe (dados de origem da
  importação/ANP, bloquear/desbloquear pra abastecimento, remover da rede,
  registrar/excluir preço por combustível — lista `PRODUTOS_POSTO`, mesma
  da web). Fora do escopo: aba "Inteligência da Minha Frota" (dado já
  coberto, de forma reduzida, pela tela Inteligência de Rede que existe no
  Flutter desde a Fase FLT-3), edição dos campos operacionais do posto
  (`PostoForm` completo — perfil de venda, horário, ARLA etc.), o
  cascateamento completo de fontes de preço que `resolverPrecosVigentes`
  calcula na web (meios de pagamento → Meus Preços → ANP
  município/estado/Brasil — aqui mostra direto o histórico manual),
  importação por planilha (`/postos/importar`, `/postos/importar-precos`)
  e "Atualizar universo ANP" (admin only).
- **Abastecimentos** (`lib/features/abastecimentos/`) — porta de
  abastecimentos/page.tsx (lado cliente — a web desvia pro
  `AbastecimentosPosto`, já coberto pela Fase FLT-2, quando a empresa é
  segmento "Revenda"). Modelada de perto em `AbastecimentosPostoScreen`
  (mesma view `abastecimentos_unificado`, mesmo layout de indicadores/
  filtros/cards, inclusive reaproveitando a classe
  `RegistroAbastecimentoPosto` direto em vez de duplicar), só que filtra
  por `empresa_id` (consumo desta frota) em vez de `posto_cnpj` (o que um
  posto forneceu). Inclui: lista com indicadores, filtros (combustível,
  meio de pagamento, busca, período, "🔴 Pendente de ajuste"), lançamento
  manual (`/abastecimentos/novo`, pra clientes sem integração automática)
  e o fluxo completo de **Ajuste de registro** bidirecional (solicitar,
  contrapropor, aprovar/recusar, cancelar) — o mesmo do lado posto
  (`AjustesAbastecimentosService`, que ganhou um parâmetro opcional
  `autor` — default `'posto'`, preserva 100% o comportamento original —
  usado aqui com `'cliente'` pra derivar o turno certo). Achado real
  conferido no banco antes de portar: como a view `abastecimentos_unificado`
  só tem `posto_cnpj` (texto solto, não FK), resolver o `empresaPostoId`
  (necessário pra abrir uma solicitação de ajuste) usa a mesma RPC
  SECURITY DEFINER da web, `resolver_empresa_por_cnpj_segmento` — sem ela,
  a RLS de `empresas` bloquearia a consulta (cliente nunca é "membro" do
  posto). Fora do escopo: paginação de verdade (só traz os 50 mais
  recentes), importação por planilha (`/abastecimentos/importar`) e o
  badge "Rejeitada + motivo" de NF-e — `notas_fiscais_pendencias` só tem
  RLS de leitura pra quem é `empresa_posto_id` (conferido direto no banco),
  o cliente nunca teria acesso a essas linhas; só mostra "Emitida" (via
  `notas_fiscais_abastecimento`, que tem `empresa_cliente_id` e portanto É
  legível) ou "Pendente" (sem diferenciar rejeitada).
- **Veículos** (`lib/features/veiculos/`) — porta de `veiculos/page.tsx` +
  `[id]/page.tsx` + `actions.ts` + `src/lib/centroCusto.ts`. RLS conferida
  antes de portar: `cadastro_veiculos`/`centros_custo_veiculos` têm
  self-service completo pra empresa do usuário. Achado real do schema:
  `cadastro_veiculos` não tem `empresa_id` (vínculo só por `cnpj_frota`,
  texto normalizado) — a lista usa a mesma RPC da web,
  `veiculos_da_empresa`, que resolve essa normalização; criar/editar usa
  `veiculo_duplicado` pra impedir placa repetida na frota. CRUD completo
  (identificação, especificações técnicas, localização) + alocação de
  **centro de custo com histórico** — porta fiel de
  `alocarVeiculoCentroCusto`: fecha a alocação ativa atual em
  `centros_custo_veiculos` (`data_fim`/`ativo: false`) e abre uma nova em
  vez de sobrescrever, sincronizando `cadastro_veiculos.centro_custo_id/
  nome` como cache — exatamente como a web, sem RPC (é escrita direta em
  2-3 tabelas). Fora do escopo: paginação de verdade (a web pagina em
  memória depois de trazer a frota inteira; aqui traz até 1000, suficiente
  pro celular) e importação por planilha (`/veiculos/importar`).
- **Notas Fiscais** (`lib/features/notas_fiscais/`) — porta de
  `notas-fiscais/page.tsx` + `[notaId]/page.tsx` (lado cliente — `ehPosto`
  sempre falso aqui). RPCs conferidas antes de portar:
  `indicador_notas_fiscais`/`abastecimentos_com_status_nota_fiscal` são
  SECURITY DEFINER mas conferem `p_empresa_id` contra
  `empresas_do_usuario(email)` internamente — chamar com
  `sessao.empresaId` é seguro; `notas_fiscais_abastecimento` tem RLS de
  leitura direta (`empresa_posto_id` OU `empresa_cliente_id`), então o
  detalhe usa `.from()` direto, sem RPC, igual à web. Lista com painel de
  indicador (barra de progresso vermelho→âmbar→verde conforme o % de
  recolha), filtros por status (Todos/Emitida/Rejeitada/Pendente, com
  contagem) e busca (ID de 10 dígitos, placa, posto ou cliente) sobre os
  abastecimentos dos últimos 90 dias; cada linha mostra o badge de status,
  com o motivo detalhado nas rejeitadas (`mensagemMotivoPendencia`,
  portada 1:1). Detalhe da NF-e mostra emitente/destinatário, item de
  combustível e o abastecimento vinculado. Fora do escopo: seção "Uploads
  sem abastecimento correspondente" (só aparece pro posto, que é quem sobe
  o XML), botão "Baixar PDF" da NF-e (a web monta o PDF inteiro em memória
  via jsPDF) e paginação de verdade (web pagina 20 em 20; aqui traz até
  100 linhas).
- **Anomalias** (`lib/features/anomalias/`) — porta de `anomalias/page.tsx`
  + `actions.ts`. RLS conferida antes de portar: `anomalias_abastecimento`
  tem self-service COMPLETO (select/update) via `empresas_do_usuario` —
  ler e revisar é direto, sem RPC, igual à web. Só a detecção
  (`detectar_anomalias_abastecimento`, as 4 regras: volume x tanque,
  postos distantes no mesmo dia, hodômetro retrocedendo, preço fora da
  média regional) é RPC (SECURITY DEFINER), sempre chamada com
  `p_empresa_id` da sessão — o "rodar pra todos os clientes" é só do
  admin, fora de escopo aqui. Tela com KPIs (não revisadas / críticas não
  revisadas), filtros (tipo + status pendentes/revisadas/todas), botão
  "Detectar agora" e cada card com badge de severidade/tipo, descrição e
  ação marcar/desfazer revisão. Fora do escopo: seletor de cliente (só
  existe pro admin na web) e paginação de verdade (web pagina 30 em 30;
  aqui traz até 100).
- **Roteirização** (`lib/features/roteirizacao/`) — porta de
  `roteirizacao/page.tsx` + `posto/page.tsx` + `planejar/page.tsx` +
  `actions.ts` + `geo.ts` + `roteirizacaoAlgoritmo.ts`. RLS/tabelas
  conferidas antes de portar: `postos_gf`/`historico_precos` têm
  self-service completo (já usado em Postos Revendedores);
  `anp_postos`/`anp_precos_referencia` têm leitura PÚBLICA (`qual: true`,
  sem tenant-scoping) — dá pra consultar direto, sem RPC, igual à web. A
  web tem 4 abas; 3 entraram no v1, num único toggle em vez de abas
  separadas: "Por UF/Município" (lista postos da UF/município, mesclando
  rede própria + base pública ANP), "Consulta por Posto" (busca livre por
  CNPJ ou nome) e "Roteirizador Inteligente" (pedido do Daniel — calcula a
  rota real origem→destino via OSRM público, busca postos candidatos num
  corredor de 5km ao longo da rota via bounding boxes segmentadas a cada
  150km — porta fiel da Fase 27.21 da web, evita estourar `.limit()` em
  rotas longas —, e roda o algoritmo guloso "olhar à frente"
  (`otimizarAbastecimento`, porta fiel de `roteirizacaoAlgoritmo.ts`) pra
  decidir onde parar e quantos litros abastecer, dado tanque/autonomia do
  veículo escolhido e um dos 4 perfis de peso (Economia/Equilíbrio/
  Qualidade/Mínimas Paradas)). Cada resultado mostra o score A-D (porta
  fiel de `calcularScorePosto` — preço 50%/serviços 30%/distância 20%,
  sem ponto de referência único nos modos UF/posto, então o score fica
  dominado pela % de serviços do posto) e os preços por combustível. Mapa
  interativo (`flutter_map` + tiles OpenStreetMap,
  `lib/features/roteirizacao/screens/mapa_postos.dart`, mesma fonte
  gratuita usada no Leaflet da web) plotado nos 3 modos, com a rota
  desenhada e as paradas sugeridas destacadas no Roteirizador Inteligente.
  Geocodificação de endereço livre via Nominatim (mesmo serviço público da
  web). Bug corrigido: o campo `veiculo.combustivel` guarda o tipo de
  motor ("Diesel S10", "Flex" etc. — rótulos de `CICLOS_COMBUSTIVEL`), não
  o produto vendido no posto ("Diesel S-10 Comum" etc. — rótulos de
  `PRODUTOS_POSTO`); usar o valor bruto direto como filtro de preço nunca
  batia com `historico_precos`/ANP, zerando os candidatos e escondendo os
  pinos do mapa. Corrigido com o de-para `produtosPorTipoVeiculo` (porta
  de `PRODUTOS_POR_TIPO_VEICULO`) — pra veículos Flex (gasolina OU
  etanol), a tela pede pro usuário escolher o combustível da viagem, igual
  à web. Fora do escopo: comparativo lado a lado das 4 estratégias de peso
  de uma vez (a web recalcula as 4 pra montar uma tabela comparativa; aqui
  só calcula a estratégia escolhida — dá pra trocar o perfil e recalcular
  manualmente), export de GPX/PDF/PNG e "Rotas Salvas" (persistência de
  consultas).
- **Parâmetros de Uso** (`lib/features/parametros_uso/`) — porta de
  `parametros-uso/page.tsx` + `novo`/`[id]/editar` (Vínculo) + `actions.ts`.
  RLS conferida antes de portar: as 9 tabelas (Vínculo + 8 tipos de regra)
  têm self-service COMPLETO (ALL) via `empresas_do_usuario` — CRUD direto,
  sem RPC, igual à web. A web tem 11 abas; 9 entraram no v1 (Vínculo,
  Intervalo, Valor Diário, Volume Diário, Produto, Hodômetro Leve/Pesado,
  Dias/Horários, Postos, Cotas), cada uma com lista + criar (formulário em
  bottom sheet, exceto Vínculo que tem tela própria de criar/editar,
  espelhando a página dedicada da web) + ativar/desativar + excluir. Cotas
  mostra o consumo do período atual (mesma agregação sobre
  `abastecimentos_unificado` que a web faz, com o mesmo cálculo de início
  de período por semana/quinzena/mês). Fora do escopo: aba "Serviços"
  (`parametros_limite_servicos`) — o campo `limites` é um array JSONB de
  objetos (serviço/quantidade/valor) montado por um formulário repetível
  na web, trabalho bem maior que os outros 9 tipos (todos têm campos
  fixos) e o tipo de regra menos comum no dia a dia — fica pra uma
  próxima fase.
- **Negociações com Postos** (`lib/features/negociacoes/`) — porta de
  `negociacoes/page.tsx` + `novo/page.tsx` + `[id]/page.tsx` (lado
  cliente — a web serve os 2 lados na mesma tela; o lado posto já existe
  desde a FLT-2 em `lib/features/posto/`). RLS conferida antes de portar:
  `negociacoes_postos`/`negociacoes_postos_rodadas` têm self-service
  COMPLETO via `empresa_cliente_id` — CRUD direto, sem RPC, igual à web.
  Modelada de perto no par de telas do posto (mesmos providers de
  rodada/histórico reaproveitados via `show`, só a classe de detalhe e o
  service são novos, com "autor" fixo em `'cliente'`) — porta fiel de
  `src/lib/negociacoesPostos.ts`: lista com indicadores (Negociações/
  Aguardando sua resposta/Aceitas/Vigentes agora) e filtro por status;
  criar negociação nova (informando CNPJ do posto); detalhe com histórico
  de rodadas e o fluxo completo aceitar/recusar/contrapropor/cancelar,
  incluindo os mesmos achados reais já resolvidos do lado posto (fotografa
  os termos da rodada aceita no cabeçalho, encerra automaticamente outra
  negociação já aceita do mesmo par posto+cliente). Achado real conferido
  na web antes de portar: os gates de assinatura em trial e documentação
  aprovada em `decidirNegociacao` (Fases 27.125/27.149) só valem pra
  `autor === "posto"` aceitando — do lado cliente aceitar não passa por
  eles; já `criarNegociacao` sempre exige documentação aprovada da
  empresa CLIENTE, dos dois lados. Fora do escopo: provisionamento
  automático do posto (Fase 27.125) — quando o CNPJ do posto não existe
  na FNI e o cliente informa e-mail de contato, a web cria a conta do
  posto em trial e convida via Supabase Auth Admin API
  (`inviteUserByEmail`), que exige Service Role Key (o app só tem a
  publishable key); aqui, sem CNPJ encontrado, a negociação é criada do
  mesmo jeito com `empresa_posto_id` nulo — mesmo fallback que a web já
  tem quando não informa e-mail.

Demais itens do menu (Rotograma, Planos de Viagem, Preços dos Postos
Parceiros, Manutenção Preditiva, Relatórios,
Integrações, Permissões) seguem como `EmConstrucaoScreen`, uma de cada vez
nas próximas fases — várias devem reaproveitar bastante lógica já pronta
do lado Posto (LGPD, Usuários, Chamados especialmente).

## Hotfix: login com Google (fora da sequência FLT-3)

Achado real testando com o Daniel: o botão "Continuar com Google" sempre
falhava com "Não foi possível obter o idToken do Google.", mesmo com
Client ID certo e Authorized Origins cadastrados no Google Cloud Console
(hipótese inicial, descartada). Causa raiz encontrada no Console do
navegador: `[GSI_LOGGER-TOKEN_CLIENT] Starting popup flow` seguido de uma
chamada a `people.googleapis.com` pra buscar nome/e-mail/foto — ou seja, o
pacote `google_sign_in`, no Flutter Web, só obtém um `access_token` via
Google Identity Services (fluxo de popup), nunca um `id_token`. É uma
mudança do próprio Google (o método `signIn()` imperativo foi
descontinuado pra esse fim); a web contorna isso renderizando o botão
oficial do GIS, que dá bem mais trabalho de replicar no Flutter.

Trocado `auth_service.dart`/`login_screen.dart` pra usar
`supabase.auth.signInWithOAuth(OAuthProvider.google)` — fluxo de redirect
PKCE em que o Supabase troca o código de autorização pelo token
diretamente com o Google no backend dele, sem depender de idToken no
navegador. Pré-requisito de configuração (não é código, ver seção
"Pendência de configuração" acima): a URL do app precisa estar cadastrada
em Supabase Dashboard → Authentication → URL Configuration → Redirect
URLs. Pacote `google_sign_in` ficou sem uso no código (removido do
`auth_service.dart`); mantido em `pubspec.yaml` por ora pra não mexer no
lockfile sem rodar `flutter pub get` localmente.

**Correção (2ª rodada de teste):** sem `redirectTo`, o Supabase mandava de
volta pra "Site URL" do projeto (landing page da web), não pro PWA.
Corrigido passando `redirectTo: Uri.base.origin` — usa a origem de onde o
app está rodando na hora, sem hardcode.
