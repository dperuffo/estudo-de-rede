import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — Notas Fiscais (cliente), porta de notas-fiscais/page.tsx +
// [notaId]/page.tsx. RLS/RPCs conferidas antes de portar: as RPCs de
// listagem são SECURITY DEFINER mas conferem `p_empresa_id`/negociação
// internamente contra `empresas_do_usuario(email)` — chamar com
// `sessao.empresaId` é seguro. `notas_fiscais_abastecimento` tem RLS de
// leitura direta (tem tanto `empresa_posto_id` quanto `empresa_cliente_id`)
// — a tela de detalhe usa `.from()` igual à web, sem precisar de RPC.
//
// Fase NFE-1 — pedido do Daniel: "percentual de recolha por ciclo, seja o
// status que ele estiver". O indicador único de 90 dias (`indicador_notas_
// fiscais`/`abastecimentos_com_status_nota_fiscal`) virou 1 ciclo por
// negociação (`nfe_recolha_por_ciclo`), e a lista de abastecimentos passou
// a ser escopada ao ciclo selecionado (`abastecimentos_do_ciclo_nfe`) — ver
// mesma mudança em src/app/(dashboard)/notas-fiscais/page.tsx da web.
//
// Escopo reduzido: sem seção "Uploads sem abastecimento correspondente"
// (só aparece pro posto, que é quem sobe o XML — fora de escopo aqui) e
// sem botão "Baixar PDF" da NF-e (a web monta o PDF inteiro em memória
// via jsPDF — deixado fora do v1 mobile). Também sem paginação de
// verdade: a web pagina 20 em 20; aqui traz até 100 linhas por ciclo,
// suficiente pro celular.
const statusNotasValidos = ['emitida', 'rejeitada', 'pendente'];

class CicloNfe {
  final String negociacaoId;
  final String? postoNome;
  final String? clienteNome;
  final String? faturaPostoId;
  // 'aberto' (virtual) | 'fechada' | 'a_vencer' | 'vencida' (derivado) |
  // 'paga' | 'cancelada'.
  final String status;
  final String periodoInicio;
  final String periodoFim;
  final String vencimento;
  final int total;
  final int comNota;
  final int semNota;
  final int rejeitadas;
  final double? percentual;

  const CicloNfe({
    required this.negociacaoId,
    this.postoNome,
    this.clienteNome,
    this.faturaPostoId,
    required this.status,
    required this.periodoInicio,
    required this.periodoFim,
    required this.vencimento,
    required this.total,
    required this.comNota,
    required this.semNota,
    required this.rejeitadas,
    this.percentual,
  });

  int get pendentes => semNota - rejeitadas;

  factory CicloNfe.fromMap(Map<String, dynamic> m) => CicloNfe(
        negociacaoId: m['negociacao_id'] as String,
        postoNome: m['posto_nome'] as String?,
        clienteNome: m['cliente_nome'] as String?,
        faturaPostoId: m['fatura_posto_id'] as String?,
        status: m['status'] as String? ?? 'aberto',
        periodoInicio: m['periodo_inicio'] as String,
        periodoFim: m['periodo_fim'] as String,
        vencimento: m['vencimento'] as String,
        total: (m['total'] as num?)?.toInt() ?? 0,
        comNota: (m['com_nota'] as num?)?.toInt() ?? 0,
        semNota: (m['sem_nota'] as num?)?.toInt() ?? 0,
        rejeitadas: (m['rejeitadas'] as num?)?.toInt() ?? 0,
        percentual: (m['percentual'] as num?)?.toDouble(),
      );
}

final ciclosNfeProvider = FutureProvider.autoDispose<List<CicloNfe>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client
      .rpc('nfe_recolha_por_ciclo', params: {'p_empresa_id': empresaId, 'p_qtd_fechados': 6}) as List;
  final ciclos = rows.map((m) => CicloNfe.fromMap(m as Map<String, dynamic>)).toList();
  // ciclo aberto primeiro, depois os fechados do mais recente pro mais antigo.
  ciclos.sort((a, b) {
    if (a.status == 'aberto' && b.status != 'aberto') return -1;
    if (b.status == 'aberto' && a.status != 'aberto') return 1;
    return b.periodoFim.compareTo(a.periodoFim);
  });
  return ciclos;
});

class LinhaNotaFiscal {
  final int abastecimentoId;
  final String provedor;
  final String? codigoAbastecimento;
  final String dataAbastecimento;
  final String? clienteNome;
  final String? postoNome;
  final String? veiculoPlaca;
  final String? itemNome;
  final double? itemValorTotal;
  final String? notaId;
  final int? notaNumero;
  final String? pendenciaMotivo;
  final String? pendenciaDetalheTexto;
  final String? pendenciaNomeArquivo;
  final String? pendenciaCnpjEmitente;
  final String? pendenciaProdutoNomeXml;
  final double? pendenciaQuantidade;
  final double? pendenciaValorTotal;

