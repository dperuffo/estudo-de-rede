-- ══════════════════════════════════════════════════════════════════════
--  FNI — Grants completos para chave anon e authenticated
--  Execute no SQL Editor do Supabase
--  Garante INSERT, UPDATE, DELETE em todas as tabelas de carga
-- ══════════════════════════════════════════════════════════════════════

-- ── Tabelas que a aplicação precisa escrever ──────────────────────────
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE postos_gf             TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE postos_gf_versoes      TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE postos_cercados_db     TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE postos_cercados_versoes TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE precos_posto_db        TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE precos_posto_versoes   TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE historico_precos       TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE cargas_precos_pp       TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE variacoes_precos_pp    TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE acordos_precos         TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE acordos_versoes        TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE frota_abastecimentos   TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE frota_veiculos_fipe    TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE preferencias           TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE postos_favoritos       TO anon, authenticated;

-- Sequências (para colunas bigserial)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;

-- Confirma
SELECT 'Grants aplicados com sucesso!' AS status;
