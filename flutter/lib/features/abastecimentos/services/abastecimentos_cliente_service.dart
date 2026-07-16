import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../posto/services/abastecimentos_posto_service.dart' show RegistroAbastecimentoPosto, nomeProvedor;

// Fase FLT-3 — Abastecimentos (cliente), porta de abastecimentos/page.tsx
// (lado cliente — a web desvia pro AbastecimentosPosto quando a empresa é
// segmento "Revenda", já coberto pela Fase FLT-2). Modelado de perto em
// AbastecimentosPostoService (mesma view `abastecimentos_unificado`,
// mesmo formato de resultado — por isso reaproveita a classe
// RegistroAbastecimentoPosto direto em vez de duplicar), só que o filtro
// principal aqui é `empresa_id` (o consumo desta frota) em vez de
// `posto_cnpj` (o que este posto forneceu).
//
// Fora do escopo desta v1 (ver README): paginação de verdade (só traz os N
// mais recentes), importação por planilha (`/abastecimentos/importar`) e o
// badge "Rejeitada + motivo" de NF-e — a tabela `notas_fiscais_pendencias`
// só tem RLS de leitura pra quem é `empresa_posto_id` (conferido direto no
// banco antes de portar), o cliente nunca teria acesso a essas linhas; só
// mostra "Emitida" (via notas_fiscais_abastecimento, que tem
// `empresa_cliente_id` e portanto É legível) ou "Pendente" (sem
// diferenciar rejeitada).

class FiltrosAbastecimentosCliente {
  final String? combustivel;
  final String? provedor;
  final String? q;
  final String? de;
  final String? ate;
  final bool somenteAjustePendente;
  const FiltrosAbastecimentosCliente({
    this.combustivel,
    this.provedor,
    this.q,
    this.de,
    this.ate,
    this.somenteAjustePendente = false,
  });
}

class ResultadoAbastecimentosCliente {
  final List<RegistroAbastecimentoPosto> registros;
  final int total;
  final double volumeTotal;
  final double receitaTotal;
  final List<String> provedoresOpcoes;
  final Map<String, String?> notaPorAbastecimento;
  final Set<String> comAjustePendente;

  const ResultadoAbastecimentosCliente({
    required this.registros,
    required this.total,
    required this.volumeTotal,
    required this.receitaTotal,
    required this.provedoresOpcoes,
    required this.notaPorAbastecimento,
    required this.comAjustePendente,
  });

  static const vazio = ResultadoAbastecimentosCliente(
    registros: [],
    total: 0,
    volumeTotal: 0,
    receitaTotal: 0,
    provedoresOpcoes: [],
    notaPorAbastecimento: {},
    comAjustePendente: {},
  );
}

class AbastecimentosClienteService {
  final _supabase = SupabaseService.client;

