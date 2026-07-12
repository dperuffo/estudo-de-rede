import 'package:flutter/material.dart';

// Fase FLT-1 — placeholder genérico pras telas da visão Posto que ainda vão
// ser construídas de verdade na Fase FLT-2 (uma de cada vez — ver tarefa
// "PWA Flutter — Fase FLT-2" na lista de tarefas). Existe pra já deixar a
// navegação/menu certos funcionando agora, sem prometer funcionalidade que
// ainda não foi implementada.
class EmConstrucaoScreen extends StatelessWidget {
  final String titulo;
  const EmConstrucaoScreen({super.key, required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.construction, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                '$titulo ainda está em construção nesta versão do app.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                'Por enquanto, use a versão web pra essa funcionalidade.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
