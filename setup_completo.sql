-- ============================================================
--  SETUP COMPLETO v5.5 — Execute tudo de uma vez
--  Supabase Dashboard → SQL Editor → cole e clique em Run
-- ============================================================

-- ── 1. Tabela usuarios_app ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.usuarios_app (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    email           TEXT         NOT NULL UNIQUE,
    nome            TEXT,
    perfil          TEXT         NOT NULL DEFAULT 'posto'
                                 CHECK (perfil IN ('admin','analista','gestor_frota','posto')),
    cnpj_vinculado  TEXT,
    empresa_nome    TEXT,
    ativo           BOOLEAN      NOT NULL DEFAULT true,
    mfa_secret      TEXT,
    mfa_habilitado  BOOLEAN      NOT NULL DEFAULT false,
    created_at      TIMESTAMPTZ  DEFAULT now(),
    updated_at      TIMESTAMPTZ  DEFAULT now()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_usuarios_email  ON public.usuarios_app (email);
CREATE INDEX IF NOT EXISTS idx_usuarios_perfil ON public.usuarios_app (perfil);
CREATE INDEX IF NOT EXISTS idx_usuarios_cnpj   ON public.usuarios_app (cnpj_vinculado);

-- RLS
ALTER TABLE public.usuarios_app ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "usuario_le_proprio"       ON public.usuarios_app;
DROP POLICY IF EXISTS "admin_le_todos"            ON public.usuarios_app;
DROP POLICY IF EXISTS "admin_gerencia_usuarios"   ON public.usuarios_app;
DROP POLICY IF EXISTS "service_acesso_total"      ON public.usuarios_app;

CREATE POLICY "usuario_le_proprio"
    ON public.usuarios_app FOR SELECT TO authenticated
    USING (email = auth.jwt() ->> 'email');

CREATE POLICY "admin_le_todos"
    ON public.usuarios_app FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.usuarios_app u
            WHERE u.email = auth.jwt() ->> 'email'
              AND u.perfil IN ('admin','analista')
              AND u.ativo = true
        )
    );

CREATE POLICY "admin_gerencia_usuarios"
    ON public.usuarios_app FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.usuarios_app u
            WHERE u.email = auth.jwt() ->> 'email'
              AND u.perfil = 'admin'
              AND u.ativo = true
        )
    );

CREATE POLICY "service_acesso_total"
    ON public.usuarios_app FOR ALL TO service_role
    USING (true) WITH CHECK (true);

-- ── 2. Trigger updated_at ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

DROP TRIGGER IF EXISTS trg_usuarios_updated_at ON public.usuarios_app;
CREATE TRIGGER trg_usuarios_updated_at
    BEFORE UPDATE ON public.usuarios_app
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── 3. Admin inicial ──────────────────────────────────────────
INSERT INTO public.usuarios_app (email, nome, perfil, ativo)
VALUES ('d.peruffo@gmail.com', 'Daniel (Admin)', 'admin', true)
ON CONFLICT (email) DO UPDATE SET perfil = 'admin', ativo = true;

-- ── 4. Tabela historico_precos_anp ────────────────────────────
CREATE TABLE IF NOT EXISTS public.historico_precos_anp (
    id               BIGSERIAL PRIMARY KEY,
    data_referencia  DATE         NOT NULL,
    semana_label     TEXT         NOT NULL,
    nivel            TEXT         NOT NULL CHECK (nivel IN ('brasil','estado','regiao','municipio')),
    uf               TEXT,
    regiao           TEXT,
    municipio        TEXT,
    produto_pk       TEXT         NOT NULL,
    produto_nome     TEXT,
    preco_medio      NUMERIC(10,4),
    n_postos         INTEGER,
    unidade          TEXT         DEFAULT 'R$/L',
    fonte            TEXT         DEFAULT 'github_auto',
    created_at       TIMESTAMPTZ  DEFAULT now(),
    UNIQUE (semana_label, nivel, uf, regiao, municipio, produto_pk)
);

CREATE INDEX IF NOT EXISTS idx_anp_hist_data_nivel
    ON public.historico_precos_anp (data_referencia DESC, nivel);
CREATE INDEX IF NOT EXISTS idx_anp_hist_uf_produto
    ON public.historico_precos_anp (uf, produto_pk, data_referencia DESC);
CREATE INDEX IF NOT EXISTS idx_anp_hist_semana
    ON public.historico_precos_anp (semana_label);

ALTER TABLE public.historico_precos_anp ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_select_historico_anp"  ON public.historico_precos_anp;
DROP POLICY IF EXISTS "auth_select_historico_anp"  ON public.historico_precos_anp;
DROP POLICY IF EXISTS "service_insert_historico_anp" ON public.historico_precos_anp;
DROP POLICY IF EXISTS "service_upsert_historico_anp" ON public.historico_precos_anp;

CREATE POLICY "auth_select_historico_anp"
    ON public.historico_precos_anp FOR SELECT TO authenticated, anon
    USING (true);

CREATE POLICY "service_insert_historico_anp"
    ON public.historico_precos_anp FOR INSERT TO service_role
    WITH CHECK (true);

CREATE POLICY "service_upsert_historico_anp"
    ON public.historico_precos_anp FOR UPDATE TO service_role
    USING (true);

-- ============================================================
--  Pronto! Todas as tabelas criadas com RLS configurado.
-- ============================================================
