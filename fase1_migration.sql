-- ═══════════════════════════════════════════════════════════════════════════
--  FNI PRÓ-FROTAS — FASE 1: FUNDAÇÃO MULTITENANT
--  Migration SQL completa — execute no Supabase SQL Editor
--
--  ORDEM DE EXECUÇÃO:
--    1. Upgrade tabela empresas → estrutura SaaS completa
--    2. Adicionar empresa_id nas tabelas que ainda não têm
--    3. Remover políticas RLS permissivas (ANON = USING true)
--    4. Criar políticas RLS com isolamento real por empresa_id
--    5. Índices compostos para performance
--    6. Função auxiliar de contexto de tenant
--    7. Seed: primeira empresa + vínculo do admin
--
--  Seguro para re-executar (idempotente).
--  Tempo estimado: ~15s em Supabase Pro
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. UPGRADE TABELA EMPRESAS → TENANT TABLE COMPLETA
-- ─────────────────────────────────────────────────────────────────────────────

-- Garante que a tabela empresas existe com a estrutura mínima
CREATE TABLE IF NOT EXISTS public.empresas (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    nome       TEXT        NOT NULL,
    cnpj       TEXT,
    ativo      BOOLEAN     NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Campos de plano e status SaaS
ALTER TABLE public.empresas
    ADD COLUMN IF NOT EXISTS plano        TEXT        NOT NULL DEFAULT 'gratuito'
                                                      CHECK (plano IN ('gratuito','basico','profissional','enterprise')),
    ADD COLUMN IF NOT EXISTS status       TEXT        NOT NULL DEFAULT 'ativo'
                                                      CHECK (status IN ('ativo','trial','suspenso','cancelado')),
    ADD COLUMN IF NOT EXISTS trial_ends_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS cancelado_em  TIMESTAMPTZ,
    -- Campos Stripe (preenchidos na Fase 2)
    ADD COLUMN IF NOT EXISTS stripe_customer_id      TEXT,
    ADD COLUMN IF NOT EXISTS stripe_subscription_id  TEXT,
    -- Limites por plano (cache para evitar join a cada request)
    ADD COLUMN IF NOT EXISTS max_usuarios  INTEGER    DEFAULT 1,
    ADD COLUMN IF NOT EXISTS max_veiculos  INTEGER    DEFAULT 10,
    -- LGPD
    ADD COLUMN IF NOT EXISTS termo_aceito_em  TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS termo_aceito_por TEXT;

-- Índices na tabela empresas
CREATE UNIQUE INDEX IF NOT EXISTS idx_empresas_stripe_customer
    ON public.empresas (stripe_customer_id)
    WHERE stripe_customer_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_empresas_status_plano
    ON public.empresas (status, plano);

-- Trigger updated_at (reutiliza função já existente do setup_completo.sql)
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

DROP TRIGGER IF EXISTS trg_empresas_updated_at ON public.empresas;
CREATE TRIGGER trg_empresas_updated_at
    BEFORE UPDATE ON public.empresas
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ─────────────────────────────────────────────────────────────────────────────
-- 2. ADICIONAR empresa_id NAS TABELAS QUE AINDA NÃO TÊM
--    (tabelas que já têm: postos_gf, historico_precos, frota_abastecimentos,
--     acordos_precos — essas são mantidas como estão)
-- ─────────────────────────────────────────────────────────────────────────────

-- rotas_salvas
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='rotas_salvas') THEN
        ALTER TABLE public.rotas_salvas
            ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_rotas_salvas_empresa
            ON public.rotas_salvas (empresa_id, usuario_email);
    END IF;
END $$;

-- preferencias
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='preferencias') THEN
        ALTER TABLE public.preferencias
            ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_preferencias_empresa
            ON public.preferencias (empresa_id, usuario_email);
    END IF;
END $$;

-- perfis_veiculo
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='perfis_veiculo') THEN
        ALTER TABLE public.perfis_veiculo
            ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_perfis_veiculo_empresa
            ON public.perfis_veiculo (empresa_id, usuario_email);
    END IF;
