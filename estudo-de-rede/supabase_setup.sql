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
-- IMPORTANTE: deve ser UNIQUE CONSTRAINT (não apenas UNIQUE INDEX) para o
-- PostgREST/Supabase reconhecer o on_conflict no upsert via API REST.
-- Criamos o índice único primeiro e depois o promovemos a constraint:
create unique index if not exists idx_precos_unico
    on historico_precos(cnpj, combustivel, data_ref);
alter table historico_precos
    add constraint historico_precos_unico
    unique using index idx_precos_unico;

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

-- ── 7. Postos Gestão de Frotas ───────────────────────────────────
create table if not exists postos_gf (
    cnpj           text primary key,
    razao_social   text,
    distribuidora  text,
    municipio      text,
    uf             text,
    lat            numeric(10,6),
    lon            numeric(10,6),
    perfil_venda   text,
    horario        text,
    funciona_24h   boolean,
    pista_caminhao boolean,
    arla           boolean,
    conveniencia   boolean,
    extras         jsonb default '{}'::jsonb,
    versao_id      bigint,
    atualizado_em  timestamptz default now()
);

create table if not exists postos_gf_versoes (
    id            bigserial primary key,
    usuario_email text not null,
    nome_arquivo  text,
    n_cnpjs       int,
    n_coords      int,
    carregado_em  timestamptz default now()
);

-- ── 8. Postos Cercados ────────────────────────────────────────────
create table if not exists postos_cercados_db (
    cnpj          text primary key,
    versao_id     bigint,
    adicionado_em timestamptz default now()
);

create table if not exists postos_cercados_versoes (
    id            bigserial primary key,
    usuario_email text not null,
    nome_arquivo  text,
    n_cnpjs       int,
    carregado_em  timestamptz default now()
);

-- ── 9. Preços por Posto ───────────────────────────────────────────
create table if not exists precos_posto_db (
    id               bigserial primary key,
    cnpj_norm        text not null,
    combustivel_pk   text not null,
    combustivel_label text,
    preco            numeric(10,3),
    data_atualizacao text,
    versao_id        bigint,
    atualizado_em    timestamptz default now(),
    unique(cnpj_norm, combustivel_pk)
);

create table if not exists precos_posto_versoes (
    id            bigserial primary key,
    usuario_email text not null,
    nome_arquivo  text,
    n_registros   int,
    n_postos      int,
    carregado_em  timestamptz default now()
);

-- ── 13. Abastecimentos de Frota (Análise de Cliente) ─────────────
create table if not exists frota_abastecimentos (
    id                  bigserial primary key,
    usuario_email       text not null,
    id_transacao        bigint,
    data_abastecimento  date,
    hora_abastecimento  text,
    cnpj_frota          text,
    razao_frota         text,
    centro_custo        text,
    cnpj_posto          text,
    nome_posto          text,
    cidade_posto        text,
    uf_posto            text,
    placa               text,
    tipo_veiculo        text,
    nome_motorista      text,
    hod_atual           numeric,
    hod_anterior        numeric,
    km_percorrido       numeric,
    media_km_l          numeric,
    produto             text,
    litros              numeric,
    preco_litro         numeric,
    valor_combustivel   numeric,
    valor_total         numeric,
    status_transacao    text,
    lat_posto           numeric,
    lon_posto           numeric,
    nome_arquivo        text,
    created_at          timestamptz default now(),
    unique(usuario_email, id_transacao)
);

create table if not exists frota_uploads (
    id            bigserial primary key,
    usuario_email text not null,
    nome_arquivo  text,
    n_registros   int,
    n_veiculos    int,
    periodo_ini   date,
    periodo_fim   date,
    carregado_em  timestamptz default now()
);

-- ── Desabilita Row Level Security (app usa chave publishable) ─────
alter table rotas_salvas           disable row level security;
alter table historico_precos       disable row level security;
alter table preferencias           disable row level security;
alter table postos_favoritos       disable row level security;
alter table notas_posto            disable row level security;
alter table perfis_veiculo         disable row level security;
alter table postos_gf              disable row level security;
alter table postos_gf_versoes      disable row level security;
alter table postos_cercados_db     disable row level security;
alter table postos_cercados_versoes disable row level security;
alter table precos_posto_db        disable row level security;
alter table precos_posto_versoes   disable row level security;
alter table frota_abastecimentos   disable row level security;
alter table frota_uploads          disable row level security;
