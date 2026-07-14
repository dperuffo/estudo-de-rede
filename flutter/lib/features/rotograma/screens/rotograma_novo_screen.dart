import 'package:flutter/material.dart';
import 'rotograma_form.dart';

class RotogramaNovoScreen extends StatelessWidget {
  const RotogramaNovoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Rotograma')),
      body: const RotogramaForm(),
    );
  }
}
