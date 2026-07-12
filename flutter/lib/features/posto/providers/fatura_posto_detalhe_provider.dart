import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — pedido do Daniel: clicar numa fatura (tela de cliente do
// posto) e ver o detalhe/extrato dela. Porta com escopo reduzido (ver
// README) de faturas-postos/[id]/page.tsx: período, vencimento, valor,
// status e o detalhamento (linha a linha) dos abastecimentos que compõem
// o valor cobrado, via a mesma RPC `abastecimentos_da_fatura` usada na web
// (SECURITY DEFINER + guarda manual, já resolve o CNPJ sem/com pontuação).
// Fora do escopo desta versão: boleto/PDF, QR Code PIX, dados de
// cedente/sacado (CNPJ/endereço completo) — só o extrato de leitura.
class ItemExtratoAbastecimento {
  final int id;
  final String? data;
  final String? motorista;
  final String? placa;
  final String? combustivel;
  final double? litros;
  final double? precoUnitario;
  final double? valorTotal;

  const ItemExtratoAbastecimento({
    required this.id,
    this.data,
    this.motorista,
    this.placa,
    this.combustivel,
    this.litros,
    this.precoUnitario,
    this.valorTotal,
  });

  factory ItemExtratoAbastecimento.fromMap(Map<String, dynamic> m) => ItemExtratoAbastecimento(
        id: (m['id'] as num).toInt(),
        data: m['data_abastecimento'] as String?,
        motorista: m['motorista_nome'] as String?,
        placa: m['veiculo_placa'] as String?,
        combustivel: m['item_nome'] as String?,
        litros: (m['item_quantidade'] as num?)?.toDouble(),
        precoUnitario: (m['item_valor_unitario'] as num?)?.toDouble(),
        valorTotal: (m['item_valor_total'] as num?)?.toDouble(),
      );
}

class FaturaPostoDetalhe {
  final String id;
  final int? numeroFatura;
  final String? periodoInicio;
  final String? periodoFim;
  final String? vencimento;
  final double valorTotal;
  final double volumeTotal;
  final int quantidadeAbastecimentos;
  final String status;
  final String? clienteNome;
  final List<ItemExtratoAbastecimento> itens;

  const FaturaPostoDetalhe({
    required this.id,
    this.numeroFatura,
    this.periodoInicio,
    this.periodoFim,
    this.vencimento,
    required this.valorTotal,
    required this.volumeTotal,
    required this.quantidadeAbastecimentos,
    required this.status,
    this.clienteNome,
    required this.itens,
  });
}

final faturaPostoDetalheProvider =
    FutureProvider.autoDispose.family<FaturaPostoDetalhe?, String>((ref, faturaId) async {
  final supabase = SupabaseService.client;

  final fatura = await supabase
      .from('faturas_postos')
      .select('id, numero_fatura, periodo_inicio, periodo_fim, vencimento, valor_total, '
          'volume_total, quantidade_abastecimentos, status, cliente_nome')
      .eq('id', faturaId)
      .maybeSingle();
  if (fatura == null) return null;

  final itensRaw = await supabase.rpc('abastecimentos_da_fatura', params: {'p_fatura_id': faturaId}) as List;
  final itens = itensRaw.map((m) => ItemExtratoAbastecimento.fromMap(m as Map<String, dynamic>)).toList();

  return FaturaPostoDetalhe(
    id: fatura['id'].toString(),
    numeroFatura: (fatura['numero_fatura'] as num?)?.toInt(),
    periodoInicio: fatura['periodo_inicio'] as String?,
    periodoFim: fatura['periodo_fim'] as String?,
    vencimento: fatura['vencimento'] as String?,
    valorTotal: (fatura['valor_total'] as num?)?.toDouble() ?? 0,
    volumeTotal: (fatura['volume_total'] as num?)?.toDouble() ?? 0,
    quantidadeAbastecimentos: (fatura['quantidade_abastecimentos'] as num?)?.toInt() ?? 0,
    status: fatura['status'] as String? ?? '',
    clienteNome: fatura['cliente_nome'] as String?,
    itens: itens,
  );
});
