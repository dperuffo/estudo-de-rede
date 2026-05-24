-- ═══════════════════════════════════════════════════════════════════
--  MULTI-TENANCY — Isolamento de dados por empresa
--  Execute este script no Supabase SQL Editor
--  Cada bloco é seguro para re-executar (idempotente)
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


-- ── 3. Adicionar empresa_id nas tabelas existentes ───────────────────
--   Cada bloco DO verifica se a tabela existe antes de alterar.
--   Nullable → não quebra dados legados.

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'postos_gf') THEN
        ALTER TABLE postos_gf ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES empresas(id);
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'historico_precos') THEN
        ALTER TABLE historico_precos ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES empresas(id);
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'frota_abastecimentos') THEN
        ALTER TABLE frota_abastecimentos ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES empresas(id);
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'acordos_precos') THEN
        ALTER TABLE acordos_precos ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES empresas(id);
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'frota_veiculos') THEN
        ALTER TABLE frota_veiculos ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES empresas(id);
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'favoritos_postos') THEN
        ALTER TABLE favoritos_postos ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES empresas(id);
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'anotacoes_postos') THEN
        ALTER TABLE anotacoes_postos ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES empresas(id);
    END IF;
END $$;


-- ── 4. Índices (só criados se a tabela existir) ──────────────────────

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'postos_gf') THEN
        CREATE INDEX IF NOT EXISTS idx_postos_gf_empresa ON postos_gf(empresa_id);
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'historico_precos') THEN
        CREATE INDEX IF NOT EXISTS idx_historico_precos_empresa ON historico_precos(empresa_id);
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'frota_abastecimentos') THEN
        CREATE INDEX IF NOT EXISTS idx_frota_abastecimentos_empresa ON frota_abastecimentos(empresa_id);
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'acordos_precos') THEN
        CREATE INDEX IF NOT EXISTS idx_acordos_precos_empresa ON acordos_precos(empresa_id);
    END IF;
END $$;


-- ── 5. (Opcional) Row Level Security ────────────────────────────────
--   Segunda camada de proteção no nível do banco.
--   Descomente se quiser ativar após configurar o Supabase Auth corretamente.
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


-- ── 6. Criar primeira empresa (descomente e ajuste) ──────────────────
--
-- INSERT INTO empresas (nome, cnpj)
-- VALUES ('Nome da Empresa', '00.000.000/0001-00')
-- RETURNING id;
--
-- -- Use o ID retornado para associar usuários:
-- INSERT INTO usuarios_empresas (user_email, empresa_id, role)
-- VALUES
--   ('usuario@empresa.com', '<ID_ACIMA>', 'editor');
