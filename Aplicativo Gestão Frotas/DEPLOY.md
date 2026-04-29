# Deploy — FX Gestão de Frotas no Railway

## Por que Railway?

O Railway suporta Python + PostgreSQL nativamente, sem configuração complexa.
O `server.py` serve tanto o frontend (HTML) quanto os endpoints `/api/...` — tudo em um único deploy.

---

## Passo a passo (primeira vez)

### 1. Criar conta no Railway

Acesse [https://railway.app](https://railway.app) e crie uma conta gratuita com GitHub ou e-mail.

---

### 2. Criar projeto e conectar o repositório

1. No painel do Railway, clique em **New Project**
2. Escolha **Deploy from GitHub repo**
3. Selecione o repositório `gestao-abastecimentos` (ou o nome que você usa)
4. O Railway detecta o `Procfile` e `requirements.txt` automaticamente

---

### 3. Adicionar PostgreSQL

1. Dentro do projeto, clique em **New** → **Database** → **Add PostgreSQL**
2. O Railway cria o banco e define automaticamente a variável `DATABASE_URL` no serviço

---

### 4. Definir variáveis de ambiente

No painel do serviço, vá em **Variables** e adicione:

| Variável       | Valor                          | Descrição                          |
|----------------|--------------------------------|------------------------------------|
| `AUTH_SALT`    | (string aleatória, mín. 32 chars) | Sal para hash de senhas          |
| `APP_URL`      | `https://SEU-APP.railway.app`  | URL pública do app (para e-mails)  |
| `SMTP_HOST`    | ex: `smtp.gmail.com`           | Servidor SMTP (opcional)           |
| `SMTP_PORT`    | `587`                          | Porta SMTP (opcional)              |
| `SMTP_USER`    | seu@email.com                  | Usuário SMTP (opcional)            |
| `SMTP_PASS`    | senha-de-app                   | Senha SMTP (opcional)              |
| `SMTP_FROM`    | noreply@seudominio.com         | Remetente dos e-mails (opcional)   |

> **Atenção**: `DATABASE_URL` e `PORT` são definidos automaticamente pelo Railway. Não adicione manualmente.

---

### 5. Fazer deploy

O Railway faz deploy automaticamente ao fazer push no repositório. Para forçar:

```bash
# No terminal, na pasta do projeto:
git add .
git commit -m "deploy: adiciona configuração Railway"
git push origin master   # ou main
```

Aguarde ~2 minutos. O Railway vai:
1. Instalar dependências (`pip install -r requirements.txt`)
2. Iniciar o servidor (`python server.py`)
3. Criar um domínio público tipo `https://gestao-frota-production.up.railway.app`

---

### 6. Criar usuário admin

Após o primeiro deploy, o banco estará vazio. Acesse o terminal do Railway:

1. No painel do projeto, clique no serviço → **Shell**
2. Execute:

```bash
python create_admin.py
```

Isso cria o primeiro usuário administrador para login.

---

## Atualizar o app após mudanças

```bash
git add .
git commit -m "update: descrição da mudança"
git push origin master
```

O Railway faz o redeploy automaticamente.

---

## Domínio personalizado (opcional)

1. No painel do Railway → **Settings** → **Domains**
2. Clique em **Add Custom Domain**
3. Aponte seu DNS (CNAME) para o domínio gerado pelo Railway

---

## Custos

O Railway oferece **$5/mês de crédito gratuito** no plano Hobby.
Para uso leve (até ~500 req/dia), o app roda sem custo adicional.

Plano estimado: **~$0–5/mês** dependendo do uso.

---

## Variáveis geradas automaticamente pelo Railway

| Variável        | Descrição                                  |
|-----------------|--------------------------------------------|
| `DATABASE_URL`  | String de conexão PostgreSQL completa      |
| `PORT`          | Porta dinâmica para o servidor HTTP        |

---

## Suporte

Documentação Railway: [https://docs.railway.app](https://docs.railway.app)
