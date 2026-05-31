-- ══════════════════════════════════════════════════════════════════
--  Manutenção Preditiva — Tabela de Registros
--  Execute no SQL Editor do Supabase
-- ══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS manutencoes_realizadas (
    id              BIGSERIAL    PRIMARY KEY,
    cnpj_frota      TEXT         NOT NULL,          -- CNPJ da empresa/frota
    placa           TEXT         NOT NULL,          -- placa do veículo
    data_manutencao DATE         NOT NULL,
    hodometro       INTEGER,                        -- km no momento da manutenção
    tecnico         TEXT,                           -- nome do técnico/mecânico
    oficina         TEXT,                           -- nome da oficina
    custo_total     NUMERIC(12,2),                  -- custo total R$
    -- Itens realizados (array de tipos: oleo, pneus, filtros, etc.)
    itens_realizados TEXT[],                        -- ex: ['oleo','filtros']
    obs_gerais      TEXT,                           -- observações livres
    criado_por      TEXT,                           -- e-mail do usuário que registrou
    criado_em       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    atualizado_em   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_man_placa       ON manutencoes_realizadas (placa);
CREATE INDEX IF NOT EXISTS idx_man_cnpj        ON manutencoes_realizadas (cnpj_frota);
CREATE INDEX IF NOT EXISTS idx_man_data        ON manutencoes_realizadas (data_manutencao DESC);
CREATE INDEX IF NOT EXISTS idx_man_placa_tipo  ON manutencoes_realizadas USING GIN (itens_realizados);

-- RLS
ALTER TABLE manutencoes_realizadas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_all_manutencoes" ON manutencoes_realizadas;
CREATE POLICY "anon_all_manutencoes" ON manutencoes_realizadas
    FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

COMMENT ON TABLE manutencoes_realizadas IS
  'Histórico de manutenções realizadas por veículo — alimenta a análise preditiva.';
