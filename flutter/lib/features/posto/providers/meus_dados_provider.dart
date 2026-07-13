import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — dados brutos da linha `empresas` do posto logado, pra
// alimentar "Meus Dados / PIX" (espelha src/app/(dashboard)/minha-empresa/
// page.tsx da web). Mesmo padrão de meu_posto_provider.dart (Map cru, só
// pra inicializar os controllers uma vez) — provider próprio (em vez de
// reaproveitar meuPostoProvider) pra manter a invalidação de cada tela
// independente.
final meusDadosProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return null;

  final supabase = SupabaseService.client;
  return supabase.from('empresas').select().eq('id', empresaId).maybeSingle();
});
