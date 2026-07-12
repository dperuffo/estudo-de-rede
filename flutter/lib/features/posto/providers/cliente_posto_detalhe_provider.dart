import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';
import 'clientes_posto_provider.dart';

// Fase FLT-2 — detalhe de UM cliente na visão do posto, porta (com escopo
// reduzido — ver README) de clientes-posto/[clienteId]/page.tsx +
// CicloAbastecimentoPagamento.tsx: cadastro, negociações com este cliente,
// faturas, e o ciclo em andamento (ainda não fechado) via a RPC
// `ciclos_abertos_postos` (mesma usada em /financeiro-posto na web).
// Fora do escopo desta versão: extrato de fatura em PDF, geração manual de
// fatura, edição de ciclo/prazo — só leitura por enquanto.

class NegociacaoDoCliente {
  final String id;
  final String status;
  final String? combustivel;
  final String? vigenciaInicio;
  final String? vigenciaFim;
  final double? volumeMinimoMensal;
  final double? precoUnitario;

  const NegociacaoDoCliente({
    required this.id,
    required this.status,
    this.combustivel,
    this.vigenciaInicio,
    this.vigenciaFim,
    this.volumeMinimoMensal,
    this.precoUnitario,
  });

  factory NegociacaoDoCliente.fromMap(Map<String, dynamic> m) => NegociacaoDoCliente(
        id: m['id'].toString(),
        status: m['status'] as String? ?? '',
        combustivel: m['combustivel'] as String?,
        vigenciaInicio: m['vigencia_inicio'] as String?,
        vigenciaFim: m['vigencia_fim'] as String?,
        volumeMinimoMensal: (m['volume_minimo_mensal'] as num?)?.toDouble(),
        precoUnitario: (m['preco_unitario'] as num?)?.toDouble(),
      );
}

class FaturaDoCliente {
  final String id;
  final String? periodoInicio;
  final String? periodoFim;
  final String? vencimento;
  final double valorTotal;
  final String status;

  const FaturaDoCliente({
    required this.id,
    this.periodoInicio,
    this.periodoFim,
    this.vencimento,
    required this.valorTotal,
    required this.status,
  });

  factory FaturaDoCliente.fromMap(Map<String, dynamic> m) => FaturaDoCliente(
        id: m['id'].toString(),
        periodoInicio: m['periodo_inicio'] as String?,
        periodoFim: m['periodo_fim'] as String?,
        vencimento: m['vencimento'] as String?,
        valorTotal: (m['valor_total'] as num?)?.toDouble() ?? 0,
        status: m['status'] as String? ?? '',
      );
}

class CicloAberto {
  final String? periodoInicio;
  final String? periodoFimPrevisto;
  final String? vencimentoPrevisto;
  final double valorAcumulado;
  final double volumeAcumulado;
  final int quantidadeAbastecimentos;
  final double valorPendenteNfe;
  final int quantidadePendenteNfe;

  const CicloAberto({
    this.periodoInicio,
    this.periodoFimPrevisto,
    this.vencimentoPrevisto,
    required this.valorAcumulado,
    required this.volumeAcumulado,
    required this.quantidadeAbastecimentos,
    required this.valorPendenteNfe,
    required this.quantidadePendenteNfe,
  });

  factory CicloAberto.fromMap(Map<String, dynamic> m) => CicloAberto(
        periodoInicio: m['periodo_inicio'] as String?,
        periodoFimPrevisto: m['periodo_fim_previsto'] as String?,
        vencimentoPrevisto: m['vencimento_previsto'] as String?,
        valorAcumulado: (m['valor_acumulado'] as num?)?.toDouble() ?? 0,
        volumeAcumulado: (m['volume_acumulado'] as num?)?.toDouble() ?? 0,
        quantidadeAbastecimentos: (m['quantidade_abastecimentos'] as num?)?.toInt() ?? 0,
        valorPendenteNfe: (m['valor_pendente_nfe'] as num?)?.toDouble() ?? 0,
        quantidadePendenteNfe: (m['quantidade_pendente_nfe'] as num?)?.toInt() ?? 0,
      );
}

class ClientePostoDetalhe {
  final ClientePosto? cliente;
  final List<NegociacaoDoCliente> negociacoes;
  final List<FaturaDoCliente> faturas;
  final CicloAberto? cicloAtual;

  const ClientePostoDetalhe({
    required this.cliente,
    required this.negociacoes,
    required this.faturas,
    this.cicloAtual,
  });
}

final clientePostoDetalheProvider =
    FutureProvider.autoDispose.family<ClientePostoDetalhe, String>((ref, clienteId) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) {
    return const ClientePostoDetalhe(cliente: null, negociacoes: [], faturas: []);
  }
  final supabase = SupabaseService.client;

  final clientes = await ref.watch(clientesPostoProvider.future);
  ClientePosto? cliente;
  for (final c in clientes) {
    if (c.id == clienteId) {
      cliente = c;
      break;
    }
  }

  final negociacoesRaw = await supabase
      .from('negociacoes_postos')
      .select('id, status, combustivel, vigencia_inicio, vigencia_fim, volume_minimo_mensal, preco_unitario')
      .eq('empresa_posto_id', empresaId)
      .eq('empresa_cliente_id', clienteId)
      .order('atualizado_em', ascending: false);
  final negociacoes = negociacoesRaw.map((m) => NegociacaoDoCliente.fromMap(m)).toList();

  final faturasRaw = await supabase
      .from('faturas_postos')
      .select('id, periodo_inicio, periodo_fim, vencimento, valor_total, status')
      .eq('empresa_posto_id', empresaId)
      .eq('empresa_cliente_id', clienteId)
      .order('vencimento', ascending: false)
      .limit(200);
  final faturas = faturasRaw.map((m) => FaturaDoCliente.fromMap(m)).toList();

  final ciclosRaw = await supabase.rpc('ciclos_abertos_postos');
  CicloAberto? cicloAtual;
  for (final m in (ciclosRaw as List)) {
    final mm = m as Map<String, dynamic>;
    if (mm['empresa_posto_id'] == empresaId && mm['empresa_cliente_id'] == clienteId) {
      cicloAtual = CicloAberto.fromMap(mm);
      break;
    }
  }

  return ClientePostoDetalhe(
    cliente: cliente,
    negociacoes: negociacoes,
    faturas: faturas,
    cicloAtual: cicloAtual,
  );
});
