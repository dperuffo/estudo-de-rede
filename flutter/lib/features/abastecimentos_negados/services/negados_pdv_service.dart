import '../../../core/services/supabase_service.dart';

// Fase 5 PDV (03/10/2026, pedido do Daniel) — porta de
// abastecimentos-negados/ (web): abastecimentos feitos no PDV de um posto
// que foram NEGADOS por regras do cliente. O gestor vê as regras impactadas
// e pode liberar (ou manter negado) enquanto o pedido está dentro da
// validade. Toda a regra (quem pode decidir, janela de validade,
// justificativa obrigatória) mora nas RPCs SECURITY DEFINER — aqui só
// chamamos e mostramos a mensagem que voltar.
class RegraImpactada {
  final String codigo;
  final String titulo;
  final String detalhe;

  const RegraImpactada({required this.codigo, required this.titulo, required this.detalhe});

  factory RegraImpactada.fromMap(Map<String, dynamic> m) => RegraImpactada(
        codigo: m['codigo'] as String? ?? '',
        titulo: m['titulo'] as String? ?? '',
        detalhe: m['detalhe'] as String? ?? '',
      );
}

class AbastecimentoNegadoPdv {
  final int id;
  final String codigo;
  final String? placa;
  final String? motoristaNome;
  final String? motoristaCpf;
  final String? combustivel;
  final num? litros;
  final num? valorCombustivel;
  final String? postoNome;
  final DateTime criadoEm;
  final DateTime expiraEm;
  final List<RegraImpactada> regras;
  // pendente | liberado | recusado | expirado
  final String situacao;
  final String? decididoPor;
  final DateTime? decididoEm;
  final String? justificativa;

  const AbastecimentoNegadoPdv({
    required this.id,
    required this.codigo,
    required this.placa,
    required this.motoristaNome,
    required this.motoristaCpf,
    required this.combustivel,
    required this.litros,
    required this.valorCombustivel,
    required this.postoNome,
    required this.criadoEm,
    required this.expiraEm,
    required this.regras,
    required this.situacao,
    required this.decididoPor,
    required this.decididoEm,
    required this.justificativa,
  });

  factory AbastecimentoNegadoPdv.fromMap(Map<String, dynamic> m) => AbastecimentoNegadoPdv(
        id: (m['id'] as num).toInt(),
        codigo: m['codigo_abastecimento'] as String? ?? '',
        placa: m['placa'] as String?,
        motoristaNome: m['motorista_nome'] as String?,
        motoristaCpf: m['motorista_cpf'] as String?,
        combustivel: m['combustivel'] as String?,
        litros: m['litros'] as num?,
        valorCombustivel: m['valor_total_combustivel'] as num?,
        postoNome: m['posto_nome'] as String?,
        criadoEm: DateTime.parse(m['criado_em'] as String).toLocal(),
        expiraEm: DateTime.parse(m['otp_expira_em'] as String).toLocal(),
        regras: ((m['regras_violadas'] as List?) ?? const [])
            .map((r) => RegraImpactada.fromMap(r as Map<String, dynamic>))
            .toList(),
        situacao: m['situacao'] as String? ?? 'expirado',
        decididoPor: m['liberacao_decidida_por'] as String?,
        decididoEm: m['liberacao_decidida_em'] == null
            ? null
            : DateTime.parse(m['liberacao_decidida_em'] as String).toLocal(),
        justificativa: m['liberacao_justificativa'] as String?,
      );
}

class NegadosPdvService {
  final _supabase = SupabaseService.client;

  Future<List<AbastecimentoNegadoPdv>> listar(String empresaId) async {
    final resp = await _supabase.rpc('listar_abastecimentos_negados_pdv', params: {'p_empresa_id': empresaId});
    return (resp as List).map((m) => AbastecimentoNegadoPdv.fromMap(m as Map<String, dynamic>)).toList();
  }

  Future<int> contarPendentes(String empresaId) async {
    final resp = await _supabase.rpc('contar_abastecimentos_negados_pendentes_pdv', params: {'p_empresa_id': empresaId});
    return (resp as num?)?.toInt() ?? 0;
  }

  static const _mensagens = {
    'justificativa_obrigatoria': 'Informe a justificativa para liberar o abastecimento.',
    'expirado': 'O prazo deste pedido de abastecimento já expirou — não dá mais para liberar.',
    'ja_decidido': 'Este abastecimento já foi decidido.',
    'nao_pendente': 'Este abastecimento não está mais aguardando decisão.',
    'nao_autorizado': 'Você não tem permissão para decidir este abastecimento.',
    'nao_encontrado': 'Abastecimento não encontrado.',
  };

  /// Devolve null em sucesso, ou a mensagem de erro.
  Future<String?> decidir({required int id, required bool liberar, String? justificativa}) async {
    try {
      final resp = await _supabase.rpc('decidir_abastecimento_negado_pdv', params: {
        'p_abastecimento_pdv_id': id,
        'p_decisao': liberar ? 'liberado' : 'recusado',
        'p_justificativa': (justificativa ?? '').trim().isEmpty ? null : justificativa!.trim(),
      });
      final status = (resp as Map<String, dynamic>)['status'] as String? ?? '';
      if (status == 'liberado' || status == 'recusado') return null;
      return _mensagens[status] ?? 'Não consegui registrar a decisão.';
    } catch (_) {
      return 'Não consegui registrar a decisão agora. Tente de novo.';
    }
  }
}
