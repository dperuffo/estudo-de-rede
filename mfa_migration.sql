-- ============================================================
--  Migração MFA v5.5 — Adiciona colunas de 2FA em usuarios_app
--  Execute no Supabase Dashboard → SQL Editor
-- ============================================================

-- Adiciona coluna mfa_secret (segredo TOTP base32)
ALTER TABLE public.usuarios_app
    ADD COLUMN IF NOT EXISTS mfa_secret     TEXT,
    ADD COLUMN IF NOT EXISTS mfa_habilitado BOOLEAN NOT NULL DEFAULT false;

-- Index para queries de verificação (opcional, tabela pequena)
CREATE INDEX IF NOT EXISTS idx_usuarios_mfa
    ON public.usuarios_app (email)
    WHERE mfa_habilitado = true;

-- Comentários descritivos
COMMENT ON COLUMN public.usuarios_app.mfa_secret     IS 'Segredo TOTP base32 (pyotp). Nulo = 2FA não configurado.';
COMMENT ON COLUMN public.usuarios_app.mfa_habilitado IS 'True = usuário deve passar pelo 2FA em todo login.';

-- ============================================================
--  APÓS EXECUTAR:
--  1. Vá em Admin → Perfis & Permissões → seção "Gerenciar 2FA"
--  2. Selecione cada usuário e clique em "Gerar novo QR code"
--  3. Envie o QR para o usuário escanear no Google Authenticator
-- ============================================================