END $$;

-- frota_veiculos_fipe
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='frota_veiculos_fipe') THEN
        ALTER TABLE public.frota_veiculos_fipe
            ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_frota_veiculos_fipe_empresa
            ON public.frota_veiculos_fipe (empresa_id);
    END IF;
END $$;

-- manutencoes_realizadas
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='manutencoes_realizadas') THEN
        ALTER TABLE public.manutencoes_realizadas
            ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_manutencoes_empresa
            ON public.manutencoes_realizadas (empresa_id);
    END IF;
END $$;

-- security_logs (auditoria por empresa)
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='security_logs') THEN
        ALTER TABLE public.security_logs
            ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id) ON DELETE SET NULL;
        CREATE INDEX IF NOT EXISTS idx_security_logs_empresa
            ON public.security_logs (empresa_id, ts DESC);
    END IF;
END $$;

-- tele_frota
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='tele_frota') THEN
        ALTER TABLE public.tele_frota
            ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_tele_frota_empresa
            ON public.tele_frota (empresa_id);
    END IF;
END $$;

-- tele_abastecimentos
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='tele_abastecimentos') THEN
        ALTER TABLE public.tele_abastecimentos
            ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_tele_abastecimentos_empresa
            ON public.tele_abastecimentos (empresa_id);
    END IF;
END $$;

-- postos_cercados_db
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='postos_cercados_db') THEN
        ALTER TABLE public.postos_cercados_db
            ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_postos_cercados_empresa
            ON public.postos_cercados_db (empresa_id);
    END IF;
END $$;

-- postos_cercados_versoes
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='postos_cercados_versoes') THEN
        ALTER TABLE public.postos_cercados_versoes
            ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_postos_cercados_versoes_empresa
            ON public.postos_cercados_versoes (empresa_id);
    END IF;
END $$;

-- precos_posto_db
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='precos_posto_db') THEN
        ALTER TABLE public.precos_posto_db
            ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_precos_posto_empresa
            ON public.precos_posto_db (empresa_id);
    END IF;
END $$;

-- precos_posto_versoes
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='precos_posto_versoes') THEN
        ALTER TABLE public.precos_posto_versoes
            ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id) ON DELETE CASCADE;
    END IF;
END $$;

-- postos_gf_versoes
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='postos_gf_versoes') THEN
        ALTER TABLE public.postos_gf_versoes
            ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_postos_gf_versoes_empresa
            ON public.postos_gf_versoes (empresa_id);
    END IF;
END $$;

-- frota_uploads
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='frota_uploads') THEN
        ALTER TABLE public.frota_uploads
            ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_frota_uploads_empresa
            ON public.frota_uploads (empresa_id);
    END IF;
END $$;

-- acordos_versoes
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='acordos_versoes') THEN
        ALTER TABLE public.acordos_versoes
            ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_acordos_versoes_empresa
            ON public.acordos_versoes (empresa_id);
    END IF;
END $$;

-- cargas_precos_pp
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='cargas_precos_pp') THEN
        ALTER TABLE public.cargas_precos_pp
            ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_cargas_precos_pp_empresa
            ON public.cargas_precos_pp (empresa_id);
    END IF;
END $$;

-- variacoes_precos_pp
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='variacoes_precos_pp') THEN
        ALTER TABLE public.variacoes_precos_pp
            ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_variacoes_precos_pp_empresa
            ON public.variacoes_precos_pp (empresa_id);
    END IF;
END $$;

-- logs_acesso (auditoria global — empresa_id opcional)
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='logs_acesso') THEN
        ALTER TABLE public.logs_acesso
            ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id) ON DELETE SET NULL;
        CREATE INDEX IF NOT EXISTS idx_logs_acesso_empresa
            ON public.logs_acesso (empresa_id)
            WHERE empresa_id IS NOT NULL;
    END IF;
END $$;

