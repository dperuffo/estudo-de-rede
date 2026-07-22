import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — detalhe de UM abastecimento (PróFrotas ou externo) na visão
// Posto + o painel de ajuste, porta (com escopo reduzido — ver README) de
// abastecimentos/[id]/page.tsx + abastecimentos/externo/[id]/page.tsx +
// PainelAjusteAbastecimento.tsx da web. Usa `abastecimentos_unificado`
// (mesma view já usada em abastecimentos_posto_service.dart) em vez de
// consultar profrotas_abastecimentos/abastecimentos_externos direto — os
// nomes de coluna já vêm normalizados (produto/litros/preco_litro), o que
// evita duplicar a lógica de "traduzir" nomes que a web precisa fazer pro
// lado externo.
//
// Diferente da web (que serve os dois lados — cliente e posto — e precisa
// RESOLVER de qual lado o usuário está via CNPJ/empresas_do_usuario), aqui
// já sabemos: esta tela só existe dentro do shell /posto, então
// empresaPostoId é sempre a empresa da sessão logada.

class AbastecimentoParaAjuste {
  final String id;
  final String provedor;
  final String? codigoAbastecimento;
  final String? dataAbastecimento;
  final String? placa;
  final String? motoristaNome;
  final double? hodometro;
  final String? produto;
  final double? litros;
  final double? precoLitro;
  final double? valorTotal;
  final String? empresaClienteId;
  final String? nomeCliente;
  // Fase FLT-3 — só preenchido pelo provider do lado CLIENTE (resolvido a
  // partir do posto_cnpj via RPC `resolver_empresa_por_cnpj_segmento`, ver
  // ajuste_abastecimento_cliente_provider.dart). O provider do lado posto
  // não precisa disso — já sabe seu próprio empresaId pela sessão.
  final String? empresaPostoId;
  // Nova regra do Daniel: abastecimento já alocado numa fatura (ciclo
  // realmente fechado, faturado) não pode mais ser ajustado — mesma
  // checagem da web (PainelAjusteAbastecimento.tsx: fatura_posto_id !=
  // null). Vem da view abastecimentos_unificado (coluna acrescentada nesta
  // mesma leva de mudanças).
  final String? faturaPostoId;

  const AbastecimentoParaAjuste({
    required this.id,
    required this.provedor,
    this.codigoAbastecimento,
    this.dataAbastecimento,
    this.placa,
    this.motoristaNome,
    this.hodometro,
    this.produto,
    this.litros,
    this.precoLitro,
    this.valorTotal,
    this.empresaClienteId,
    this.nomeCliente,
    this.empresaPostoId,
    this.faturaPostoId,
  });

  String get identificadorTipo => provedor == 'profrotas' ? 'profrotas' : 'externo';
  bool get cicloFechado => faturaPostoId != null;
}

class RodadaAjuste {
  final int numeroRodada;
  final String autor;
  final String? dataAbastecimento;
  final double? hodometro;
  final String? itemNome;
  final double? itemQuantidade;
  final double? itemValorUnitario;
  final double? itemValorTotal;
  final String? motivo;
  final String decisao;
  final String criadoEm;

  const RodadaAjuste({
    required this.numeroRodada,
    required this.autor,
    this.dataAbastecimento,
    this.hodometro,
    this.itemNome,
    this.itemQuantidade,
    this.itemValorUnitario,
    this.itemValorTotal,
    this.motivo,
    required this.decisao,
    required this.criadoEm,
  });

  factory RodadaAjuste.fromMap(Map<String, dynamic> m) => RodadaAjuste(
        numeroRodada: (m['numero_rodada'] as num).toInt(),
        autor: m['autor'] as String? ?? '',
        dataAbastecimento: m['data_abastecimento'] as String?,
        hodometro: (m['hodometro'] as num?)?.toDouble(),
        itemNome: m['item_nome'] as String?,
        itemQuantidade: (m['item_quantidade'] as num?)?.toDouble(),
        itemValorUnitario: (m['item_valor_unitario'] as num?)?.toDouble(),
        itemValorTotal: (m['item_valor_total'] as num?)?.toDouble(),
        motivo: m['motivo'] as String?,
        decisao: m['decisao'] as String? ?? 'pendente',
        criadoEm: m['criado_em'] as String? ?? '',
      );
}

class AjusteAberto {
  final String id;
  final String status;
  const AjusteAberto({required this.id, required this.status});
}

