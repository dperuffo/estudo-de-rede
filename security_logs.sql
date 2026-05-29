-- ============================================================
--  Tabela: security_logs — Auditoria de Eventos de Segurança
--  Execute no Supabase Dashboard → SQL Editor
--  OWASP A09: Security Logging and Monitoring
-- ============================================================

CREATE TABLE IF NOT EXISTS public.security_logs (
    id          BIGSERIAL    PRIMARY KEY,
    tipo        TEXT         NOT NULL,   -- LOGIN_OK|LOGIN_FAIL|MFA_OK|MFA_FAIL|
                                         -- RATE_LIMIT|PERM_DENIED|SESSION_TIMEOUT|
                                         -- ADMIN_ACTION|DATA_EXPORT
    nivel       TEXT         NOT NULL DEFAULT 'INFO'
                             CHECK (nivel IN ('INFO','WARN','ERROR')),
    email       TEXT,
    descricao   TEXT,
    ip_hint     TEXT,
    ts          TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Índices para consulta
CREATE INDEX IF NOT EXISTS idx_seclogs_ts    ON public.security_logs (ts DESC);
CREATE INDEX IF NOT EXISTS idx_seclogs_tipo  ON public.security_logs (tipo, ts DESC);
CREATE INDEX IF NOT EXISTS idx_seclogs_email ON public.security_logs (email, ts DESC);
CREATE INDEX IF NOT EXISTS idx_seclogs_nivel ON public.security_logs (nivel, ts DESC)
    WHERE nivel IN ('WARN','ERROR');

-- TTL automático: purga logs com mais de 90 dias (cron ou pg_cron)
-- DELETE FROM public.security_logs WHERE ts < now() - interval '90 days';

-- RLS
ALTER TABLE public.security_logs ENABLE ROW LEVEL SECURITY;

-- Apenas service_role/anon (backend) insere
CREATE POLICY "backend_insert_seclogs"
    ON public.security_logs FOR INSERT
    TO anon, authenticated, service_role
    WITH CHECK (true);

-- Apenas admin lê
CREATE POLICY "admin_select_seclogs"
    ON public.security_logs FOR SELECT
    TO anon, authenticated, service_role
    USING (true);

-- ============================================================
--  APÓS EXECUTAR:
--  Os eventos de segurança aparecerão automaticamente em
--  Admin → Logs de Atividade da aplicação.
-- ============================================================
