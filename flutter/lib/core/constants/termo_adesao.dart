// Espelho fiel de src/lib/termoAdesao.ts (web) — mesmo texto, mesma versão.
// IMPORTANTE: este texto é só EXIBIDO aqui; o hash/versão realmente
// registrados no aceite (tabela termos_aceite) vêm de constantes hardcoded
// dentro da Edge Function `create-checkout-session` (nunca do que o client
// manda) — então não é preciso (nem seria seguro) recalcular hash no
// Flutter. Se o texto do termo mudar na web, copiar de novo pra cá.
const versaoTermoAdesao = '1.0';

const termoAdesaoParagrafos = <String>[
  'TERMO DE ADESÃO E CONTRATO DE PRESTAÇÃO DE SERVIÇOS — Versão 1.0',
  'FLEET NETWORK INTELLIGENCE — FNI Gestão de Frotas (fxgestaodefrotasonline.com)',
  '',
  'PARTE I — DAS PARTES E DO OBJETO',
  'Cláusula 1ª — Das Partes. 1.1. CONTRATADA: FLEET NETWORK INTELLIGENCE LTDA. (FNI), operadora da plataforma SaaS FNI Gestão de Frotas, acessível em fxgestaodefrotasonline.com. 1.2. CONTRATANTE: pessoa física ou jurídica que realiza a adesão eletrônica, doravante denominada CLIENTE.',
  'Cláusula 2ª — Do Objeto. 2.1. Prestação de serviços de Software como Serviço (SaaS) de gestão inteligente de frotas e combustíveis, nos limites do plano contratado. 2.2. Recursos da plataforma: consulta e análise de preços ANP (~38.000 postos); roteirização otimizada para frotas; dashboard analítico e comparativos ANP; relatórios exportáveis em PDF e Excel; Assistente IA (planos Pro e Enterprise); API e integrações com Ticket Log, Rede Frota, Veloe e Pró-Frotas.',
  '',
  'PARTE II — DOS PLANOS E VALORES',
  'Cláusula 3ª — Planos Disponíveis. Básico (até 5 usuários, até 50 veículos, dashboard básico, suporte 48h); Profissional (até 20 usuários, até 200 veículos, dashboard completo, Assistente IA, API e integrações, suporte 24h); Enterprise (usuários e veículos ilimitados, dashboard personalizado, Assistente IA, API e integrações com webhooks, SLA 99,95%/24x7). Trial gratuito de 14 dias nos planos Básico e Profissional.',
  'Cláusula 4ª — Condições de Pagamento. 4.1. Cobrança mensal recorrente via cartão ou boleto processado pela Stripe. 4.2. Renovação automática ao final de cada ciclo, salvo cancelamento com 5 dias de antecedência. 4.3. Reajuste anual com notificação prévia de 30 dias. 4.4. Inadimplência acima de 10 dias: suspensão, multa de 2% e juros de 1% a.m.',
  '',
  'PARTE III — DOS DIREITOS E OBRIGAÇÕES',
  'Cláusula 5ª — Direitos do Cliente: acessar todos os recursos do plano contratado; suporte técnico nos prazos do plano (48h / 24h / 24x7); portabilidade dos dados em até 30 dias por solicitação; exclusão de dados pessoais conforme LGPD; cancelamento sem multa com 5 dias de antecedência; notificação prévia de 30 dias sobre mudanças relevantes.',
  'Cláusula 6ª — Obrigações do Cliente: usar a plataforma exclusivamente para fins lícitos; não compartilhar credenciais com terceiros não autorizados; manter dados cadastrais atualizados; não realizar engenharia reversa ou extração não autorizada; não comprometer a segurança da plataforma; efetuar pagamentos nas datas acordadas.',
  'Cláusula 7ª — Obrigações da FNI: manter plataforma disponível conforme SLAs; proteger dados com TLS 1.3 em trânsito e criptografia em repouso; isolar dados entre tenants com Row Level Security; notificar incidentes de segurança em até 72 horas; manter backups por no mínimo 90 dias.',
  '',
  'PARTE IV — DO USO ADEQUADO',
  'Cláusula 8ª — Uso Aceitável e Restrições. 8.1. É expressamente proibido ao CLIENTE: acessar a plataforma por bots ou scrapers sem autorização; contornar mecanismos de autenticação ou controle de acesso; fazer upload de arquivos maliciosos ou código prejudicial; usar a plataforma em violação à LGPD ou Marco Civil da Internet; sublicenciar ou ceder acesso a terceiros sem consentimento da FNI.',
  '',
  'PARTE V — SEGURANÇA DA INFORMAÇÃO E LGPD',
  'Cláusula 9ª — Medidas de Segurança Adotadas: autenticação OAuth 2.0 via Google e Microsoft; MFA disponível para todos os usuários; TLS 1.3 obrigatório em todas as comunicações; dados em repouso criptografados no Supabase/PostgreSQL; isolamento por tenant com Row Level Security (RLS); WAF com proteção contra SQL Injection e XSS; logs de auditoria de todas as ações administrativas.',
  'Cláusula 10ª — Tratamento de Dados Pessoais (LGPD). 10.1. A FNI é Controladora dos dados pessoais nos termos da Lei nº 13.709/2018 (LGPD). 10.2. Dados tratados: identificação (nome, e-mail, CNPJ/CPF), dados de uso e dados operacionais inseridos pelo CLIENTE. 10.3. Bases legais: execução de contrato (art. 7º, V), legítimo interesse (art. 7º, IX) e consentimento (art. 7º, I). 10.4. Direitos dos Titulares: acesso, correção, eliminação, portabilidade e revogação via privacidade@fxgestaodefrotasonline.com. 10.5. DPO: contato@fxgestaodefrotasonline.com. 10.6. Retenção: 90 dias após cancelamento; logs de auditoria por 12 meses.',
  '',
  'PARTE VI — DA CONFIDENCIALIDADE',
  'Cláusula 11ª — Obrigação de Confidencialidade. 11.1. As Partes mantêm sigilo sobre informações confidenciais: dados operacionais, algoritmos, código-fonte, estratégias comerciais e dados de terceiros. 11.2. Vigência: 5 anos após encerramento deste Termo. 11.3. Exceções: domínio público ou ordem judicial/regulatória.',
  '',
  'PARTE VII — DISPOSIÇÕES GERAIS',
  'Cláusula 12ª — Propriedade Intelectual. 12.1. Todos os direitos sobre a plataforma (código, algoritmos, design) são de titularidade exclusiva da FNI. 12.2. O CLIENTE mantém propriedade sobre todos os dados que inserir na plataforma.',
  'Cláusula 13ª — Limitação de Responsabilidade. 13.1. A FNI não se responsabiliza por: decisões baseadas nas análises; imprecisões nos dados ANP; danos por uso indevido; interrupções por force majeure. 13.2. Responsabilidade total limitada ao valor pago nos últimos 3 meses de assinatura.',
  'Cláusula 14ª — Vigência, Rescisão e Foro. 14.1. Entra em vigor na data de adesão e permanece ativo enquanto a assinatura estiver vigente. 14.2. Rescisão pelo CLIENTE: a qualquer momento com 5 dias de antecedência, sem multa. 14.3. Foro: Comarca de São Paulo/SP.',
  '',
  'ASSINATURA ELETRÔNICA',
  "A adesão eletrônica mediante clique em 'Aceito os Termos de Adesão' tem plena validade jurídica nos termos da MP nº 2.200-2/2001 e da Lei nº 14.063/2020. Ao aceitar este Termo de Adesão, o CLIENTE também declara estar de acordo com os Termos de Uso gerais da plataforma FNI Gestão de Frotas.",
];
