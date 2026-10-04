import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

// Item de menu que alterna Claro → Escuro → Automático (igual ao ThemeToggle
// do painel web). Mostra o estado ATUAL escolhido.
class TemaToggleTile extends ConsumerWidget {
  const TemaToggleTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modo = ref.watch(themeControllerProvider);
    final (icone, rotulo) = switch (modo) {
      ThemeMode.light => (Icons.light_mode_outlined, 'Tema: Claro'),
      ThemeMode.dark => (Icons.dark_mode_outlined, 'Tema: Escuro'),
      ThemeMode.system => (
        Icons.brightness_auto_outlined,
        'Tema: Sistema (auto)',
      ),
    };
    return ListTile(
      leading: Icon(icone, color: AppTheme.glassIcone),
      title: Text(
        rotulo,
        style: TextStyle(color: AppTheme.glassTexto, fontSize: 14),
      ),
      onTap: () => ref.read(themeControllerProvider.notifier).alternar(),
    );
  }
}
