import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../router/app_router.dart';
import 'auth_service.dart';

// Fase Timeout-Inatividade (21/08/2026, pedido do Daniel: "forçar logout
// após 30 min" nos PWAs) — desloga sozinho quem deixa o app aberto sem
// interagir por 30 minutos, mesma prática de qualquer painel financeiro.
// Funciona em 2 camadas complementares, pensando que o PWA roda dentro de
// uma aba de navegador (que pode ficar minimizada/em segundo plano, com o
// próprio navegador suspendendo Timers pra economizar bateria):
//   1. `Timer.periodic` de 30s enquanto a aba está em primeiro plano,
//      comparando "agora" com o horário da última interação (toque,
//      clique, scroll — capturados por um `Listener` translúcido
//      envolvendo TODO o app, plugado no `builder` do MaterialApp.router
//      em main.dart, então cobre qualquer tela sem precisar mexer em cada
//      uma).
//   2. `WidgetsBindingObserver` — quando a aba VOLTA a ficar em primeiro
//      plano (`AppLifecycleState.resumed`), refaz a mesma conta. Cobre o
//      caso comum de minimizar/trocar de app por mais de 30 min: o
//      Timer.periodic pode não disparar nesse meio tempo (é comum
//      navegadores suspenderem timers de abas em segundo plano), mas o
//      horário da última interação continua confiável (é só uma leitura
//      de relógio, não depende do Timer ter rodado).
class InactivityGuard extends ConsumerStatefulWidget {
  final Widget child;
  const InactivityGuard({super.key, required this.child});

  @override
  ConsumerState<InactivityGuard> createState() => _InactivityGuardState();
}

class _InactivityGuardState extends ConsumerState<InactivityGuard>
    with WidgetsBindingObserver {
  static const _tempoLimite = Duration(minutes: 30);
  static const _intervaloChecagem = Duration(seconds: 30);

  Timer? _timer;
  DateTime _ultimaInteracao = DateTime.now();
  bool _deslogando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(_intervaloChecagem, (_) => _checarInatividade());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checarInatividade();
    }
  }

  void _registrarInteracao([PointerEvent? _]) {
    _ultimaInteracao = DateTime.now();
  }

  Future<void> _checarInatividade() async {
    if (_deslogando) return;
    if (!AuthService().isLoggedIn) return;
    if (DateTime.now().difference(_ultimaInteracao) < _tempoLimite) return;

    _deslogando = true;
    try {
      await AuthService().signOut();
      // O `redirect` do appRouterProvider não é reavaliado sozinho quando
      // a sessão muda (diferente do app do motorista, que tem
      // refreshListenable ligado ao onAuthStateChange) — por isso o
      // `.go('/login')` explícito abaixo é necessário aqui, não só reforço.
      if (mounted) {
        ref.read(appRouterProvider).go('/login');
      }
    } finally {
      _deslogando = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _registrarInteracao,
      onPointerMove: _registrarInteracao,
      onPointerSignal: _registrarInteracao,
      child: widget.child,
    );
  }
}
