import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/pisos_antt_provider.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

// Fase Financeiro-ERP (26/07/2026, pedido do Daniel) — "Aba de Piso mínimo
// ANTT tem que estar na visão do cliente, web e PWA". Porta de
// /administracao/pisos-antt (page.tsx), só a listagem (leitura) — ver
// providers/pisos_antt_provider.dart pro porquê de não ter formulário de
// import/exclusão aqui.
class PisosAnttScreen extends ConsumerWidget {
  const PisosAnttScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pisosAnttProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Piso Mínimo ANTT')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (pisos) => _lista(pisos),
      ),
    );
  }

  Widget _lista(List<PisoAntt> pisos) {
    if (pisos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Nenhum piso ANTT cadastrado ainda.', style: TextStyle(color: Colors.grey.shade600)),
        ),
      );
    }

    final porTipo = <String, List<PisoAntt>>{};
    for (final p in pisos) {
      (porTipo[p.tipoCarga] ??= []).add(p);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        const Text(
          'Res. ANTT 5.867/2020 — piso = distância (km) × coeficiente de deslocamento + coeficiente de '
          'carga/descarga, por tipo de carga e nº de eixos. É o valor mínimo legal usado pra alertar quando '
          'uma cotação simulada fica abaixo do piso.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        for (final entrada in porTipo.entries) _cardTipoCarga(entrada.key, entrada.value),
      ],
    );
  }

  Widget _cardTipoCarga(String tipo, List<PisoAntt> linhas) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tipo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            ...linhas.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 68,
                        child: Text('${p.numeroEixos} eixos', style: const TextStyle(fontSize: 12.5)),
                      ),
                      Expanded(
                        child: Text(
                          '${_moeda.format(p.coeficienteDeslocamento)}/km + ${_moeda.format(p.coeficienteCargaDescarga)}',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        DateTime.tryParse(p.vigenciaInicio) != null
                            ? DateFormat('dd/MM/yyyy').format(DateTime.parse(p.vigenciaInicio))
                            : p.vigenciaInicio,
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
