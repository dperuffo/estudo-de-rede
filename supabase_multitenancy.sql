-- ═══════════════════════════════════════════════════════════════════
--  MULTI-TENANCY — Isolamento de dados por empresa
--  Execute este script no Supabase SQL Editor
--  Ordem de execução: 1→2→3→4→5
-- ═══════════════════════════════════════════════════════════════════


-- ── 1. Tabela de empresas ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS empresas (
    id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    nome        TEXT NOT NULL,
    cnpj        TEXT,
    ativo       BOOLEAN DEFAULT true,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ── 2. Tabela de associação usuário ↔ empresa (N:N) ─────────────────
--   Um usuário pode pertencer a múltiplas empresas
--   Uma empresa pode ter múltiplos usuários
CREATE TABLE IF NOT EXISTS usuarios_empresas (
    user_email  TEXT    NOT NULL,
    empresa_id  UUID    NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
    role        TEXT    DEFAULT 'viewer',   -- 'viewer' | 'editor'
    ativo       BOOLEAN DEFAULT true,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_email, empresa_id)
);

CREATE INDEX IF NOT EXISTS idx_usuarios_empresas_email
    ON usuarios_empresas(user_email);
CREATE INDEX IF NOT EXISTS idx_usuarios_empresas_empresa
    ON usuarios_empresas(empresa_id);


-- ── 3. Adicionar empresa_id nas tabelas de dados existentes ─────────
--   Nullable para não quebrar dados legados já existentes.
--   O admin vê tudo (NULL inclusive). Usuários comuns veem só a empresa deles.

ALTER TABLE postos_gf
    ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES empresas(id);

ALTER TABLE historico_precos
    ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES empresas(id);

ALTER TABLE frota_abastecimentos
    ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES empresas(id);

ALTER TABLE acordos_precos
    ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES empresas(id);

-- Tabelas auxiliares que também devem ser isoladas
ALTER TABLE frota_veiculos
    ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES empresas(id);

ALTER TABLE favoritos_postos
    ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES empresas(id);

ALTER TABLE anotacoes_postos
    ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES empresas(id);


-- ── 4. Índices para performance nas consultas filtradas ──────────────
CREATE INDEX IF NOT EXISTS idx_postos_gf_empresa
    ON postos_gf(empresa_id);

CREATE INDEX IF NOT EXISTS idx_historico_precos_empresa
    ON historico_precos(empresa_id);

CREATE INDEX IF NOT EXISTS idx_frota_abastecimentos_empresa
    ON frota_abastecimentos(empresa_id);

CREATE INDEX IF NOT EXISTS idx_acordos_precos_empresa
    ON acordos_precos(empresa_id);


-- ── 5. (Opcional) Row Level Security no Supabase ─────────────────────
--   Segunda camada de proteção. Use se quiser bloquear no nível do banco.
--   O app já filtra por software, mas RLS garante segurança extra.
--
-- ALTER TABLE postos_gf ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "usuarios_veem_empresa" ON postos_gf
--   USING (
--     empresa_id IN (
--       SELECT empresa_id FROM usuarios_empresas
--       WHERE user_email = auth.jwt()->>'email' AND ativo = true
--     )
--     OR auth.jwt()->>'email' = 'd.peruffo@gmail.com'
--   );
--
-- (repita para historico_precos, frota_abastecimentos, acordos_precos)


-- ── 6. Exemplo: criar primeira empresa e associar admin ──────────────
--   Descomente e ajuste para criar sua primeira empresa manualmente.
--
-- INSERT INTO empresas (nome, cnpj)
-- VALUES ('Empresa Demo', '00.000.000/0001-00')
-- RETURNING id;
--
-- -- Use o ID retornado acima para associar usuários:
-- INSERT INTO usuarios_empresas (user_email, empresa_id, role)
-- VALUES
--   ('usuario1@empresa.com', '<ID_ACIMA>', 'editor'),
--   ('usuario2@empresa.com', '<ID_ACIMA>', 'viewer');
