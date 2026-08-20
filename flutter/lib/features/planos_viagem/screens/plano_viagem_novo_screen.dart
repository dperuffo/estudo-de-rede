import 'package:flutter/material.dart';
import '../providers/planos_viagem_provider.dart';
import 'plano_viagem_form.dart';

import '../../../core/theme/app_theme.dart';

// Fase FLT-3 — Novo Plano de Viagem (cliente), porta de
// planos-viagem/novo/page.tsx. Sem seletor de cliente (a visão cliente
// sempre usa a empresa da sessão — ver planos_viagem_provider.dart).
// Fase Pré-Pedido (28/07/2026) — aceita prefill opcional vindo do botão
// "Criar Plano de Viagem" na Roteirização (passado via `extra` do GoRouter).
class PlanoViagemNovoScreen extends StatelessWidget {
  final PrefillPlanoViagem? prefill;
  const PlanoViagemNovoScreen({super.key, this.prefill});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Novo Plano de Viagem')),
      body: PlanoViagemForm(prefill: prefill),
    );
  }
}
