import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import 'app_theme.dart';
import 'theme_controller.dart';

// Envolve o MaterialApp: decide se o tema EFETIVO é escuro (modo escolhido +
// brilho do sistema quando "automático"), atualiza `AppTheme.dark` — de onde
// os tokens de cor adaptativos leem — e força um rebuild da árvore inteira
// quando muda, já que muitas telas usam `AppTheme.*` diretamente (não só
// `Theme.of(context)`). Também sincroniza o tema salvo na conta após o login.
class TemaHost extends ConsumerStatefulWidget {
  final Widget Function(BuildContext context, ThemeMode modo) builder;
  const TemaHost({super.key, required this.builder});

  @override
  ConsumerState<TemaHost> createState() => _TemaHostState();
}

class _TemaHostState extends ConsumerState<TemaHost>
    with WidgetsBindingObserver {
  StreamSubscription? _auth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _auth = SupabaseService.client.auth.onAuthStateChange.listen((e) {
      if (e.session != null) {
        ref.read(themeControllerProvider.notifier).sincronizarConta();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth?.cancel();
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => setState(() {});

  void _rebuildAll() {
    void visitar(Element e) {
      e.markNeedsBuild();
      e.visitChildren(visitar);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visitar);
  }

  @override
  Widget build(BuildContext context) {
    final modo = ref.watch(themeControllerProvider);
    final sistemaEscuro =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
    final escuro =
        modo == ThemeMode.dark || (modo == ThemeMode.system && sistemaEscuro);
    if (AppTheme.dark != escuro) {
      AppTheme.dark = escuro;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _rebuildAll();
      });
    }
    return widget.builder(context, modo);
  }
}
