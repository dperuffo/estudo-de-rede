import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "core/router/app_router.dart";
import "core/theme/app_theme.dart";
import "core/services/api_service.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService().init();
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
      darkTheme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
