-- ============================================================
--  Tabela: historico_precos_anp
--  Armazena o histórico semanal de preços ANP por nível geográfico.
--  Criada em: 2026-05-28 | v5.4
-- ============================================================

CREATE TABLE IF NOT EXISTS public.historico_precos_anp (
    id               BIGSERIAL PRIMARY KEY,
    data_referencia  DATE         NOT NULL,          -- data da carga (YYYY-MM-DD)
    semana_label     TEXT         NOT NULL,           -- identificador único da semana/arquivo
    nivel            TEXT         NOT NULL CHECK (nivel IN ('brasil','estado','regiao','municipio')),
    uf               TEXT,                            -- sigla UF (NULL para brasil/regiao)
    regiao           TEXT,                            -- nome da região (NULL para outros níveis)
    municipio        TEXT,                            -- nome do município (NULL para outros níveis)
    produto_pk       TEXT         NOT NULL,           -- chave normalizada (ex: 'gasolina_c')
    produto_nome     TEXT,                            -- nome original na planilha
    preco_medio      NUMERIC(10,4),                   -- preço médio de revenda (R$/L)
    n_postos         INTEGER,                         -- número de postos pesquisados
    unidade          TEXT         DEFAULT 'R$/L',
    fonte            TEXT         DEFAULT 'github_auto',  -- 'github_auto' | 'upload_manual'
    created_at       TIMESTAMPTZ  DEFAULT now(),

    -- Chave única: não duplicar a mesma semana + nível + local + produto
    UNIQUE (semana_label, nivel, uf, regiao, municipio, produto_pk)
);

-- Índices para consultas frequentes
CREATE INDEX IF NOT EXISTS idx_anp_hist_data_nivel
    ON public.historico_precos_anp (data_referencia DESC, nivel);

CREATE INDEX IF NOT EXISTS idx_anp_hist_uf_produto
    ON public.historico_precos_anp (uf, produto_pk, data_referencia DESC);

CREATE INDEX IF NOT EXISTS idx_anp_hist_brasil_produto
    ON public.historico_precos_anp (nivel, produto_pk, data_referencia DESC)
    WHERE nivel = 'brasil';

CREATE INDEX IF NOT EXISTS idx_anp_hist_semana
    ON public.historico_precos_anp (semana_label);

-- RLS (Row Level Security)
ALTER TABLE public.historico_precos_anp ENABLE ROW LEVEL SECURITY;

-- Leitura pública (anon e authenticated)
CREATE POLICY "anon_select_historico_anp"
    ON public.historico_precos_anp
    FOR SELECT
    TO anon, authenticated
    USING (true);

-- Escrita apenas para service_role (backend / Supabase functions)
CREATE POLICY "service_insert_historico_anp"
    ON public.historico_precos_anp
    FOR INSERT
    TO service_role
    WITH CHECK (true);

CREATE POLICY "service_upsert_historico_anp"
    ON public.historico_precos_anp
    FOR UPDATE
    TO service_role
    USING (true);

-- ============================================================
--  NOTAS DE USO
--  Execute este SQL no Supabase Dashboard → SQL Editor.
--  A aplicação popula esta tabela automaticamente a cada
--  novo precos_anp.xlsx detectado no repositório GitHub.
--  Histórico mantido indefinidamente (sem TTL).
-- ============================================================