  const LinhaNotaFiscal({
    required this.abastecimentoId,
    required this.provedor,
    this.codigoAbastecimento,
    required this.dataAbastecimento,
    this.clienteNome,
    this.postoNome,
    this.veiculoPlaca,
    this.itemNome,
    this.itemValorTotal,
    this.notaId,
    this.notaNumero,
    this.pendenciaMotivo,
    this.pendenciaDetalheTexto,
    this.pendenciaNomeArquivo,
    this.pendenciaCnpjEmitente,
    this.pendenciaProdutoNomeXml,
    this.pendenciaQuantidade,
    this.pendenciaValorTotal,
  });

  factory LinhaNotaFiscal.fromMap(Map<String, dynamic> m) {
    return LinhaNotaFiscal(
      abastecimentoId: (m['abastecimento_id'] as num).toInt(),
      provedor: m['provedor'] as String? ?? '',
      codigoAbastecimento: m['codigo_abastecimento'] as String?,
      dataAbastecimento: m['data_abastecimento'] as String,
      clienteNome: m['cliente_nome'] as String?,
      postoNome: m['posto_nome'] as String?,
      veiculoPlaca: m['veiculo_placa'] as String?,
      itemNome: m['item_nome'] as String?,
      itemValorTotal: (m['item_valor_total'] as num?)?.toDouble(),
      notaId: m['nota_id'] as String?,
      notaNumero: (m['nota_numero'] as num?)?.toInt(),
      pendenciaMotivo: m['pendencia_motivo'] as String?,
      pendenciaDetalheTexto: m['pendencia_detalhe_texto'] as String?,
      pendenciaNomeArquivo: m['pendencia_nome_arquivo'] as String?,
      pendenciaCnpjEmitente: m['pendencia_cnpj_emitente'] as String?,
      pendenciaProdutoNomeXml: m['pendencia_produto_nome_xml'] as String?,
      pendenciaQuantidade: (m['pendencia_quantidade'] as num?)?.toDouble(),
      pendenciaValorTotal: (m['pendencia_valor_total'] as num?)?.toDouble(),
    );
  }

  // 'emitida' | 'rejeitada' | 'pendente' — mesma derivação da web.
  String get status {
    if (notaId != null) return 'emitida';
    if (pendenciaMotivo != null) return 'rejeitada';
    return 'pendente';
  }
}

class FiltrosNotasFiscais {
  final String negociacaoId;
  final String periodoInicio;
  final String periodoFim;
  final String? status;
  final String? busca;
  const FiltrosNotasFiscais({
    required this.negociacaoId,
    required this.periodoInicio,
    required this.periodoFim,
    this.status,
    this.busca,
  });

  @override
  bool operator ==(Object other) =>
      other is FiltrosNotasFiscais &&
      other.negociacaoId == negociacaoId &&
      other.periodoInicio == periodoInicio &&
      other.periodoFim == periodoFim &&
      other.status == status &&
      other.busca == busca;
  @override
  int get hashCode => Object.hash(negociacaoId, periodoInicio, periodoFim, status, busca);
}

final linhasNotasFiscaisProvider =
    FutureProvider.autoDispose.family<List<LinhaNotaFiscal>, FiltrosNotasFiscais>((ref, filtros) async {
  final rows = await SupabaseService.client.rpc('abastecimentos_do_ciclo_nfe', params: {
    'p_negociacao_id': filtros.negociacaoId,
    'p_periodo_inicio': filtros.periodoInicio,
    'p_periodo_fim': filtros.periodoFim,
    'p_status': filtros.status,
    'p_busca': (filtros.busca == null || filtros.busca!.trim().isEmpty) ? null : filtros.busca!.trim(),
    'p_limit': 100,
    'p_offset': 0,
  }) as List;
  return rows.map((m) => LinhaNotaFiscal.fromMap(m as Map<String, dynamic>)).toList();
});

class NotaFiscalDetalhe {
  final String id;
  final int numeroNf;
  final String serieNf;
  final String chaveAcesso;
  final String dataEmissao;
  final String cnpjEmitente;
  final String nomeEmitente;
  final String cnpjDestinatario;
  final String nomeDestinatario;
  final String produtoNomeXml;
  final String produtoCodigoAnp;
  final String produtoDescricaoAnp;
  final double quantidade;
  final double valorUnitario;
  final double valorTotal;
  final String? abastecimentoData;
  final String? veiculoPlaca;
  final String? motoristaNome;

  const NotaFiscalDetalhe({
    required this.id,
    required this.numeroNf,
    required this.serieNf,
    required this.chaveAcesso,
    required this.dataEmissao,
    required this.cnpjEmitente,
    required this.nomeEmitente,
    required this.cnpjDestinatario,
    required this.nomeDestinatario,
    required this.produtoNomeXml,
    required this.produtoCodigoAnp,
    required this.produtoDescricaoAnp,
    required this.quantidade,
    required this.valorUnitario,
    required this.valorTotal,
    this.abastecimentoData,
    this.veiculoPlaca,
    this.motoristaNome,
  });
}