class AjusteAbastecimentoDetalhe {
  final AbastecimentoParaAjuste? abastecimento;
  final AjusteAberto? ajusteAberto;
  final List<RodadaAjuste> rodadas;

  const AjusteAbastecimentoDetalhe({required this.abastecimento, this.ajusteAberto, required this.rodadas});

  // "chave" no formato "provedor:id" — igual à usada na lista de
  // Abastecimentos (abastecimentos_posto_service.dart).
  bool get minhaVezDeResponder => ajusteAberto?.status == 'pendente_posto';
}

// A rota usa "chave" = "provedor:id" (mesmo formato de
// RegistroAbastecimentoPosto.chave). Faz o split aqui.
final ajusteAbastecimentoProvider =
    FutureProvider.autoDispose.family<AjusteAbastecimentoDetalhe, String>((ref, chave) async {
  final partes = chave.split(':');
  final provedor = partes.first;
  final idTexto = partes.sublist(1).join(':');

  final sessao = await ref.watch(sessaoProvider.future);
  final empresaPostoId = sessao.empresaId;
  final supabase = SupabaseService.client;

  final linha = await supabase
      .from('abastecimentos_unificado')
      .select(
        'id, provedor, codigo_abastecimento, data_abastecimento, placa, motorista_nome, hodometro, produto, litros, preco_litro, valor_total, empresa_id, fatura_posto_id',
      )
      .eq('id', idTexto)
      .eq('provedor', provedor)
      .maybeSingle();

  if (linha == null) {
    return const AjusteAbastecimentoDetalhe(abastecimento: null, rodadas: []);
  }

  String? nomeCliente;
  final empresaClienteId = linha['empresa_id'] as String?;
  if (empresaClienteId != null) {
    nomeCliente =
        await supabase.rpc('nome_empresa_publico', params: {'p_empresa_id': empresaClienteId}) as String?;
  }

  final abastecimento = AbastecimentoParaAjuste(
    id: linha['id'] as String,
    provedor: linha['provedor'] as String,
    codigoAbastecimento: linha['codigo_abastecimento'] as String?,
    dataAbastecimento: linha['data_abastecimento'] as String?,
    placa: linha['placa'] as String?,
    motoristaNome: linha['motorista_nome'] as String?,
    hodometro: (linha['hodometro'] as num?)?.toDouble(),
    produto: linha['produto'] as String?,
    litros: (linha['litros'] as num?)?.toDouble(),
    precoLitro: (linha['preco_litro'] as num?)?.toDouble(),
    valorTotal: (linha['valor_total'] as num?)?.toDouble(),
    empresaClienteId: empresaClienteId,
    nomeCliente: nomeCliente,
    faturaPostoId: linha['fatura_posto_id'] as String?,
  );

  if (empresaPostoId == null) {
    return AjusteAbastecimentoDetalhe(abastecimento: abastecimento, rodadas: const []);
  }

  final colunaId = abastecimento.identificadorTipo == 'profrotas' ? 'abastecimento_id' : 'abastecimento_externo_id';
  final idNumerico = int.tryParse(abastecimento.id);

  Map<String, dynamic>? ajusteRaw;
  if (idNumerico != null) {
    ajusteRaw = await supabase
        .from('ajustes_abastecimentos')
        .select('id, status')
        .eq(colunaId, idNumerico)
        .eq('empresa_posto_id', empresaPostoId)
        .inFilter('status', ['pendente_cliente', 'pendente_posto'])
        .maybeSingle();
  }

  if (ajusteRaw == null) {
    return AjusteAbastecimentoDetalhe(abastecimento: abastecimento, rodadas: const []);
  }

  final ajusteAberto = AjusteAberto(id: ajusteRaw['id'] as String, status: ajusteRaw['status'] as String);

  final rodadasRaw = await supabase
      .from('ajustes_abastecimentos_rodadas')
      .select(
        'numero_rodada, autor, data_abastecimento, hodometro, item_nome, item_quantidade, item_valor_unitario, item_valor_total, motivo, decisao, criado_em',
      )
      .eq('ajuste_id', ajusteAberto.id)
      .order('numero_rodada', ascending: true);

  return AjusteAbastecimentoDetalhe(
    abastecimento: abastecimento,
    ajusteAberto: ajusteAberto,
    rodadas: rodadasRaw.map((m) => RodadaAjuste.fromMap(m)).toList(),
  );
});
