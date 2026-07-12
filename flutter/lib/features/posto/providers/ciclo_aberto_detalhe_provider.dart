import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — pedido do Daniel: clicar no card "Ciclo em andamento" (tela
// de cliente do posto) e ver o detalhamento de QUAIS abastecimentos
// compõem o valor acumulado. Porta com escopo reduzido (ver README) de
// ciclo-aberto/[negociacaoId]/page.tsx: período/vencimento/valor são
// PREVISTOS (podem mudar até o robô fechar o ciclo) + lista linha a linha
// via a RPC `abastecimentos_do_ciclo_aberto`, paginada em lotes de 1000
// (mesmo achado real da Fase 27.123 na web — limite padrão do PostgREST,
// db-max-rows, corta silenciosamente ciclos com mais de 1000 linhas).
class ItemExtratoCiclo {
  final int id;
  final String? data;
  final String? motorista;
  final String? placa;
  final String? combustivel;
  final double? litros;
  final double? precoUnitario;
  final double? valorTotal;
  final bool temNfe;

  const ItemExtratoCiclo({
    required this.id,
    this.data,
    this.motorista,
    this.placa,
    this.combustivel,
    this.litros,
    this.precoUnitario,
    this.valorTotal,
    required this.temNfe,
  });

  factory ItemExtratoCiclo.fromMap(Map<String, dynamic> m) => ItemExtratoCiclo(
        id: (m['id'] as num).toInt(),
        data: m['data_abastecimento'] as String?,
        motorista: m['motorista_nome'] as String?,
        placa: m['veiculo_placa'] as String?,
        combustivel: m['item_nome'] as String?,
        litros: (m['item_quantidade'] as num?)?.toDouble(),
        precoUnitario: (m['item_valor_unitario'] as num?)?.toDouble(),
        valorTotal: (m['item_valor_total'] as num?)?.toDouble(),
        temNfe: m['tem_nfe'] as bool? ?? false,
      );
}

class CicloAbertoDetalhe {
  final String negociacaoId;
  final String? postoNome;
  final String? clienteNome;
  final String? periodoInicio;
  final String? periodoFimPrevisto;
  final String? vencimentoPrevisto;
  final double valorAcumulado;
  final double volumeAcumulado;
  final int quantidadeAbastecimentos;
  final double valorPendenteNfe;
  final int quantidadePendenteNfe;
  final List<ItemExtratoCiclo> itens;

  const CicloAbertoDetalhe({
    required this.negociacaoId,
    this.postoNome,
    this.clienteNome,
    this.periodoInicio,
    this.periodoFimPrevisto,
    this.vencimentoPrevisto,
    required this.valorAcumulado,
    required this.volumeAcumulado,
    required this.quantidadeAbastecimentos,
    required this.valorPendenteNfe,
    required this.quantidadePendenteNfe,
    required this.itens,
  });
}

final cicloAbertoDetalheProvider =
    FutureProvider.autoDispose.family<CicloAbertoDetalhe?, String>((ref, negociacaoId) async {
  final supabase = SupabaseService.client;

  final ciclosRaw = await supabase.rpc('ciclos_abertos_postos') as List;
  Map<String, dynamic>? ciclo;
  for (final m in ciclosRaw) {
    final mm = m as Map<String, dynamic>;
    if (mm['negociacao_id'].toString() == negociacaoId) {
      ciclo = mm;
      break;
    }
  }
  if (ciclo == null) return null;

  const tamanhoLote = 1000;
  final todos = <ItemExtratoCiclo>[];
  var offset = 0;
  while (true) {
    final lote = await supabase
        .rpc('abastecimentos_do_ciclo_aberto', params: {'p_negociacao_id': negociacaoId}).range(
            offset, offset + tamanhoLote - 1) as List;
    if (lote.isEmpty) break;
    todos.addAll(lote.map((m) => ItemExtratoCiclo.fromMap(m as Map<String, dynamic>)));
    if (lote.length < tamanhoLote) break;
    offset += tamanhoLote;
  }

  return CicloAbertoDetalhe(
    negociacaoId: negociacaoId,
    postoNome: ciclo['posto_nome'] as String?,
    clienteNome: ciclo['cliente_nome'] as String?,
    periodoInicio: ciclo['periodo_inicio'] as String?,
    periodoFimPrevisto: ciclo['periodo_fim_previsto'] as String?,
    vencimentoPrevisto: ciclo['vencimento_previsto'] as String?,
    valorAcumulado: (ciclo['valor_acumulado'] as num?)?.toDouble() ?? 0,
    volumeAcumulado: (ciclo['volume_acumulado'] as num?)?.toDouble() ?? 0,
    quantidadeAbastecimentos: (ciclo['quantidade_abastecimentos'] as num?)?.toInt() ?? 0,
    valorPendenteNfe: (ciclo['valor_pendente_nfe'] as num?)?.toDouble() ?? 0,
    quantidadePendenteNfe: (ciclo['quantidade_pendente_nfe'] as num?)?.toInt() ?? 0,
    itens: todos,
  );
});
