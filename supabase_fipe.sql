CREATE TABLE IF NOT EXISTS public.frota_veiculos_fipe (
    placa            TEXT PRIMARY KEY,
    marca            TEXT,
    modelo           TEXT,
    ano_modelo       TEXT,
    cor              TEXT,
    tipo_veiculo     TEXT,
    municipio        TEXT,
    uf_veiculo       TEXT,
    codigo_fipe      TEXT,
    valor_fipe       NUMERIC(14,2),
    combustivel_fipe TEXT,
    mes_referencia   TEXT,
    empresa_id       TEXT,
    buscado_em       TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.frota_veiculos_fipe ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "fipe_select_anon" ON public.frota_veiculos_fipe;
CREATE POLICY "fipe_select_anon" ON public.frota_veiculos_fipe FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS "fipe_insert_anon" ON public.frota_veiculos_fipe;
CREATE POLICY "fipe_insert_anon" ON public.frota_veiculos_fipe FOR INSERT TO anon WITH CHECK (true);

DROP POLICY IF EXISTS "fipe_update_anon" ON public.frota_veiculos_fipe;
CREATE POLICY "fipe_update_anon" ON public.frota_veiculos_fipe FOR UPDATE TO anon USING (true);

DROP POLICY IF EXISTS "fipe_delete_anon" ON public.frota_veiculos_fipe;
CREATE POLICY "fipe_delete_anon" ON public.frota_veiculos_fipe FOR DELETE TO anon USING (true);

SELECT 'Tabela frota_veiculos_fipe criada com sucesso!' AS status;