final notaFiscalDetalheProvider = FutureProvider.autoDispose.family<NotaFiscalDetalhe?, String>((ref, notaId) async {
  final supabase = SupabaseService.client;
  final nota = await supabase
      .from('notas_fiscais_abastecimento')
      .select(
          'id, numero_nf, serie_nf, chave_acesso, data_emissao, cnpj_emitente, nome_emitente, cnpj_destinatario, nome_destinatario, produto_nome_xml, produto_codigo_anp, produto_descricao_anp, quantidade, valor_unitario, valor_total, abastecimento_id, abastecimento_externo_id')
      .eq('id', notaId)
      .maybeSingle();
  if (nota == null) return null;

  String? abastecimentoData;
  String? veiculoPlaca;
  String? motoristaNome;
  if (nota['abastecimento_id'] != null) {
    final ab = await supabase
        .from('profrotas_abastecimentos')
        .select('data_abastecimento, veiculo_placa, motorista_nome')
        .eq('id', nota['abastecimento_id'])
        .maybeSingle();
    abastecimentoData = ab?['data_abastecimento'] as String?;
    veiculoPlaca = ab?['veiculo_placa'] as String?;
    motoristaNome = ab?['motorista_nome'] as String?;
  } else if (nota['abastecimento_externo_id'] != null) {
    final ab = await supabase
        .from('abastecimentos_externos')
        .select('data_abastecimento, placa, motorista_nome')
        .eq('id', nota['abastecimento_externo_id'])
        .maybeSingle();
    abastecimentoData = ab?['data_abastecimento'] as String?;
    veiculoPlaca = ab?['placa'] as String?;
    motoristaNome = ab?['motorista_nome'] as String?;
  }

  return NotaFiscalDetalhe(
    id: nota['id'] as String,
    numeroNf: (nota['numero_nf'] as num).toInt(),
    serieNf: nota['serie_nf'] as String? ?? '',
    chaveAcesso: nota['chave_acesso'] as String? ?? '',
    dataEmissao: nota['data_emissao'] as String,
    cnpjEmitente: nota['cnpj_emitente'] as String? ?? '',
    nomeEmitente: nota['nome_emitente'] as String? ?? '',
    cnpjDestinatario: nota['cnpj_destinatario'] as String? ?? '',
    nomeDestinatario: nota['nome_destinatario'] as String? ?? '',
    produtoNomeXml: nota['produto_nome_xml'] as String? ?? '',
    produtoCodigoAnp: nota['produto_codigo_anp'] as String? ?? '',
    produtoDescricaoAnp: nota['produto_descricao_anp'] as String? ?? '',
    quantidade: (nota['quantidade'] as num?)?.toDouble() ?? 0,
    valorUnitario: (nota['valor_unitario'] as num?)?.toDouble() ?? 0,
    valorTotal: (nota['valor_total'] as num?)?.toDouble() ?? 0,
    abastecimentoData: abastecimentoData,
    veiculoPlaca: veiculoPlaca,
    motoristaNome: motoristaNome,
  );
});

// Porta 1:1 de mensagemMotivoPendencia (src/lib/nfe.ts).
String mensagemMotivoPendencia(String? motivo) {
  switch (motivo) {
    case 'sem_correspondencia':
      return 'Nenhum abastecimento encontrado com o CNPJ, quantidade e valor desta NF-e.';
    case 'erro_leitura_xml':
      return 'O XML não pôde ser lido — confira se é o arquivo certo.';
    case 'modelo_invalido':
      return 'O XML não é uma NF-e modelo 55.';
    case 'posto_nao_encontrado':
      return 'O CNPJ do emitente não corresponde a nenhum posto cadastrado na plataforma.';
    case 'cliente_nao_encontrado':
      return 'O CNPJ do destinatário não corresponde a nenhum cliente cadastrado na plataforma.';
    case 'nao_autorizado':
      return 'Você não tem permissão para vincular NF-e a este posto.';
    case 'abastecimento_nao_encontrado':
      return 'O abastecimento indicado não foi encontrado.';
    case 'abastecimento_ja_tem_nota':
      return 'Esse abastecimento já tem uma NF-e vinculada.';
    case 'cnpj_nao_corresponde_ao_abastecimento':
      return 'Os CNPJ da NF-e não correspondem aos do abastecimento selecionado.';
    case 'fora_da_tolerancia':
      return 'A quantidade ou o valor da NF-e estão fora da margem aceita em relação ao abastecimento (até 0,5 L ou 2% de diferença).';
    case 'codigo_anp_invalido':
      return 'O código ANP informado na NF-e não é um código ANP válido.';
    case 'combustivel_sem_mapeamento_anp':
      return 'Não há um código ANP cadastrado para o combustível deste abastecimento — avise o suporte da FNI.';
    case 'codigo_anp_nao_corresponde':
      return 'O código ANP da NF-e não corresponde ao combustível deste abastecimento.';
    case 'chave_duplicada':
      return 'Esta NF-e já foi cadastrada anteriormente.';
    default:
      return 'Não foi possível validar esta NF-e.';
  }
}
