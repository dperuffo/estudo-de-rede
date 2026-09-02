import '../../../core/services/supabase_service.dart';

// Fase FLT-Apuração-Tributária (02/09/2026, pedido do Daniel: "equalizar o
// PWA Cliente com as funcionalidades construídas para a web cliente") —
// porta de apuracao-tributaria/page.tsx + actions.ts. Sem cálculo próprio:
// o valor do crédito (v_icms_mono_ret) já vem pronto do XML da NF-e do
// posto (grupo ICMS61, tributação monofásica — LC 192/2022); este app só
// agrega e exibe, igual à web. Mesmas 3 simplificações assumidas na web
// (comentário lá, replicado aqui): soma agregada sem distinguir
// diesel/GLP; UF usa a do posto emitente (não a de início do transporte);
// elegibilidade é autodeclarada.
class NotaFiscalTributaria {
  final String id;
  final String numeroNf;
  final String dataEmissao;
  final String nomeEmitente;
  final String? produtoNomeXml;
  final String? produtoDescricaoAnp;
  final double quantidade;
  final double valorTotal;
  final String? cstIcms;
  final String? ufEmitente;
  final double? vIcmsMonoRet;

  const NotaFiscalTributaria({
    required this.id,
    required this.numeroNf,
    required this.dataEmissao,
    required this.nomeEmitente,
    required this.produtoNomeXml,
    required this.produtoDescricaoAnp,
    required this.quantidade,
    required this.valorTotal,
    required this.cstIcms,
    required this.ufEmitente,
    required this.vIcmsMonoRet,
  });

  factory NotaFiscalTributaria.fromMap(Map<String, dynamic> m) =>
      NotaFiscalTributaria(
        id: m['id'] as String,
        numeroNf: '${m['numero_nf']}',
        dataEmissao: m['data_emissao'] as String,
        nomeEmitente: m['nome_emitente'] as String? ?? '',
        produtoNomeXml: m['produto_nome_xml'] as String?,
        produtoDescricaoAnp: m['produto_descricao_anp'] as String?,
        quantidade: (m['quantidade'] as num?)?.toDouble() ?? 0,
        valorTotal: (m['valor_total'] as num?)?.toDouble() ?? 0,
        cstIcms: m['cst_icms'] as String?,
        ufEmitente: m['uf_emitente'] as String?,
        vIcmsMonoRet: (m['v_icms_mono_ret'] as num?)?.toDouble(),
      );
}

class DadosFiscaisEmpresa {
  final String? segmento;
  final String? uf;
  final String? regimeTributario; // "normal" | "simples_nacional" | null
  final bool? elegivelCreditoIcmsCombustivel;

  const DadosFiscaisEmpresa({
    required this.segmento,
    required this.uf,
    required this.regimeTributario,
    required this.elegivelCreditoIcmsCombustivel,
  });

  bool get cadastroIncompleto =>
      regimeTributario == null || elegivelCreditoIcmsCombustivel == null;

  bool get podeCreditar =>
      regimeTributario == 'normal' && elegivelCreditoIcmsCombustivel == true;

  factory DadosFiscaisEmpresa.fromMap(Map<String, dynamic> m) =>
      DadosFiscaisEmpresa(
        segmento: m['segmento'] as String?,
        uf: m['uf'] as String?,
        regimeTributario: m['regime_tributario'] as String?,
        elegivelCreditoIcmsCombustivel:
            m['elegivel_credito_icms_combustivel'] as bool?,
      );
}

class ApuracaoTributariaService {
  final _supabase = SupabaseService.client;

  Future<DadosFiscaisEmpresa> buscarDadosFiscais(String empresaId) async {
    final m = await _supabase
        .from('empresas')
        .select('segmento, uf, regime_tributario, elegivel_credito_icms_combustivel')
        .eq('id', empresaId)
        .single();
    return DadosFiscaisEmpresa.fromMap(m);
  }

  Future<List<NotaFiscalTributaria>> buscarNotasDoPeriodo({
    required String empresaId,
    required DateTime inicio,
    required DateTime fimExclusivo,
  }) async {
    final rows = await _supabase
        .from('notas_fiscais_abastecimento')
        .select(
          'id, numero_nf, data_emissao, nome_emitente, produto_nome_xml, produto_descricao_anp, quantidade, valor_total, cst_icms, uf_emitente, v_icms_mono_ret',
        )
        .eq('empresa_cliente_id', empresaId)
        .gte('data_emissao', inicio.toIso8601String().substring(0, 10))
        .lt('data_emissao', fimExclusivo.toIso8601String().substring(0, 10))
        .order('data_emissao', ascending: false);
    return rows.map((m) => NotaFiscalTributaria.fromMap(m)).toList();
  }

  Future<String?> atualizarRegimeTributario({
    required String empresaId,
    required String regimeTributario,
    required bool elegivel,
  }) async {
    if (regimeTributario != 'normal' && regimeTributario != 'simples_nacional') {
      return 'Regime tributário inválido.';
    }
    try {
      await _supabase.from('empresas').update({
        'regime_tributario': regimeTributario,
        'elegivel_credito_icms_combustivel': elegivel,
      }).eq('id', empresaId);
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }
}