-- configuracoes (por empresa — cada empresa tem suas config)
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='configuracoes') THEN
        ALTER TABLE public.configuracoes
            ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id) ON DELETE CASCADE;
        -- Re-criar índice único para ser por empresa
        DROP INDEX IF EXISTS idx_configuracoes_chave_empresa;
        CREATE UNIQUE INDEX IF NOT EXISTS idx_configuracoes_chave_empresa
            ON public.configuracoes (chave, COALESCE(empresa_id, '00000000-0000-0000-0000-000000000000'::uuid));
    END IF;
END $$;

-- controle_acesso (por empresa)
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='controle_acesso') THEN
        ALTER TABLE public.controle_acesso
            ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_controle_acesso_empresa
            ON public.controle_acesso (empresa_id, email);
    END IF;
END $$;

-- profrotas_api_keys
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='profrotas_api_keys') THEN
        ALTER TABLE public.profrotas_api_keys
            ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_profrotas_api_keys_empresa
            ON public.profrotas_api_keys (empresa_id);
    END IF;
END $$;

-- profrotas_abastecimentos
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='profrotas_abastecimentos') THEN
        ALTER TABLE public.profrotas_abastecimentos
            ADD COLUMN IF NOT EXISTS empresa_id UUID REFERENCES public.empresas(id) ON DELETE CASCADE;
        CREATE INDEX IF NOT EXISTS idx_profrotas_abast_empresa
            ON public.profrotas_abastecimentos (empresa_id, data_abastecimento DESC);
    END IF;
END $$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 3. ÍNDICES COMPOSTOS CRÍTICOS (performance com filtro por empresa_id)
-- ─────────────────────────────────────────────────────────────────────────────

-- frota_abastecimentos
CREATE INDEX IF NOT EXISTS idx_frota_abast_empresa_data
    ON public.frota_abastecimentos (empresa_id, data_abastecimento DESC)
    WHERE empresa_id IS NOT NULL;

-- postos_gf
CREATE INDEX IF NOT EXISTS idx_postos_gf_empresa_cnpj
    ON public.postos_gf (empresa_id, cnpj)
    WHERE empresa_id IS NOT NULL;

-- acordos_precos
CREATE INDEX IF NOT EXISTS idx_acordos_precos_empresa_data
    ON public.acordos_precos (empresa_id, dt_vigencia DESC)
    WHERE empresa_id IS NOT NULL;

-- historico_precos
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='historico_precos') THEN
        CREATE INDEX IF NOT EXISTS idx_historico_precos_empresa_data
            ON public.historico_precos (empresa_id, data_ref DESC)
            WHERE empresa_id IS NOT NULL;
    END IF;
END $$;

-- usuarios_app
CREATE INDEX IF NOT EXISTS idx_usuarios_app_email_ativo
    ON public.usuarios_app (email, ativo)
    WHERE ativo = true;

-- usuarios_empresas
CREATE INDEX IF NOT EXISTS idx_usuarios_empresas_empresa_ativo
    ON public.usuarios_empresas (empresa_id, ativo)
    WHERE ativo = true;


-- ─────────────────────────────────────────────────────────────────────────────
-- 4. FUNÇÃO AUXILIAR — CONTEXTO DE TENANT
--    Uso: SELECT set_tenant_context('<uuid>');
--    RLS avançado pode usar current_setting('app.tenant_id', true)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.set_tenant_context(p_empresa_id UUID)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    PERFORM set_config('app.tenant_id', p_empresa_id::text, true);
END;
$$;

-- Função auxiliar: retorna empresas de um usuário como TEXT[] (compatível com UUID e TEXT)
CREATE OR REPLACE FUNCTION public.empresas_do_usuario(p_email TEXT)
RETURNS TEXT[] LANGUAGE sql STABLE SECURITY DEFINER AS $$
    SELECT ARRAY(
        SELECT ue.empresa_id::text
        FROM public.usuarios_empresas ue
        WHERE ue.user_email = lower(p_email)
          AND ue.ativo = true
    );
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 5. ROW LEVEL SECURITY — ISOLAMENTO REAL POR EMPRESA
--    Remove políticas permissivas ANON, substitui por isolamento empresa_id
-- ─────────────────────────────────────────────────────────────────────────────

