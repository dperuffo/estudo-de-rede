import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "core/router/app_router.dart";
import "core/theme/app_theme.dart";
import "core/services/supabase_service.dart";
import "core/services/inactivity_guard.dart";

// Fase FLT-1 — troca da inicialização da API Python própria (ApiService, só
// configurava o Dio com o token salvo — nada de rede aqui) pela inicialização
// do Supabase (Auth + client de dados), que agora é a base de tudo.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init();
  runApp(const ProviderScope(child: FniApp()));
}

class FniApp extends ConsumerWidget {
  const FniApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: "FNI Gestao de Frotas",
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      // Fase Timeout-Inatividade (21/08/2026) — envolve TODA a árvore
      // roteada num único Listener global (ver inactivity_guard.dart),
      // sem precisar tocar em nenhuma tela individualmente.
      builder: (context, child) =>
          InactivityGuard(child: child ?? const SizedBox.shrink()),
    );
  }
}
