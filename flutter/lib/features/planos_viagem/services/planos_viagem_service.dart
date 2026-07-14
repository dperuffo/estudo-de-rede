import '../../../core/services/supabase_service.dart';
import '../providers/planos_viagem_provider.dart';

// Fase FLT-3 — porta de criarPlanoViagem/atualizarPlanoViagem/
// excluirPlanoViagem/revisarCombustivelRealAcao (planos-viagem/actions.ts).
// Os campos "calculados" (custo de combustível/diárias/manutenção/total)
// são recalculados aqui, a partir dos valores brutos — nunca confiamos só
// no que a tela mostrou, mesmo espírito de montarPayload() na web.
class PlanosViagemService {
  final _supabase = SupabaseService.client;

  Map<String, dynamic> _payload({
    required String nome,
    required String status,
    String? placa,
    String? motoristaId,
    String? rotogramaId,
    String? centroCustoId,
    String? dataSaida,
    String? retornoPrevisto,
    required double kmEstimado,
    required double consumoKmL,
    required double precoCombustivel,
    required int nDiarias,
    required double valorRefeicaoDia,
    required double valorPernoiteDia,
    required double valorBanhoDia,
    required double valorLavagemDia,
    required double custoManutencaoKm,
    required double receitaViagem,
    double? custoTotalReal,
    String? observacoes,
    required double pedagiosTotal,
  }) {
    final custoCombustivelEstimado = consumoKmL > 0 ? (kmEstimado / consumoKmL) * precoCombustivel : 0.0;
    final custoDiarias = nDiarias * (valorRefeicaoDia + valorPernoiteDia + valorBanhoDia + valorLavagemDia);
    final custoManutencaoEstimado = kmEstimado * custoManutencaoKm;
    final custoTotalEstimado = custoCombustivelEstimado + pedagiosTotal + custoDiarias + custoManutencaoEstimado;

    return {
      'nome': nome.trim(),
      'status': status,
      'placa': _ouNull(placa),
      'motorista_id': _ouNull(motoristaId),
      'rotograma_id': _ouNull(rotogramaId),
      'centro_custo_id': _ouNull(centroCustoId),
      'data_saida': _ouNull(dataSaida),
      'retorno_previsto': _ouNull(retornoPrevisto),
      'km_estimado': kmEstimado,
      'consumo_km_l': consumoKmL,
      'preco_combustivel': precoCombustivel,
      'custo_combustivel_estimado': custoCombustivelEstimado,
      'n_diarias': nDiarias,
      'valor_refeicao_dia': valorRefeicaoDia,
      'valor_pernoite_dia': valorPernoiteDia,
      'valor_banho_dia': valorBanhoDia,
      'valor_lavagem_dia': valorLavagemDia,
      'custo_diarias': custoDiarias,
      'custo_manutencao_km': custoManutencaoKm,
      'custo_manutencao_estimado': custoManutencaoEstimado,
      'receita_viagem': receitaViagem,
      'pedagios_total': pedagiosTotal,
      'custo_total_estimado': custoTotalEstimado,
      'custo_total_real': custoTotalReal,
      'observacoes': _ouNull(observacoes),
    };
  }

  Future<String> criar({
    required String empresaId,
    required String criadoPor,
    required String nome,
    required String status,
    String? placa,
    String? motoristaId,
    String? rotogramaId,
    String? centroCustoId,
    String? dataSaida,
    String? retornoPrevisto,
    required double kmEstimado,
    required double consumoKmL,
    required double precoCombustivel,
    required int nDiarias,
    required double valorRefeicaoDia,
    required double valorPernoiteDia,
    required double valorBanhoDia,
    required double valorLavagemDia,
    required double custoManutencaoKm,
    required double receitaViagem,
    double? custoTotalReal,
    String? observacoes,
    required List<Pedagio> pedagios,
  }) async {
    if (nome.trim().isEmpty) {
      throw Exception('O nome do plano é obrigatório.');
    }
    final pedagiosValidos = pedagios.where((p) => p.pracaNome.trim().isNotEmpty).toList();
    final pedagiosTotal = pedagiosValidos.fold<double>(0, (s, p) => s + p.valor);

    final payload = _payload(
      nome: nome,
      status: status,
      placa: placa,
      motoristaId: motoristaId,
      rotogramaId: rotogramaId,
      centroCustoId: centroCustoId,
      dataSaida: dataSaida,
      retornoPrevisto: retornoPrevisto,
      kmEstimado: kmEstimado,
      consumoKmL: consumoKmL,
      precoCombustivel: precoCombustivel,
      nDiarias: nDiarias,
      valorRefeicaoDia: valorRefeicaoDia,
      valorPernoiteDia: valorPernoiteDia,
      valorBanhoDia: valorBanhoDia,
      valorLavagemDia: valorLavagemDia,
      custoManutencaoKm: custoManutencaoKm,
      receitaViagem: receitaViagem,
      custoTotalReal: custoTotalReal,
      observacoes: observacoes,
      pedagiosTotal: pedagiosTotal,
    );

    final row = await _supabase
        .from('planos_viagem')
        .insert({...payload, 'empresa_id': empresaId, 'criado_por': criadoPor})
        .select('id')
        .single();
    final id = row['id'] as String;

    if (pedagiosValidos.isNotEmpty) {
      await _supabase.from('planos_viagem_pedagios').insert([
        for (var i = 0; i < pedagiosValidos.length; i++)
          {'plano_viagem_id': id, 'praca_nome': pedagiosValidos[i].pracaNome, 'valor': pedagiosValidos[i].valor, 'ordem': i},
      ]);
    }
    return id;
  }

