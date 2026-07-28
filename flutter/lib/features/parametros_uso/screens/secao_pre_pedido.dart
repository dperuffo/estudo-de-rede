import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/parametros_uso_provider.dart';
import '../services/parametros_uso_service.dart';

// Fase Pré-Pedido (28/07/2026) — porta de SecaoPrePedido.tsx: diferente dos
// outros 9 tipos de Parâmetros de Uso (listas de regras), é um único
// interruptor por empresa. Quando ligado, todo Plano de Viagem criado a
// partir de uma rota do Roteirizador Inteligente gera automaticamente um
// Pré-Pedido com os pontos de abastecimento pré-agendados, e o
// antifraude/verificar passa a só autorizar abastecimento nesses
// postos/placas (ver planos_viagem_provider.dart, planos_viagem_service.dart
// e roteirizacao_screen.dart).
class SecaoPrePedido extends ConsumerStatefulWidget {
  const SecaoPrePedido({super.key});

  @override
  ConsumerState<SecaoPrePedido> createState() => _SecaoPrePedidoState();
}

class _SecaoPrePedidoState extends ConsumerState<SecaoPrePedido> {
  bool _salvando = false;

  Future<void> _alternar(bool habilitadoAtual) async {
    final pergunta = habilitadoAtual
        ? 'Desativar o Pré-Pedido? Novos Planos de Viagem deixarão de gerar Pré-Pedido, e o antifraude/verificar '
            'deixará de restringir abastecimentos por rota pré-agendada.'
        : 'Ativar o Pré-Pedido? A partir de agora, todo Plano de Viagem criado com rota calculada no Roteirizador '
            'Inteligente vai gerar automaticamente um Pré-Pedido, e abastecimentos passam a ser autorizados só nos '
            'postos/placas pré-agendados.';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(habilitadoAtual ? 'Desativar Pré-Pedido?' : 'Ativar Pré-Pedido?'),
        content: Text(pergunta),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(habilitadoAtual ? 'Desativar' : 'Ativar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final sessao = await ref.read(sessaoProvider.future);
    final empresaId = sessao.empresaId;
    if (empresaId == null || !mounted) return;

    setState(() => _salvando = true);
    await ParametrosUsoService().salvarParametroPrePedido(empresaId: empresaId, habilitado: !habilitadoAtual);
    ref.invalidate(parametroPrePedidoProvider);
    if (mounted) setState(() => _salvando = false);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(parametroPrePedidoProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
      data: (habilitado) => ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
        children: [
          const Text(
            'Quando habilitado, presume-se que uma rota inteligente foi traçada e um Plano de Viagem criado a '
            'partir dela. Esse Plano gera um Pré-Pedido — com número sequencial e os pontos de abastecimento '
            'pré-agendados — e o abastecimento passa a ser restringido: só é autorizado em um posto que conste '
            'como parada pré-agendada daquela placa.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Switch(
                    value: habilitado,
                    onChanged: _salvando ? null : (_) => _alternar(habilitado),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Pré-Pedido ${habilitado ? 'habilitado' : 'desabilitado'} para este cliente',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