-- ── Habilitar RLS nas tabelas que ainda não têm ─────────────────────────────
DO $$ DECLARE t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'rotas_salvas','preferencias','perfis_veiculo','frota_veiculos_fipe',
        'manutencoes_realizadas','security_logs','tele_frota','tele_abastecimentos',
        'postos_cercados_db','postos_cercados_versoes','precos_posto_db',
        'precos_posto_versoes','postos_gf_versoes','frota_uploads','acordos_versoes',
        'cargas_precos_pp','variacoes_precos_pp','logs_acesso','configuracoes',
        'controle_acesso','profrotas_api_keys','profrotas_abastecimentos',
        'empresas','usuarios_empresas'
    ] LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables
                   WHERE table_schema = 'public' AND table_name = t) THEN
            EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
        END IF;
    END LOOP;
END $$;

-- ── REMOVER políticas permissivas antigas ────────────────────────────────────
DO $$ DECLARE r RECORD;
BEGIN
    FOR r IN
        SELECT schemaname, tablename, policyname
        FROM pg_policies
        WHERE schemaname = 'public'
          AND (
              policyname LIKE '%anon%'
              OR policyname IN (
                  'acordos_select_anon','acordos_insert_anon',
                  'frota_abast_select_anon','frota_abast_insert_anon',
                  'anon_all_api_keys','anon_all_abast',
                  'auth_select_historico_anp','anon_select_historico_anp',
                  'service_insert_historico_anp','service_upsert_historico_anp'
              )
          )
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I',
                       r.policyname, r.tablename);
    END LOOP;
END $$;

-- ── EMPRESAS — cada usuário vê apenas suas empresas ──────────────────────────
DROP POLICY IF EXISTS "empresas_service_total"  ON public.empresas;
DROP POLICY IF EXISTS "empresas_select_membro"  ON public.empresas;
DROP POLICY IF EXISTS "empresas_update_admin"   ON public.empresas;

CREATE POLICY "empresas_service_total" ON public.empresas
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "empresas_select_membro" ON public.empresas
    FOR SELECT TO authenticated, anon
    USING (
        id::text = ANY(public.empresas_do_usuario(auth.jwt() ->> 'email'))
        OR (auth.jwt() ->> 'email') = 'd.peruffo@gmail.com'
    );

CREATE POLICY "empresas_update_admin" ON public.empresas
    FOR UPDATE TO authenticated
    USING (
        id::text = ANY(public.empresas_do_usuario(auth.jwt() ->> 'email'))
        OR (auth.jwt() ->> 'email') = 'd.peruffo@gmail.com'
    );

-- ── USUARIOS_EMPRESAS ────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "ue_service_total"  ON public.usuarios_empresas;
DROP POLICY IF EXISTS "ue_select_membro"  ON public.usuarios_empresas;
DROP POLICY IF EXISTS "ue_manage_admin"   ON public.usuarios_empresas;

CREATE POLICY "ue_service_total" ON public.usuarios_empresas
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "ue_select_membro" ON public.usuarios_empresas
    FOR SELECT TO authenticated, anon
    USING (
        empresa_id::text = ANY(public.empresas_do_usuario(auth.jwt() ->> 'email'))
        OR user_email = lower(auth.jwt() ->> 'email')
        OR (auth.jwt() ->> 'email') = 'd.peruffo@gmail.com'
    );

CREATE POLICY "ue_manage_admin" ON public.usuarios_empresas
    FOR ALL TO authenticated
    USING (
        empresa_id::text = ANY(public.empresas_do_usuario(auth.jwt() ->> 'email'))
        OR (auth.jwt() ->> 'email') = 'd.peruffo@gmail.com'
    );

