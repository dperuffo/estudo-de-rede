ALTER TABLE public.acordos_precos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.frota_abastecimentos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "acordos_select_anon" ON public.acordos_precos;
CREATE POLICY "acordos_select_anon" ON public.acordos_precos FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS "acordos_insert_anon" ON public.acordos_precos;
CREATE POLICY "acordos_insert_anon" ON public.acordos_precos FOR INSERT TO anon WITH CHECK (true);

DROP POLICY IF EXISTS "frota_abast_select_anon" ON public.frota_abastecimentos;
CREATE POLICY "frota_abast_select_anon" ON public.frota_abastecimentos FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS "frota_abast_insert_anon" ON public.frota_abastecimentos;
CREATE POLICY "frota_abast_insert_anon" ON public.frota_abastecimentos FOR INSERT TO anon WITH CHECK (true);

SELECT tablename, policyname, cmd FROM pg_policies
WHERE tablename IN ('acordos_precos','frota_abastecimentos')
ORDER BY tablename, policyname;
