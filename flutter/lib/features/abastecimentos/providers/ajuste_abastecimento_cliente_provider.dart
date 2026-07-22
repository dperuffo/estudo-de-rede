import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../posto/providers/ajuste_abastecimento_provider.dart'
    show AbastecimentoParaAjuste, RodadaAjuste, AjusteAberto, AjusteAbastecimentoDetalhe;

// Fase FLT-3 — mesmo detalhe+ajuste de abastecimento da Fase FLT-2
// (ajuste_abastecimento_provider.dart), modelado de perto pro lado
// cliente: reaproveita as MESMAS classes de dados (AbastecimentoParaAjuste/
// RodadaAjuste/AjusteAberto/AjusteAbastecimentoDetalhe — nenhuma delas tem
// nada específico de posto), só troca o filtro (`empresa_cliente_id` em
// vez de `empresa_posto_id`) e o "meu turno" (`pendente_cliente` em vez de
// `pendente_posto`). `AjusteAbastecimentoDetalhe.minhaVezDeResponder` da
// classe original só cobre o lado posto — por isso este provider expõe o
// status calculado à parte (`minhaVezDeResponderCliente` abaixo), a tela
// usa essa função em vez do getter da classe.
bool minhaVezDeResponderCliente(AjusteAbastecimentoDetalhe d) => d.ajusteAberto?.status == 'pendente_cliente';

final ajusteAbastecimentoClienteProvider =
    FutureProvider.autoDispose.family<AjusteAbastecimentoDetalhe, String>((ref, chave) async {
  final partes = chave.split(':');
  final provedor = partes.first;
  final idTexto = partes.sublist(1).join(':');

  final sessao = await ref.watch(sessaoProvider.future);
  final empresaClienteId = sessao.empresaId;
  final supabase = SupabaseService.client;

  final linha = await supabase
      .from('abastecimentos_unificado')
      .select(
        'id, provedor, codigo_abastecimento, data_abastecimento, placa, motorista_nome, hodometro, produto, litros, preco_litro, valor_total, empresa_id, posto_nome, posto_cnpj, fatura_posto_id',
      )
      .eq('id', idTexto)
      .eq('provedor', provedor)
      .maybeSingle();

  if (linha == null) {
    return const AjusteAbastecimentoDetalhe(abastecimento: null, rodadas: []);
  }

  // Resolve o id da empresa do POSTO a partir do CNPJ (a view só tem
  // posto_cnpj, texto solto) — RPC SECURITY DEFINER, mesma usada na web
  // (resolver_empresa_por_cnpj_segmento), pra não depender da RLS de
  // `empresas` (o cliente nunca é "membro" do posto).
  String? empresaPostoId;
  final postoCnpj = linha['posto_cnpj'] as String?;
  if (postoCnpj != null && postoCnpj.isNotEmpty) {
    empresaPostoId = await supabase.rpc('resolver_empresa_por_cnpj_segmento', params: {
      'p_cnpj': postoCnpj,
      'p_segmento': 'Revenda',
    }) as String?;
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
    empresaClienteId: linha['empresa_id'] as String?,
    // Aqui "nomeCliente" (nome da OUTRA parte na tela genérica) vira o
    // nome do POSTO — já vem pronto na view (posto_nome), sem precisar de
    // RPC extra pra exibição (só precisa da RPC acima pro id, não pro nome).
    nomeCliente: linha['posto_nome'] as String?,
    empresaPostoId: empresaPostoId,
    faturaPostoId: linha['fatura_posto_id'] as String?,
  );

  if (empresaClienteId == null) {
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
        .eq('empresa_cliente_id', empresaClienteId)
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
