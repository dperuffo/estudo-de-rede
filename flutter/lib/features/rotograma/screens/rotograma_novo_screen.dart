import 'package:flutter/material.dart';
import 'rotograma_form.dart';

import '../../../core/theme/app_theme.dart';

class RotogramaNovoScreen extends StatelessWidget {
  const RotogramaNovoScreen({super.key});

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
          title: const Text('Novo Rotograma')),
      body: const RotogramaForm(),
    );
  }
}
