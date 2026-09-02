import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-Faturas-Frete (02/09/2026, pedido do Daniel: "equalizar o PWA
// Cliente com as funcionalidades construídas para a web cliente") — porta
// de faturas-fretes/gerar/page.tsx + [id]/page.tsx + actions.ts. Sem RPC
// própria pra gerar fatura — mesma orquestração da web via inserts/updates
// diretos (RLS tenant_all cobre autorização). Sem geração de PDF/boleto
// nesta v1 mobile (mesmo corte já aplicado em notas_fiscais_provider.dart
// — PDF client-side fica pra depois).
class TomadorComPendentes {
  final String cnpj;
  final String? nome;
  final int quantidadeCtes;
  final double valorTotal;
  final String dataMin;
  final String dataMax;

  const TomadorComPendentes({
    required this.cnpj,
    required this.nome,
    required this.quantidadeCtes,
    required this.valorTotal,
    required this.dataMin,
    required this.dataMax,
  });
}

class FaturaFrete {
  final String id;
  final String tomadorCnpj;
  final String? tomadorNome;
  final int numeroFatura;
  final String periodoInicio;
  final String periodoFim;
  final String vencimento;
  final double valorTotal;
  final int quantidadeCtes;
  final String status; // aberta | paga | cancelada
  final String? pagoEm;
  final String? observacoes;
  final String criadoEm;

  const FaturaFrete({
    required this.id,
    required this.tomadorCnpj,
    required this.tomadorNome,
    required this.numeroFatura,
    required this.periodoInicio,
    required this.periodoFim,
    required this.vencimento,
    required this.valorTotal,
    required this.quantidadeCtes,
    required this.status,
    required this.pagoEm,
    required this.observacoes,
    required this.criadoEm,
  });

  factory FaturaFrete.fromMap(Map<String, dynamic> m) => FaturaFrete(
        id: m['id'] as String,
        tomadorCnpj: m['tomador_cnpj'] as String,
        tomadorNome: m['tomador_nome'] as String?,
        numeroFatura: (m['numero_fatura'] as num?)?.toInt() ?? 0,
        periodoInicio: m['periodo_inicio'] as String,
        periodoFim: m['periodo_fim'] as String,
        vencimento: m['vencimento'] as String,
        valorTotal: (m['valor_total'] as num?)?.toDouble() ?? 0,
        quantidadeCtes: (m['quantidade_ctes'] as num?)?.toInt() ?? 0,
        status: m['status'] as String? ?? 'aberta',
        pagoEm: m['pago_em'] as String?,
        observacoes: m['observacoes'] as String?,
        criadoEm: m['criado_em'] as String? ?? '',
      );
}

class ItemFaturaFrete {
  final String freteCteId;
  final double valorPrestacao;
  final String? numeroCte;
  final String? dataEmissao;
  final String? chaveAcesso;

  const ItemFaturaFrete({
    required this.freteCteId,
    required this.valorPrestacao,
    required this.numeroCte,
    required this.dataEmissao,
    required this.chaveAcesso,
  });
}

class FaturasFretesService {
  final _supabase = SupabaseService.client;

  Future<List<TomadorComPendentes>> buscarTomadoresComPendentes(
      String empresaId) async {
    final fretes = await _supabase
        .from('fretes')
        .select('id')
        .eq('empresa_id', empresaId);
    final freteIds = fretes.map((m) => m['id'] as String).toList();
    if (freteIds.isEmpty) return [];

    final ctes = await _supabase
        .from('fretes_cte')
        .select('tomador_cnpj, tomador_nome, valor_prestacao, data_emissao')
        .inFilter('frete_id', freteIds)
        .eq('status', 'autorizado')
        .isFilter('fatura_frete_id', null);

    final porTomador = <String, List<Map<String, dynamic>>>{};
    for (final m in ctes) {
      final cnpj = m['tomador_cnpj'] as String?;
      if (cnpj == null || cnpj.isEmpty) continue;
      porTomador.putIfAbsent(cnpj, () => []).add(m);
    }

    final resultado = <TomadorComPendentes>[];
    for (final entry in porTomador.entries) {
      final linhas = entry.value;
      final valorTotal = linhas.fold<double>(
          0, (s, m) => s + ((m['valor_prestacao'] as num?)?.toDouble() ?? 0));
      final datas = linhas
          .map((m) => m['data_emissao'] as String?)
          .whereType<String>()
          .toList()
        ..sort();
      resultado.add(TomadorComPendentes(
        cnpj: entry.key,
        nome: linhas.first['tomador_nome'] as String?,
        quantidadeCtes: linhas.length,
        valorTotal: valorTotal,
        dataMin: datas.isNotEmpty ? datas.first : '',
        dataMax: datas.isNotEmpty ? datas.last : '',
      ));
    }
    resultado.sort((a, b) => (a.nome ?? a.cnpj).compareTo(b.nome ?? b.cnpj));
    return resultado;
  }

  Future<({String? id, String? erro})> gerarFatura({
    required String empresaId,
    required String tomadorCnpj,
    String? tomadorNome,
    required String periodoInicio,
    required String periodoFim,
    required String vencimento,
  }) async {
    if (vencimento.trim().isEmpty) {
      return (id: null, erro: 'Informe o vencimento da fatura.');
    }
    try {
      final fretes = await _supabase
          .from('fretes')
          .select('id')
          .eq('empresa_id', empresaId);
      final freteIds = fretes.map((m) => m['id'] as String).toList();
      if (freteIds.isEmpty) {
        return (id: null, erro: 'Nenhum frete encontrado para esta empresa.');
      }

      final ctes = await _supabase
          .from('fretes_cte')
          .select('id, frete_id, valor_prestacao, data_emissao')
          .inFilter('frete_id', freteIds)
          .eq('status', 'autorizado')
          .eq('tomador_cnpj', tomadorCnpj)
          .isFilter('fatura_frete_id', null)
          .gte('data_emissao', periodoInicio)
          .lte('data_emissao', periodoFim);

      if (ctes.isEmpty) {
        return (id: null, erro: 'Nenhum CT-e elegível encontrado nesse período.');
      }

      final valorTotal = ctes.fold<double>(
          0, (s, m) => s + ((m['valor_prestacao'] as num?)?.toDouble() ?? 0));

      final fatura = await _supabase
          .from('faturas_fretes')
          .insert({
            'empresa_id': empresaId,
            'tomador_cnpj': tomadorCnpj,
            'tomador_nome': tomadorNome,
            'periodo_inicio': periodoInicio,
            'periodo_fim': periodoFim,
            'vencimento': vencimento,
            'valor_total': valorTotal,
            'quantidade_ctes': ctes.length,
            'status': 'aberta',
            'criado_por': AuthService().emailAtual,
          })
          .select('id')
          .single();
      final faturaId = fatura['id'] as String;

      await _supabase.from('faturas_fretes_itens').insert(ctes
          .map((c) => {
                'fatura_frete_id': faturaId,
                'frete_cte_id': c['id'],
                'frete_id': c['frete_id'],
                'valor_prestacao': c['valor_prestacao'],
              })
          .toList());

      for (final c in ctes) {
        await _supabase
            .from('fretes_cte')
            .update({'fatura_frete_id': faturaId}).eq('id', c['id']);
      }

      await _supabase.from('contas_receber').insert({
        'empresa_id': empresaId,
        'origem': 'fatura_frete',
        'referencia_id': faturaId,
        'devedor_nome': tomadorNome,
        'devedor_cnpj': tomadorCnpj,
        'descricao': 'Fatura de frete $periodoInicio a $periodoFim',
        'valor_original': valorTotal,
        'vencimento': vencimento,
        'criado_por': AuthService().emailAtual,
      });

      return (id: faturaId, erro: null);
    } catch (e) {
      return (id: null, erro: 'Não foi possível gerar a fatura: $e');
    }
  }

  Future<List<FaturaFrete>> buscar(String empresaId) async {
    final rows = await _supabase
        .from('faturas_fretes')
        .select(
          'id, tomador_cnpj, tomador_nome, numero_fatura, periodo_inicio, periodo_fim, vencimento, valor_total, quantidade_ctes, status, pago_em, observacoes, criado_em',
        )
        .eq('empresa_id', empresaId)
        .order('criado_em', ascending: false)
        .limit(100);
    return rows.map((m) => FaturaFrete.fromMap(m)).toList();
  }

  Future<FaturaFrete?> buscarDetalhe(String id) async {
    final m = await _supabase
        .from('faturas_fretes')
        .select(
          'id, tomador_cnpj, tomador_nome, numero_fatura, periodo_inicio, periodo_fim, vencimento, valor_total, quantidade_ctes, status, pago_em, observacoes, criado_em',
        )
        .eq('id', id)
        .maybeSingle();
    if (m == null) return null;
    return FaturaFrete.fromMap(m);
  }

  Future<List<ItemFaturaFrete>> buscarItens(String faturaId) async {
    final itens = await _supabase
        .from('faturas_fretes_itens')
        .select('frete_cte_id, valor_prestacao')
        .eq('fatura_frete_id', faturaId);
    final cteIds = itens.map((m) => m['frete_cte_id'] as String).toList();
    if (cteIds.isEmpty) return [];
    final ctes = await _supabase
        .from('fretes_cte')
        .select('id, numero_cte, data_emissao, chave_acesso')
        .inFilter('id', cteIds);
    final cteMap = {for (final c in ctes) c['id'] as String: c};
    return itens.map((m) {
      final cteId = m['frete_cte_id'] as String;
      final cte = cteMap[cteId];
      return ItemFaturaFrete(
        freteCteId: cteId,
        valorPrestacao: (m['valor_prestacao'] as num?)?.toDouble() ?? 0,
        numeroCte: cte?['numero_cte'] as String?,
        dataEmissao: cte?['data_emissao'] as String?,
        chaveAcesso: cte?['chave_acesso'] as String?,
      );
    }).toList();
  }

  Future<Map<String, dynamic>?> buscarContaReceberDaFatura(
      String faturaId) async {
    return await _supabase
        .from('contas_receber')
        .select('id, valor_original, valor_pago, status')
        .eq('origem', 'fatura_frete')
        .eq('referencia_id', faturaId)
        .maybeSingle();
  }

  Future<String?> cancelar(String faturaId) async {
    try {
      final atualizado = await _supabase
          .from('faturas_fretes')
          .update({
            'status': 'cancelada',
            'atualizado_em': DateTime.now().toUtc().toIso8601String(),
            'atualizado_por': AuthService().emailAtual,
          })
          .eq('id', faturaId)
          .eq('status', 'aberta')
          .select('id')
          .maybeSingle();
      if (atualizado == null) {
        return 'Só é possível cancelar faturas com status "aberta".';
      }
      await _supabase
          .from('fretes_cte')
          .update({'fatura_frete_id': null}).eq('fatura_frete_id', faturaId);
      final conta = await buscarContaReceberDaFatura(faturaId);
      if (conta != null) {
        await _supabase.rpc('cancelar_conta_receber',
            params: {'p_conta_id': conta['id']});
      }
      return null;
    } catch (e) {
      return 'Não foi possível cancelar: $e';
    }
  }

  Future<String?> marcarComoPaga(String faturaId) async {
    try {
      final conta = await buscarContaReceberDaFatura(faturaId);
      if (conta == null) {
        return 'Título financeiro desta fatura não encontrado.';
      }
      final valorOriginal = (conta['valor_original'] as num).toDouble();
      final valorPago = (conta['valor_pago'] as num?)?.toDouble() ?? 0;
      final pendente = valorOriginal - valorPago;
      if (pendente <= 0) return null;
      await _supabase.rpc('baixar_conta_receber', params: {
        'p_conta_id': conta['id'],
        'p_valor': pendente,
        'p_forma': 'manual',
        'p_gateway_ref': null,
        'p_observacao': null,
      });
      return null;
    } catch (e) {
      return 'Não foi possível marcar como paga: $e';
    }
  }
}
