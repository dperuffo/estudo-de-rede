import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/clientes_posto_provider.dart';
import '../providers/negociacoes_provider.dart' show statusNegociacaoLabel;

// Fase FLT-2 — "Clientes" da visão Posto: transportadoras que já
// negociaram com este posto (qualquer status), porta de
// clientes-posto/page.tsx da web.
class ClientesPostoScreen extends ConsumerWidget {
  const ClientesPostoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(clientesPostoProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(clientesPostoProvider),
      child: async.when(
        loading: () => const Center(
          child: Padding(padding: EdgeInsets.only(top: 80), child: CircularProgressIndicator()),
        ),
        error: (e, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [Text('Não deu pra carregar: $e', textAlign: TextAlign.center)],
        ),
        data: (clientes) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Text('Clientes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Transportadoras que já negociaram com este posto (qualquer status).',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            if (clientes.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text('Nenhum cliente negociou com este posto ainda.',
                        style: TextStyle(color: Colors.grey.shade600)),
                  ),
                ),
              )
            else
              ...clientes.map((c) => _linhaCliente(context, c)),
          ],
        ),
      ),
    );
  }

  Widget _linhaCliente(BuildContext context, ClientePosto c) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: () => context.push('/posto/clientes/${c.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(c.nome,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
                const SizedBox(height: 4),
                Text(formatarCnpj(c.cnpj), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                if (c.municipio != null)
                  Text('${c.municipio}/${c.uf ?? ''}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusNegociacaoLabel[c.statusNegociacao] ?? (c.statusNegociacao ?? '—'),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('(${c.negociacoesCount})',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
