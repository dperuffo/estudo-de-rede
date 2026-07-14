import '../../../core/services/supabase_service.dart';

// Fase FLT-4 — porta de atualizarLogoutInatividadeMinutos
// (src/lib/configuracoesSistema.ts). A checagem de perfil fica só na UI
// (mostra "Acesso restrito" pra quem não é admin, ver
// configuracoes_sistema_screen.dart) — a garantia de verdade é a RLS de
// UPDATE (admin/superusuário), que bloqueia a escrita mesmo que alguém
// tente burlar a checagem da tela.
class ConfiguracoesSistemaService {
  final _supabase = SupabaseService.client;

  Future<void> atualizarLogoutInatividade({required int minutos, required String atualizadoPor}) async {
    await _supabase.from('configuracoes_sistema').update({
      'logout_inatividade_minutos': minutos,
      'atualizado_em': DateTime.now().toIso8601String(),
      'atualizado_por': atualizadoPor,
    }).eq('id', true);
  }
}
