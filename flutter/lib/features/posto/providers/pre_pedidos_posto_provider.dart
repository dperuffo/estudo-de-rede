import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase Pré-Pedido (28/07/2026) — porta de pre-pedidos/page.tsx: consulta do
// posto pra conferir, antes de liberar o abastecimento, se um veículo tem
// Pré-Pedido ativo com parada pré-agendada NESTE posto. Usa a RPC SECURITY
// DEFINER `consultar_pre_pedido_para_posto` (não uma query direta em
// pre_pedidos/pre_pedidos_paradas) — RLS dessas tabelas é escopada pela
// empresa DONA do pré-pedido (o cliente/frota), não pelo posto; a RPC
// resolve isso devolvendo só a parada do próprio posto chamador, nunca o
// itinerário completo do cliente (evita vazar rota pra concorrente).
class ConsultaPrePedido {
  final String prePedidoId;
  final int numero;
  final String status; // ativo | concluido | cancelado
  final String? placa;
  final String? motoristaNome;
  final String? dataSaida;
  final double? kmEstimado;
  final String? paradaPostoNome;
  final double? paradaLitrosPrevistos;
  final bool paradaAtendida;

  const ConsultaPrePedido({
    required this.prePedidoId,
    required this.numero,
    required this.status,
    this.placa,
    this.motoristaNome,
    this.dataSaida,
    this.kmEstimado,
    this.paradaPostoNome,
    this.paradaLitrosPrevistos,
    required this.paradaAtendida,
  });

  factory ConsultaPrePedido.fromMap(Map<String, dynamic> m) => ConsultaPrePedido(
        prePedidoId: m['pre_pedido_id'] as String,
        numero: m['numero'] as int,
        status: m['status'] as String? ?? 'ativo',
        placa: m['placa'] as String?,
        motoristaNome: m['motorista_nome'] as String?,
        dataSaida: m['data_saida'] as String?,
        kmEstimado: (m['km_estimado'] as num?)?.toDouble(),
        paradaPostoNome: m['parada_posto_nome'] as String?,
        paradaLitrosPrevistos: (m['parada_litros_previstos'] as num?)?.toDouble(),
        paradaAtendida: m['parada_atendida'] as bool? ?? false,
      );
}

final consultaPrePedidoProvider = FutureProvider.autoDispose.family<ConsultaPrePedido?, int>((ref, numero) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null || numero <= 0) return null;

  final rows = await SupabaseService.client.rpc('consultar_pre_pedido_para_posto', params: {
    'p_numero': numero,
    'p_empresa_posto_id': empresaId,
  }) as List;

  if (rows.isEmpty) return null;
  return ConsultaPrePedido.fromMap(rows.first as Map<String, dynamic>);
});
