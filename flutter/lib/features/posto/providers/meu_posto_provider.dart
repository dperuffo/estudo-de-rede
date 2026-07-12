import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — dados brutos da linha `empresas` do posto logado, pra
// alimentar o formulário "Meu Posto" (espelha
// src/app/(dashboard)/meu-posto/page.tsx da web). Mantém o Map cru (em vez
// de um model tipado) de propósito: o formulário só lê os campos uma vez
// pra inicializar os controllers, e a tabela `empresas` tem bem mais
// colunas do que as usadas aqui.
final meuPostoProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return null;

  final supabase = SupabaseService.client;
  return supabase.from('empresas').select().eq('id', empresaId).maybeSingle();
});