  // Porta de criarAbastecimento (abastecimentos/actions.ts) — lançamento
  // manual pra clientes sem integração automática com meio de pagamento.
  // Grava em profrotas_abastecimentos com um "identificador" negativo
  // (sequência própria via RPC nextval_identificador_manual), igual à web,
  // pra nunca colidir com IDs reais vindos da integração.
  Future<String?> criarManual({
    required String empresaId,
    required String empresaNome,
    required String empresaCnpj,
    String? dataAbastecimento,
    String? placa,
    String? motoristaNome,
    double? hodometro,
    String? produto,
    double? litros,
    double? precoUnitario,
    double? valorTotal,
    String? postoNome,
    String? postoMunicipio,
    String? postoUf,
  }) async {
    try {
      final seq = await _supabase.rpc('nextval_identificador_manual');
      if (seq == null) return 'Não foi possível gerar o identificador do lançamento manual.';
      final identificador = (seq as num).toInt();

      await _supabase.from('profrotas_abastecimentos').insert({
        'data_abastecimento': dataAbastecimento,
        'hodometro': hodometro,
        'veiculo_placa': placa,
        'motorista_nome': motoristaNome,
        'pv_razao_social': postoNome,
        'pv_municipio': postoMunicipio,
        'pv_uf': postoUf,
        'item_nome': produto,
        'item_quantidade': litros,
        'item_valor_unitario': precoUnitario,
        'item_valor_total': valorTotal,
        'cnpj_frota': empresaCnpj,
        'frota_cnpj': empresaCnpj,
        'frota_razao_social': empresaNome,
        'empresa_id': empresaId,
        'identificador': identificador,
        'sync_key': 'manual-$identificador',
        'abastecimento_estornado': 0,
        'status_autorizacao': 1,
        'item_tipo': 1,
      });
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  Future<ResultadoAbastecimentosCliente> buscar({
    required String empresaId,
    FiltrosAbastecimentosCliente filtros = const FiltrosAbastecimentosCliente(),
    int limite = 50,
  }) async {
    Set<int>? idsComAjusteAbertoProfrotas;
    Set<int>? idsComAjusteAbertoExterno;
    if (filtros.somenteAjustePendente) {
      final ajustesAbertos = await _supabase
          .from('ajustes_abastecimentos')
          .select('abastecimento_id, abastecimento_externo_id')
          .eq('empresa_cliente_id', empresaId)
          .inFilter('status', ['pendente_cliente', 'pendente_posto']);
      idsComAjusteAbertoProfrotas = {
        for (final a in ajustesAbertos)
          if (a['abastecimento_id'] != null) a['abastecimento_id'] as int,
      };
      idsComAjusteAbertoExterno = {
        for (final a in ajustesAbertos)
          if (a['abastecimento_externo_id'] != null) a['abastecimento_externo_id'] as int,
      };
    }

    // Fase FLT-3 — achado real (Daniel, cliente de teste com 8,4k+
    // abastecimentos): as opções de "meio de pagamento" vinham de
    // .select('provedor').limit(20000), sujeito ao corte de 1.000 linhas
    // que o PostgREST aplica por padrão sem paginação (mesmo bug já
    // documentado e corrigido na Inteligência de Rede, Fase 6, do lado
    // web). Clientes com mais de 1.000 registros podiam não ver todos os
    // provedores na lista de filtro. Troca pra RPC agregada no banco
    // (indicadores_financeiros_por_provedor, já usada em Financeiro) —
    // sem limite de data, só pra descobrir todo provedor já usado por
    // este cliente.
    final provedoresRaw = await _supabase.rpc('indicadores_financeiros_por_provedor', params: {
      'p_empresa_id': empresaId,
      'p_data_inicio': '2000-01-01',
      'p_data_fim': DateTime.now().toIso8601String().substring(0, 10),
    }) as List;
    final provedoresOpcoes = <String>{
      for (final m in provedoresRaw)
        if ((m as Map<String, dynamic>)['provedor'] != null) m['provedor'] as String,
    }.toList()
      ..sort((a, b) => nomeProvedor(a).compareTo(nomeProvedor(b)));

    PostgrestFilterBuilder<T> aplicar<T>(PostgrestFilterBuilder<T> query) {
      var q = query.eq('empresa_id', empresaId);
      if (filtros.combustivel != null) q = q.eq('produto', filtros.combustivel!);
      if (filtros.provedor != null) q = q.eq('provedor', filtros.provedor!);
      final termo = filtros.q?.trim();
      if (termo != null && termo.isNotEmpty) {
        q = q.or(
          'placa.ilike.%$termo%,motorista_nome.ilike.%$termo%,posto_nome.ilike.%$termo%,codigo_abastecimento.ilike.%$termo%',
        );
      }
      if (filtros.de != null && filtros.de!.isNotEmpty) q = q.gte('data_abastecimento', filtros.de!);
      if (filtros.ate != null && filtros.ate!.isNotEmpty) {
        q = q.lte('data_abastecimento', '${filtros.ate}T23:59:59');
      }
      if (filtros.somenteAjustePendente) {
        final profrotasIds = (idsComAjusteAbertoProfrotas?.isNotEmpty ?? false)
            ? idsComAjusteAbertoProfrotas!.join(',')
            : '-1';
        final externoIds =
            (idsComAjusteAbertoExterno?.isNotEmpty ?? false) ? idsComAjusteAbertoExterno!.join(',') : '-1';
        q = q.or(
          'and(provedor.eq.profrotas,id.in.($profrotasIds)),and(provedor.neq.profrotas,id.in.($externoIds))',
        );
      }
      return q;
    }

    final contagemResp =
        await aplicar(_supabase.from('abastecimentos_unificado').select('id')).count(CountOption.exact);
    final total = contagemResp.count;

    // Fase FLT-3 — mesmo bug do corte de 1.000 linhas do PostgREST: Volume
    // e Valor total vinham de .select('litros, valor_total').limit(50000)
    // e soma em Dart, então clientes com mais de 1.000 abastecimentos
    // tinham esses indicadores calculados sobre uma fatia arbitrária dos
    // dados (quase sempre dominada pelo provedor histórico maior). Troca
    // pra RPC que soma direto no Postgres (abastecimentos_totais_filtrados,
    // criada no banco pra este fix), replicando os mesmos filtros desta
    // busca (combustível, provedor, texto livre, data, ajuste pendente).
    final totaisRaw = await _supabase.rpc('abastecimentos_totais_filtrados', params: {
      'p_empresa_id': empresaId,
      'p_q': (filtros.q?.trim().isEmpty ?? true) ? null : filtros.q!.trim(),
      'p_de': (filtros.de?.isEmpty ?? true) ? null : filtros.de,
      'p_ate': (filtros.ate?.isEmpty ?? true) ? null : filtros.ate,
      'p_provedor': filtros.provedor,
      'p_apenas_ajuste_pendente': filtros.somenteAjustePendente,
      'p_produto': filtros.combustivel,
    }) as List;
    final totaisLinha = totaisRaw.isNotEmpty ? totaisRaw.first as Map<String, dynamic> : null;
    final volumeTotal = (totaisLinha?['litros'] as num?)?.toDouble() ?? 0;
    final receitaTotal = (totaisLinha?['valor_total'] as num?)?.toDouble() ?? 0;

    final paginaRaw = await aplicar(_supabase.from('abastecimentos_unificado').select(
          'id, provedor, codigo_abastecimento, data_abastecimento, empresa_id, placa, motorista_nome, produto, litros, valor_total, posto_nome',
        ))
        .order('data_abastecimento', ascending: false)
        .limit(limite);
    final registros = paginaRaw.map((m) => RegistroAbastecimentoPosto.fromMap(m)).toList();

    final notaPorAbastecimento = <String, String?>{};
    final comAjustePendente = <String>{};

    if (registros.isNotEmpty) {
      final notasRaw = await _supabase
          .from('notas_fiscais_abastecimento')
          .select('abastecimento_id, abastecimento_externo_id, numero_nf')
          .eq('empresa_cliente_id', empresaId)
          .limit(20000);
      final registroPorIdExterno = <String, RegistroAbastecimentoPosto>{
        for (final r in registros)
          if (r.provedor != 'profrotas') r.id: r,
      };
      for (final n in notasRaw) {
        final idProfrotas = n['abastecimento_id'];
        final idExterno = n['abastecimento_externo_id'];
        final numero = n['numero_nf']?.toString();
        if (idProfrotas != null) notaPorAbastecimento.putIfAbsent('profrotas:$idProfrotas', () => numero);
        final registroExterno = idExterno != null ? registroPorIdExterno[idExterno.toString()] : null;
        if (registroExterno != null) notaPorAbastecimento.putIfAbsent(registroExterno.chave, () => numero);
      }

      final ajustesRaw = await _supabase
          .from('ajustes_abastecimentos')
          .select('abastecimento_id, abastecimento_externo_id')
          .eq('empresa_cliente_id', empresaId)
          .inFilter('status', ['pendente_cliente', 'pendente_posto']);
      for (final a in ajustesRaw) {
        final idProfrotas = a['abastecimento_id'];
        final idExterno = a['abastecimento_externo_id'];
        if (idProfrotas != null) comAjustePendente.add('profrotas:$idProfrotas');
        final registroExterno = idExterno != null ? registroPorIdExterno[idExterno.toString()] : null;
        if (registroExterno != null) comAjustePendente.add(registroExterno.chave);
      }
    }

    return ResultadoAbastecimentosCliente(
      registros: registros,
      total: total,
      volumeTotal: volumeTotal,
      receitaTotal: receitaTotal,
      provedoresOpcoes: provedoresOpcoes,
      notaPorAbastecimento: notaPorAbastecimento,
      comAjustePendente: comAjustePendente,
    );
  }
}
