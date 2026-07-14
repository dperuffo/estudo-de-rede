import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/rotograma_provider.dart';

// Fase FLT-3 — Rotograma de Segurança (cliente): lista, porta de
// rotograma/page.tsx. Ver escopo em rotograma_provider.dart.
class RotogramaScreen extends ConsumerWidget {
  const RotogramaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listaAsync = ref.watch(rotogramasListaProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Rotograma de Segurança')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/rotograma/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Novo'),
      ),
      body: listaAsync.when(
        data: (lista) => _lista(context, lista),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
      ),
    );
  }

  Widget _lista(BuildContext context, List<RotogramaResumo> lista) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Mapa de pontos de risco, paradas e contatos de emergência para o motorista levar na viagem.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        if (lista.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('Nenhum Rotograma cadastrado ainda.', style: TextStyle(color: Colors.grey.shade500)),
          )
        else
          ...lista.map((r) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => context.push('/rotograma/${r.id}'),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFEFF6FF),
                    child: Text('#${r.numero}', style: const TextStyle(fontSize: 10, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w700)),
                  ),
                  title: Text('${r.origem ?? '—'} → ${r.destino ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text(
                    '${r.motorista ?? '—'} · ${r.placa ?? '—'}${r.dataViagem != null ? ' · ${r.dataViagem}' : ''}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              )),
      ],
    );
  }
}