-- ── MACRO para criar política padrão de isolamento em tabelas com empresa_id ─
-- Padrão: service_role vê tudo; autenticado vê apenas sua empresa
CREATE OR REPLACE FUNCTION public._criar_politica_tenant(
    p_table TEXT
) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    -- Remove políticas antigas do padrão
    EXECUTE format('DROP POLICY IF EXISTS "%s_service_total" ON public.%I', p_table, p_table);
    EXECUTE format('DROP POLICY IF EXISTS "%s_tenant_select" ON public.%I', p_table, p_table);
    EXECUTE format('DROP POLICY IF EXISTS "%s_tenant_all"    ON public.%I', p_table, p_table);

    -- service_role: acesso total (backend Python usa service_role)
    EXECUTE format(
        'CREATE POLICY "%s_service_total" ON public.%I
         FOR ALL TO service_role USING (true) WITH CHECK (true)',
        p_table, p_table
    );

    -- authenticated/anon: só vê registros da sua empresa
    -- empresa_id::text garante compatibilidade com colunas UUID e TEXT
    EXECUTE format(
        'CREATE POLICY "%s_tenant_all" ON public.%I
         FOR ALL TO authenticated, anon
         USING (
             empresa_id IS NULL
             OR empresa_id::text = ANY(public.empresas_do_usuario(auth.jwt() ->> ''email''))
             OR (auth.jwt() ->> ''email'') = ''d.peruffo@gmail.com''
         )
         WITH CHECK (
             empresa_id::text = ANY(public.empresas_do_usuario(auth.jwt() ->> ''email''))
             OR (auth.jwt() ->> ''email'') = ''d.peruffo@gmail.com''
         )',
        p_table, p_table
    );
END;
$$;

-- Aplicar política de isolamento em todas as tabelas de dados tenant
DO $$ DECLARE t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'frota_abastecimentos','postos_gf','acordos_precos','historico_precos',
        'frota_veiculos_fipe','manutencoes_realizadas','security_logs',
        'tele_frota','tele_abastecimentos','postos_cercados_db',
        'postos_cercados_versoes','precos_posto_db','precos_posto_versoes',
        'postos_gf_versoes','frota_uploads','acordos_versoes',
        'cargas_precos_pp','variacoes_precos_pp','logs_acesso',
        'configuracoes','controle_acesso','profrotas_api_keys',
        'profrotas_abastecimentos','rotas_salvas','preferencias',
        'perfis_veiculo'
    ] LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables
                   WHERE table_schema = 'public' AND table_name = t) THEN
            PERFORM public._criar_politica_tenant(t);
        END IF;
    END LOOP;
END $$;

-- ── historico_precos_anp — dados públicos ANP, leitura global ────────────────
ALTER TABLE public.historico_precos_anp ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anp_service_total"    ON public.historico_precos_anp;
DROP POLICY IF EXISTS "anp_leitura_publica"  ON public.historico_precos_anp;

CREATE POLICY "anp_service_total" ON public.historico_precos_anp
    FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "anp_leitura_publica" ON public.historico_precos_anp
    FOR SELECT TO authenticated, anon USING (true);

-- ── usuarios_app — política já existente, garante service_role ───────────────
DROP POLICY IF EXISTS "service_acesso_total" ON public.usuarios_app;
CREATE POLICY "service_acesso_total" ON public.usuarios_app
    FOR ALL TO service_role USING (true) WITH CHECK (true);