  Future<void> atualizar({
    required String id,
    required String nome,
    required String status,
    String? placa,
    String? motoristaId,
    String? rotogramaId,
    String? centroCustoId,
    String? dataSaida,
    String? retornoPrevisto,
    required double kmEstimado,
    required double consumoKmL,
    required double precoCombustivel,
    required int nDiarias,
    required double valorRefeicaoDia,
    required double valorPernoiteDia,
    required double valorBanhoDia,
    required double valorLavagemDia,
    required double custoManutencaoKm,
    required double receitaViagem,
    double? custoTotalReal,
    String? observacoes,
    required List<Pedagio> pedagios,
  }) async {
    if (nome.trim().isEmpty) {
      throw Exception('O nome do plano é obrigatório.');
    }
    final pedagiosValidos = pedagios.where((p) => p.pracaNome.trim().isNotEmpty).toList();
    final pedagiosTotal = pedagiosValidos.fold<double>(0, (s, p) => s + p.valor);

    final payload = _payload(
      nome: nome,
      status: status,
      placa: placa,
      motoristaId: motoristaId,
      rotogramaId: rotogramaId,
      centroCustoId: centroCustoId,
      dataSaida: dataSaida,
      retornoPrevisto: retornoPrevisto,
      kmEstimado: kmEstimado,
      consumoKmL: consumoKmL,
      precoCombustivel: precoCombustivel,
      nDiarias: nDiarias,
      valorRefeicaoDia: valorRefeicaoDia,
      valorPernoiteDia: valorPernoiteDia,
      valorBanhoDia: valorBanhoDia,
      valorLavagemDia: valorLavagemDia,
      custoManutencaoKm: custoManutencaoKm,
      receitaViagem: receitaViagem,
      custoTotalReal: custoTotalReal,
      observacoes: observacoes,
      pedagiosTotal: pedagiosTotal,
    );

    await _supabase
        .from('planos_viagem')
        .update({...payload, 'atualizado_em': DateTime.now().toIso8601String()})
        .eq('id', id);

    // Substitui a lista inteira de pedágios — mais simples que diff/merge
    // linha a linha, mesma decisão da web (a lista costuma ter poucos itens).
    await _supabase.from('planos_viagem_pedagios').delete().eq('plano_viagem_id', id);
    if (pedagiosValidos.isNotEmpty) {
      await _supabase.from('planos_viagem_pedagios').insert([
        for (var i = 0; i < pedagiosValidos.length; i++)
          {'plano_viagem_id': id, 'praca_nome': pedagiosValidos[i].pracaNome, 'valor': pedagiosValidos[i].valor, 'ordem': i},
      ]);
    }
  }

  Future<void> excluir(String id) async {
    await _supabase.from('planos_viagem').delete().eq('id', id);
  }

  // "Revisar" combustível real: soma litros/valor dos abastecimentos de
  // verdade daquela placa, entre a data de saída e o retorno previsto (ou
  // hoje, se ainda não tiver retorno definido) — mesma RPC da web.
  Future<({double litros, double valor})> revisarCombustivelReal({
    required String planoId,
    required String empresaId,
    required String placa,
    required String dataSaida,
    String? retornoPrevisto,
  }) async {
    final dataFim = retornoPrevisto ?? DateTime.now().toIso8601String().substring(0, 10);
    final resultado = await _supabase.rpc('combustivel_real_periodo', params: {
      'p_empresa_id': empresaId,
      'p_placa': placa,
      'p_data_inicio': dataSaida,
      'p_data_fim': dataFim,
    }).single();

    final litros = ((resultado['litros'] as num?) ?? 0).toDouble();
    final valor = ((resultado['valor_total'] as num?) ?? 0).toDouble();

    await _supabase.from('planos_viagem').update({
      'combustivel_real_litros': litros,
      'custo_combustivel_real': valor,
      'combustivel_real_revisado_em': DateTime.now().toIso8601String(),
    }).eq('id', planoId);

    return (litros: litros, valor: valor);
  }

  String? _ouNull(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
}
