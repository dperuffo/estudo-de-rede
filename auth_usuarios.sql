-- ============================================================
--  Sistema de Autenticação e Permissionamento — v5.5
--  Execute no Supabase Dashboard → SQL Editor
-- ============================================================

-- ── 1. Tabela de usuários da aplicação ────────────────────────
CREATE TABLE IF NOT EXISTS public.usuarios_app (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    email           TEXT         NOT NULL UNIQUE,
    nome            TEXT,
    perfil          TEXT         NOT NULL DEFAULT 'posto'
                                 CHECK (perfil IN ('admin','analista','gestor_frota','posto')),
    -- Vínculo do usuário com uma entidade de dados
    cnpj_vinculado  TEXT,        -- CNPJ do posto OU CNPJ da empresa de frota
    empresa_nome    TEXT,        -- Nome da empresa/posto para exibição
    ativo           BOOLEAN      NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ  DEFAULT now(),
    updated_at      TIMESTAMPTZ  DEFAULT now()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_usuarios_email  ON public.usuarios_app (email);
CREATE INDEX IF NOT EXISTS idx_usuarios_perfil ON public.usuarios_app (perfil);
CREATE INDEX IF NOT EXISTS idx_usuarios_cnpj   ON public.usuarios_app (cnpj_vinculado);

-- RLS
ALTER TABLE public.usuarios_app ENABLE ROW LEVEL SECURITY;

-- Qualquer autenticado pode LER SEU PRÓPRIO perfil
CREATE POLICY "usuario_le_proprio"
    ON public.usuarios_app FOR SELECT
    TO authenticated
    USING (email = auth.jwt() ->> 'email');

-- Admin pode ler todos
CREATE POLICY "admin_le_todos"
    ON public.usuarios_app FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.usuarios_app u
            WHERE u.email = auth.jwt() ->> 'email'
              AND u.perfil IN ('admin','analista')
              AND u.ativo = true
        )
    );

-- Admin pode inserir/atualizar/deletar
CREATE POLICY "admin_gerencia_usuarios"
    ON public.usuarios_app FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.usuarios_app u
            WHERE u.email = auth.jwt() ->> 'email'
              AND u.perfil = 'admin'
              AND u.ativo = true
        )
    );

-- service_role tem acesso total (para o backend Python)
CREATE POLICY "service_acesso_total"
    ON public.usuarios_app FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- ── 2. Trigger para updated_at automático ─────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_usuarios_updated_at
    BEFORE UPDATE ON public.usuarios_app
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── 3. Atualizar RLS das outras tabelas para segregar dados ───

-- frota_veiculos_fipe: gestor_frota só vê seus próprios veículos
-- (a aplicação filtra pelo cnpj_empresa em Python — RLS adicional opcional)

-- historico_precos_anp: leitura pública para autenticados
ALTER TABLE IF EXISTS public.historico_precos_anp ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon_select_historico_anp" ON public.historico_precos_anp;
CREATE POLICY "auth_select_historico_anp"
    ON public.historico_precos_anp FOR SELECT
    TO authenticated, anon
    USING (true);

-- ── 4. Usuário admin inicial ───────────────────────────────────
-- Substitua o e-mail abaixo pelo seu e-mail Google antes de executar
INSERT INTO public.usuarios_app (email, nome, perfil, ativo)
VALUES ('d.peruffo@gmail.com', 'Daniel (Admin)', 'admin', true)
ON CONFLICT (email) DO UPDATE SET perfil = 'admin', ativo = true;

-- ============================================================
--  CONFIGURAÇÃO GOOGLE OAUTH NO SUPABASE
--  1. Supabase Dashboard → Authentication → Providers → Google
--  2. Ative o Google provider
--  3. Crie credenciais OAuth no Google Cloud Console:
--     - https://console.cloud.google.com/apis/credentials
--     - Tipo: "OAuth 2.0 Client ID" → Web Application
--     - Authorized redirect URIs: https://<seu-projeto>.supabase.co/auth/v1/callback
--  4. Cole Client ID e Client Secret no Supabase
--  5. Em Authentication → URL Configuration, adicione:
--     Site URL: https://<seu-app>.streamlit.app
--     Redirect URLs: https://<seu-app>.streamlit.app
-- ============================================================