-- ─────────────────────────────────────────────────────────────────────────────
-- 6. TABELA DE BILLING (preparação para Fase 2 — Stripe)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.invoices (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    empresa_id          UUID        NOT NULL REFERENCES public.empresas(id) ON DELETE CASCADE,
    stripe_invoice_id   TEXT        UNIQUE,
    valor_cents         INTEGER,      -- centavos de BRL
    status              TEXT        NOT NULL DEFAULT 'pending'
                                    CHECK (status IN ('pending','paid','failed','void')),
    periodo_inicio      TIMESTAMPTZ,
    periodo_fim         TIMESTAMPTZ,
    criado_em           TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_invoices_empresa ON public.invoices (empresa_id, criado_em DESC);
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN PERFORM public._criar_politica_tenant('invoices'); END $$;

CREATE TABLE IF NOT EXISTS public.stripe_events (
    id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    stripe_event_id  TEXT        NOT NULL UNIQUE,  -- idempotência
    tipo             TEXT        NOT NULL,
    payload          JSONB,
    processado_em    TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.stripe_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "stripe_events_service" ON public.stripe_events;
CREATE POLICY "stripe_events_service" ON public.stripe_events
    FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Permissões de execução para funções auxiliares
GRANT EXECUTE ON FUNCTION public.set_tenant_context(UUID) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.empresas_do_usuario(TEXT) TO authenticated, anon, service_role;


-- ─────────────────────────────────────────────────────────────────────────────
-- 7. SEED — PRIMEIRA EMPRESA + VÍNCULO DO ADMIN
--    (idempotente — não duplica se já existir)
-- ─────────────────────────────────────────────────────────────────────────────

DO $$
DECLARE
    _admin_email  TEXT    := 'd.peruffo@gmail.com';
    _empresa_id   UUID;
    _empresa_nome TEXT    := 'FNI Tecnologia (Seed)';
BEGIN
    -- Verifica se o admin já tem empresa associada
    SELECT ue.empresa_id INTO _empresa_id
    FROM public.usuarios_empresas ue
    WHERE ue.user_email = lower(_admin_email)
      AND ue.ativo = true
    LIMIT 1;

    IF _empresa_id IS NULL THEN
        -- Cria a empresa seed apenas se não existir nenhuma associação
        IF NOT EXISTS (
            SELECT 1 FROM public.empresas WHERE nome = _empresa_nome
        ) THEN
            INSERT INTO public.empresas (nome, plano, status, max_usuarios, max_veiculos)
            VALUES (_empresa_nome, 'enterprise', 'ativo', 999, 9999)
            RETURNING id INTO _empresa_id;

            INSERT INTO public.usuarios_empresas (user_email, empresa_id, role, ativo)
            VALUES (lower(_admin_email), _empresa_id, 'admin', true)
            ON CONFLICT (user_email, empresa_id) DO UPDATE SET role = 'admin', ativo = true;

            RAISE NOTICE 'Empresa seed criada: % (%)', _empresa_nome, _empresa_id;
        ELSE
            SELECT id INTO _empresa_id FROM public.empresas WHERE nome = _empresa_nome LIMIT 1;
            INSERT INTO public.usuarios_empresas (user_email, empresa_id, role, ativo)
            VALUES (lower(_admin_email), _empresa_id, 'admin', true)
            ON CONFLICT (user_email, empresa_id) DO UPDATE SET role = 'admin', ativo = true;

            RAISE NOTICE 'Vínculo admin criado para empresa existente: %', _empresa_id;
        END IF;
    ELSE
        -- Garante que o plano da empresa do admin é enterprise
        UPDATE public.empresas SET plano = 'enterprise', status = 'ativo'
        WHERE id = _empresa_id AND plano != 'enterprise';
        RAISE NOTICE 'Admin já tem empresa associada: %', _empresa_id;
    END IF;
END $$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 8. VIEW DE DIAGNÓSTICO — verifique o isolamento após rodar a migration
-- ─────────────────────────────────────────────────────────────────────────────

-- Execute após a migration para checar status do RLS:
/*
SELECT
    schemaname,
    tablename,
    rowsecurity AS rls_ativo,
    (SELECT count(*) FROM pg_policies p WHERE p.schemaname = t.schemaname AND p.tablename = t.tablename) AS num_policies
FROM pg_tables t
WHERE schemaname = 'public'
  AND tablename NOT IN ('schema_migrations')
ORDER BY tablename;
*/

-- Execute para verificar que a empresa seed foi criada:
/*
SELECT e.nome, e.plano, e.status, ue.user_email, ue.role
FROM public.empresas e
JOIN public.usuarios_empresas ue ON ue.empresa_id = e.id
ORDER BY e.created_at;
*/

COMMIT;

-- ═══════════════════════════════════════════════════════════════════════════
--  FIM DA MIGRATION FASE 1
--  Próximos passos:
--  1. Execute test_tenant_isolation.py para validar isolamento
--  2. Siga para fase2_billing_stripe.sql
-- ═══════════════════════════════════════════════════════════════════════════
