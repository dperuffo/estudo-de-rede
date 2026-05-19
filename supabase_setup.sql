-- ══════════════════════════════════════════════════════════════════
--  Estudo de Rede – Pró-Frotas
--  Script de criação das tabelas no Supabase
--
--  Como usar:
--    1. Acesse o painel do Supabase → SQL Editor
--    2. Cole todo este conteúdo e clique em "Run"
-- ══════════════════════════════════════════════════════════════════

-- ── 1. Rotas Salvas ──────────────────────────────────────────────
create table if not exists rotas_salvas (
    id           text primary key,
    usuario_email text not null,
    nome         text not null,
    tipo         text default 'roteirizacao',
    criado_em    text,
    dados        jsonb default '{}'::jsonb
);

create index if not exists idx_rotas_usuario on rotas_salvas(usuario_email);

-- ── 2. Histórico de Preços ────────────────────────────────────────
create table if not exists historico_precos (
    id           bigserial primary key,
    cnpj         text not null,
    razao_social text,
    municipio    text,
    uf           text,
    combustivel  text not null,
    preco        numeric(8,3) not null,
    fonte        text default 'ANP',
    data_ref     date not null default current_date,
    lat          numeric(10,6),
    lon          numeric(10,6),
    criado_em    timestamptz default now()
);

create index if not exists idx_precos_cnpj on historico_precos(cnpj);
create index if not exists idx_precos_data on historico_precos(data_ref);
create unique index if not exists idx_precos_unico
    on historico_precos(cnpj, combustivel, data_ref);

-- ── 3. Preferências do Usuário ────────────────────────────────────
create table if not exists preferencias (
    usuario_email text primary key,
    placa         text,
    combustivel   text,
    autonomia     numeric(8,2),
    capacidade    numeric(8,2),
    extras        jsonb default '{}'::jsonb,
    atualizado_em timestamptz default now()
);

-- ── 4. Postos Favoritos ───────────────────────────────────────────
create table if not exists postos_favoritos (
    id           bigserial primary key,
    usuario_email text not null,
    cnpj         text not null,
    razao_social text,
    municipio    text,
    uf           text,
    lat          numeric(10,6),
    lon          numeric(10,6),
    criado_em    timestamptz default now(),
    unique(usuario_email, cnpj)
);

create index if not exists idx_favoritos_usuario on postos_favoritos(usuario_email);

-- ── 5. Notas por Posto ───────────────────────────────────────────
create table if not exists notas_posto (
    id            bigserial primary key,
    usuario_email text not null,
    cnpj          text not null,
    nota          text default '',
    atualizado_em timestamptz default now(),
    unique(usuario_email, cnpj)
);
create index if not exists idx_notas_usuario on notas_posto(usuario_email);

-- ── 6. Perfis de Veículo ─────────────────────────────────────────
create table if not exists perfis_veiculo (
    id            bigserial primary key,
    usuario_email text not null,
    nome          text not null,
    placa         text,
    combustivel   text,
    tanque        numeric(8,2),
    autonomia     numeric(8,2),
    criado_em     timestamptz default now()
);
create index if not exists idx_perfis_usuario on perfis_veiculo(usuario_email);

-- ── Desabilita Row Level Security (app usa chave publishable) ─────
alter table rotas_salvas      disable row level security;
alter table historico_precos  disable row level security;
alter table preferencias      disable row level security;
alter table postos_favoritos  disable row level security;
alter table notas_posto       disable row level security;
alter table perfis_veiculo    disable row level security;
