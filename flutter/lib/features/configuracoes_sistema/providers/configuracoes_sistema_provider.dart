import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-4 — Configurações do Sistema (admin), porta de
// configuracoes/page.tsx + _components/FormularioLogoutInatividade.tsx +
// actions.ts + src/lib/configuracoesSistema.ts. RLS conferida antes de
// portar (`configuracoes_sistema`, tabela singleton — 1 linha só, id
// boolean sempre `true`): SELECT liberado pra qualquer autenticado
// (`true`), UPDATE só pra admin/superusuário — dá pra ler/gravar direto
// do app, sem RPC. Único parâmetro hoje: tempo de logout automático por
// inatividade (em minutos), vale pro sistema inteiro (não é por
// cliente/posto).
const logoutInatividadeMinutosPadrao = 30;
const logoutInatividadeMinutosMin = 5;
const logoutInatividadeMinutosMax = 480;

final configuracoesSistemaProvider = FutureProvider.autoDispose<int>((ref) async {
  final row = await SupabaseService.client
      .from('configuracoes_sistema')
      .select('logout_inatividade_minutos')
      .eq('id', true)
      .maybeSingle();
  if (row == null) return logoutInatividadeMinutosPadrao;
  return (row['logout_inatividade_minutos'] as num?)?.toInt() ?? logoutInatividadeMinutosPadrao;
});

// Mesma checagem dupla da web (RLS + validação aqui, mensagem melhor pro
// usuário em vez de só deixar o erro de permissão do banco estourar).
String? validarLogoutInatividadeMinutos(int minutos) {
  if (minutos < logoutInatividadeMinutosMin || minutos > logoutInatividadeMinutosMax) {
    return 'O tempo precisa estar entre $logoutInatividadeMinutosMin e $logoutInatividadeMinutosMax minutos.';
  }
  return null;
}
