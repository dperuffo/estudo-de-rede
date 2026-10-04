import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';

// Modo de tema (claro / escuro / automático) — mesmo padrão do painel web
// (ThemeToggle + SincronizadorTema, 11 e 15/09/2026): a escolha vale na hora
// (guardada no aparelho) e também é gravada na CONTA do usuário
// (RPC definir_tema_preferido), pra seguir ele entre dispositivos. Depois do
// login, `sincronizarConta` puxa o valor salvo na conta (obter_tema_preferido).
const _chave = 'tema_preferido';

ThemeMode _parse(String? v) => switch (v) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

String nomeDoModo(ThemeMode m) => switch (m) {
  ThemeMode.light => 'light',
  ThemeMode.dark => 'dark',
  ThemeMode.system => 'system',
};

class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.system) {
    _carregarLocal();
  }

  Future<void> _carregarLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final salvo = prefs.getString(_chave);
      if (salvo != null) state = _parse(salvo);
    } catch (_) {}
  }

  /// Puxa o tema salvo na conta (se houver) — chamado após o login.
  Future<void> sincronizarConta() async {
    try {
      final r = await SupabaseService.client.rpc('obter_tema_preferido');
      if (r is String && r.isNotEmpty) {
        state = _parse(r);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_chave, r);
      }
    } catch (_) {}
  }

  Future<void> definir(ThemeMode modo) async {
    state = modo;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chave, nomeDoModo(modo));
    } catch (_) {}
    try {
      await SupabaseService.client.rpc(
        'definir_tema_preferido',
        params: {'p_tema': nomeDoModo(modo)},
      );
    } catch (_) {
      // Sem rede/sessão: vale só neste aparelho (a troca visual já aconteceu).
    }
  }

  /// Claro → Escuro → Automático (mesmo ciclo do painel web).
  Future<void> alternar() => definir(switch (state) {
    ThemeMode.light => ThemeMode.dark,
    ThemeMode.dark => ThemeMode.system,
    ThemeMode.system => ThemeMode.light,
  });
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeMode>(
      (ref) => ThemeController(),
    );
