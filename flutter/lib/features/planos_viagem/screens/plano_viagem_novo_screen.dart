import 'package:flutter/material.dart';
import 'plano_viagem_form.dart';

// Fase FLT-3 — Novo Plano de Viagem (cliente), porta de
// planos-viagem/novo/page.tsx. Sem seletor de cliente (a visão cliente
// sempre usa a empresa da sessão — ver planos_viagem_provider.dart).
class PlanoViagemNovoScreen extends StatelessWidget {
  const PlanoViagemNovoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Plano de Viagem')),
      body: const PlanoViagemForm(),
    );
  }
}
