import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pre_pedidos_posto_provider.dart';

import '../../../core/theme/app_theme.dart';

// Fase Pré-Pedido (28/07/2026) — porta de pre-pedidos/page.tsx: o posto
// digita o número do Pré-Pedido informado pelo motorista antes de liberar o
// abastecimento, e confere placa/motorista/parada pré-agendada. Ver
// pre_pedidos_posto_provider.dart pra por que isso usa uma RPC em vez de
// query direta.
class PrePedidosPostoScreen extends ConsumerStatefulWidget {
  const PrePedidosPostoScreen({super.key});

  @override
  ConsumerState<PrePedidosPostoScreen> createState() =>
      _PrePedidosPostoScreenState();
}

class _PrePedidosPostoScreenState extends ConsumerState<PrePedidosPostoScreen> {
  final _numeroCtrl = TextEditingController();
  int? _numeroConsultado;

  @override
  void dispose() {
    _numeroCtrl.dispose();
    super.dispose();
  }

  void _consultar() {
    final numero = int.tryParse(_numeroCtrl.text.trim());
    if (numero == null || numero <= 0) return;
    setState(() => _numeroConsultado = numero);
  }

  @override
  Widget build(BuildContext context) {
    final async = _numeroConsultado != null
        ? ref.watch(consultaPrePedidoProvider(_numeroConsultado!))
        : null;

    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Consulta de Pré-Pedido')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Confira o número do Pré-Pedido informado pelo motorista antes de liberar o abastecimento.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _numeroCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Número do Pré-Pedido',
                    hintText: 'Ex.: 1024',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _consultar(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                  onPressed: _consultar, child: const Text('Consultar')),
            ],
          ),
          const SizedBox(height: 16),
          if (async != null)
            async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Erro ao consultar: $e',
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
              data: (resultado) {
                if (resultado == null) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Nenhum Pré-Pedido nº $_numeroConsultado com parada pré-agendada para este posto foi '
                        'encontrado. Confira o número com o motorista ou se o CNPJ deste posto está na rota '
                        'planejada.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  );
                }
                return _cardResultado(resultado);
              },
            ),
        ],
      ),
    );
  }

  Widget _cardResultado(ConsultaPrePedido r) {
    final statusLabel = r.status == 'ativo'
        ? 'Ativo'
        : r.status == 'concluido'
            ? 'Concluído'
            : 'Cancelado';
    final statusCor = r.status == 'ativo'
        ? const Color(0xFF16A34A)
        : r.status == 'concluido'
            ? Colors.grey
            : const Color(0xFFDC2626);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Pré-Pedido nº ${r.numero}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: statusCor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(statusLabel,
                      style: TextStyle(
                          fontSize: 11,
                          color: statusCor,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _campo('Placa', r.placa ?? '—'),
                _campo('Motorista', r.motoristaNome ?? '—'),
                _campo('Data de saída', r.dataSaida ?? '—'),
                _campo('Km estimado', r.kmEstimado?.toStringAsFixed(0) ?? '—'),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PARADA PRÉ-AGENDADA NESTE POSTO',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade500)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${r.paradaPostoNome ?? 'Este posto'}'
                          '${r.paradaLitrosPrevistos != null ? ' · ${r.paradaLitrosPrevistos} L previstos' : ''}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (r.paradaAtendida
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFB45309))
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          r.paradaAtendida
                              ? 'Já abastecido'
                              : 'Autorizado — pendente',
                          style: TextStyle(
                              fontSize: 11,
                              color: r.paradaAtendida
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFB45309),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (!r.paradaAtendida && r.status == 'ativo') ...[
                    const SizedBox(height: 6),
                    Text(
                      'Este veículo está autorizado a abastecer aqui. A confirmação é feita automaticamente pela '
                      'integração no momento do abastecimento.',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campo(String label, String valor) => SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            const SizedBox(height: 2),
            Text(valor,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
