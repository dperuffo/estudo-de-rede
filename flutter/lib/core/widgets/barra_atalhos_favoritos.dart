import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/menu_favoritos_provider.dart';

// Item já resolvido (href -> label/ícone), pronto pra desenhar. Resolução
// fica a cargo de quem monta a barra (HomeScreen/PostoHomeScreen), porque
// só eles sabem o mapa completo de rotas do próprio shell (cliente x posto
// têm rotas diferentes) — mesma divisão de responsabilidade da web
// (layout.tsx resolve via MAPA_ITENS_MENU antes de passar pra
// BarraAtalhosFavoritos.tsx).
class ItemAtalhoMenu {
  final String href;
  final String label;
  final IconData icon;
  const ItemAtalhoMenu(
      {required this.href, required this.label, required this.icon});
}

// Fase Acesso-Rápido-Favoritos (04/08/2026, pedido do Daniel, escolha
// explícita dele: "barra horizontal de atalhos no topo do conteúdo" em vez
// do topo do menu lateral) — chips roláveis horizontalmente com as telas
// mais usadas (frecência) ou fixadas manualmente deste usuário. Some
// sozinha (sem placeholder vazio) pra quem ainda não tem uso registrado.
// Port do BarraAtalhosFavoritos.tsx da web, adaptado ao Drawer+Scaffold do
// Flutter (aqui os itens somem otimisticamente ao remover, via estado local
// da própria barra, igual à web).
class BarraAtalhosFavoritos extends ConsumerStatefulWidget {
  final Map<String, ItemAtalhoMenu> mapaItens;
  const BarraAtalhosFavoritos({super.key, required this.mapaItens});

  @override
  ConsumerState<BarraAtalhosFavoritos> createState() =>
      _BarraAtalhosFavoritosState();
}

class _BarraAtalhosFavoritosState extends ConsumerState<BarraAtalhosFavoritos> {
  // hrefs removidos otimisticamente (somem da barra na hora, sem esperar o
  // round-trip da RPC) — se a chamada falhar, o href volta pra cá é
  // removido do set (reaparece, já que o provider nunca chegou a excluí-lo
  // de verdade).
  final Set<String> _removendo = {};

  Future<void> _remover(String href) async {
    setState(() => _removendo.add(href));
    final ok = await alternarFavoritoMenu(ref, href, false);
    if (!ok && mounted) setState(() => _removendo.remove(href));
  }

  @override
  Widget build(BuildContext context) {
    final favoritos = ref.watch(favoritosMenuProvider).valueOrNull ?? const [];
    final itens = favoritos
        .where((f) => !_removendo.contains(f.href))
        .map((f) => widget.mapaItens[f.href])
        .whereType<ItemAtalhoMenu>()
        .toList();

    if (itens.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: itens.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final item = itens[i];
            return _Chip(item: item, onRemover: () => _remover(item.href));
          },
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final ItemAtalhoMenu item;
  final VoidCallback onRemover;
  const _Chip({required this.item, required this.onRemover});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => context.go(item.href),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 15, color: const Color(0xFF0D2D6B)),
              const SizedBox(width: 6),
              Text(item.label,
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF334155))),
              const SizedBox(width: 2),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onRemover,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 14, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
