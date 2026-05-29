-- ══════════════════════════════════════════════════════════════════
--  GestaoFrotas API — Tabelas de integração
--  Execute no SQL Editor do Supabase
-- ══════════════════════════════════════════════════════════════════

-- 1. Chaves de acesso dos clientes
CREATE TABLE IF NOT EXISTS profrotas_api_keys (
    id               BIGSERIAL    PRIMARY KEY,
    cnpj_frota       TEXT         NOT NULL,
    nome_empresa     TEXT         NOT NULL,
    token            TEXT         NOT NULL,
    ativo            BOOLEAN      NOT NULL DEFAULT TRUE,
    data_cadastro    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    data_inicio_sync TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    ultimo_sync      TIMESTAMPTZ,
    registros_sync   INTEGER      DEFAULT 0,
    criado_por       TEXT,
    CONSTRAINT profrotas_api_keys_cnpj_uq UNIQUE (cnpj_frota)
);

-- 2. Abastecimentos importados (1 linha por item de combustível)
CREATE TABLE IF NOT EXISTS profrotas_abastecimentos (
    id                      BIGSERIAL    PRIMARY KEY,
    cnpj_frota              TEXT         NOT NULL,
    -- Campos do registro pai
    identificador           BIGINT       NOT NULL,
    abastecimento_estornado INTEGER,
    data_abastecimento      TIMESTAMPTZ,
    data_atualizacao        TIMESTAMPTZ,
    data_transacao          TIMESTAMPTZ,
    status_autorizacao      INTEGER,
    motivo_recusa           TEXT,
    motivo_cancelamento     TEXT,
    hodometro               INTEGER,
    horimetro               INTEGER,
    -- Frota
    frota_cnpj              TEXT,
    frota_razao_social      TEXT,
    -- Motorista
    motorista_id            BIGINT,
    motorista_nome          TEXT,
    -- Veículo
    veiculo_id              BIGINT,
    veiculo_placa           TEXT,
    -- Ponto de venda
    pv_cnpj                 TEXT,
    pv_razao_social         TEXT,
    pv_posto_interno        BOOLEAN,
    pv_municipio            TEXT,
    pv_uf                   TEXT,
    pv_latitude             NUMERIC(10,6),
    pv_longitude            NUMERIC(10,6),
    -- Item de combustível
    item_id                 TEXT,
    item_nome               TEXT,        -- ex: "DIESEL S10", "GASOLINA"
    item_tipo               INTEGER,     -- range[1,14]
    item_quantidade         NUMERIC(12,3),
    item_valor_unitario     NUMERIC(12,4),
    item_valor_total        NUMERIC(12,2),
    -- Controle
    payload_raw             JSONB,
    importado_em            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT profrotas_abast_uq UNIQUE (cnpj_frota, identificador, item_id)
);

CREATE INDEX IF NOT EXISTS idx_pfa_cnpj   ON profrotas_abastecimentos (cnpj_frota);
CREATE INDEX IF NOT EXISTS idx_pfa_data   ON profrotas_abastecimentos (data_abastecimento);
CREATE INDEX IF NOT EXISTS idx_pfa_placa  ON profrotas_abastecimentos (veiculo_placa);
CREATE INDEX IF NOT EXISTS idx_pfa_pvcnpj ON profrotas_abastecimentos (pv_cnpj);

ALTER TABLE profrotas_api_keys       ENABLE ROW LEVEL SECURITY;
ALTER TABLE profrotas_abastecimentos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_all_api_keys" ON profrotas_api_keys;
DROP POLICY IF EXISTS "anon_all_abast"    ON profrotas_abastecimentos;

CREATE POLICY "anon_all_api_keys" ON profrotas_api_keys
    FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "anon_all_abast"    ON profrotas_abastecimentos
    FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
