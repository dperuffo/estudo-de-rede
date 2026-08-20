import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sessao_provider.dart';
import '../services/supabase_service.dart';

// Fase Acesso-Rápido-Favoritos (04/08/2026, pedido do Daniel: "mecanismo de
// acesso rápido em funcionalidades mais utilizadas... uma espécie de
// favoritos... usar inteligência artificial pra posicionar as abas mais
// utilizadas") — port 1:1 do mecanismo já implementado na web
// (src/lib/menuFavoritos.ts + RPCs no Supabase: registrar_acesso_menu,
// alternar_favorito_menu, favoritos_menu_do_usuario, tabela menu_favoritos).
// "IA" aqui = frecência (frequência + recência com meia-vida de 14 dias),
// calculada inteiramente no Postgres — não é uma chamada de IA de verdade
// (esclarecido e decidido com o Daniel via pergunta direta antes de
// implementar na web). Modelo híbrido: usuário pode fixar manualmente
// (`fixado_manual`, sempre no topo) ou remover manualmente (nunca mais
// sugerido de volta sozinho); sem nenhum toque, o sistema sugere pelas
// telas mais/mais recentemente usadas.
class ItemFavoritoMenu {
  final String href;
  final bool fixado;
  const ItemFavoritoMenu({required this.href, required this.fixado});
}

// Lista já ordenada (fixados manualmente primeiro, depois por frecência)
// vinda direto da RPC — mesmo contrato usado na web
// (favoritos_menu_do_usuario). autoDispose: refeita sempre que a tela que a
// usa (shell do cliente ou do posto) volta a ficar visível.
final favoritosMenuProvider =
    FutureProvider.autoDispose<List<ItemFavoritoMenu>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  if (sessao.email.isEmpty) return [];
  try {
    final linhas = await SupabaseService.client
        .rpc('favoritos_menu_do_usuario', params: {'p_limite': 8}) as List;
    return linhas.map((l) {
      final m = l as Map<String, dynamic>;
      return ItemFavoritoMenu(
          href: m['href'] as String, fixado: m['fixado'] as bool);
    }).toList();
  } catch (_) {
    // Best-effort — mesmo espírito das demais listas do menu (badges,
    // avisos): uma falha aqui nunca deve travar a navegação nem o menu.
    return [];
  }
});

// Guarda a última rota já registrada nesta sessão do app, pra não regravar
// acesso a cada rebuild do shell sem navegação de verdade — mesmo motivo do
// `useRef` em RastreadorAcessoMenu.tsx na web, adaptado pra cá com um
// StateProvider comum (não-autoDispose: precisa sobreviver a rebuilds dos
// shells, que acontecem a cada troca de rota).
final ultimaRotaRegistradaProvider = StateProvider<String?>((ref) => null);

// Registra 1 acesso (pra frecência) — chamado a partir do build() dos
// shells (HomeScreen/PostoHomeScreen), dentro de um addPostFrameCallback,
// toda vez que a rota atual muda pra uma rota "rastreável" (item de algum
// menu; telas de detalhe tipo /fretes/123 não contam). Best-effort e
// silencioso — nunca deve interferir na navegação em si.
Future<void> registrarAcessoMenu(String href) async {
  try {
    await SupabaseService.client
        .rpc('registrar_acesso_menu', params: {'p_href': href});
  } catch (_) {}
}

// Fixa/desfixa manualmente (estrela no menu, "x" na barra de atalhos).
// Devolve `true` em caso de sucesso — quem chama usa isso pra reverter
// estado otimista em caso de falha, mesmo padrão de
// `alternarFavoritoMenuAcao` na web.
Future<bool> alternarFavoritoMenu(
    WidgetRef ref, String href, bool fixar) async {
  try {
    await SupabaseService.client.rpc('alternar_favorito_menu',
        params: {'p_href': href, 'p_fixar': fixar});
    ref.invalidate(favoritosMenuProvider);
    return true;
  } catch (_) {
    return false;
  }
}
