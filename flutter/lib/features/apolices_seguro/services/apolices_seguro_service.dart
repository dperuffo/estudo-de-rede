import '../../../core/services/supabase_service.dart';

// Fase FLT-Apólices-Seguro (02/09/2026, pedido do Daniel: "equalizar o PWA
// Cliente com as funcionalidades construídas para a web cliente") — porta
// de apolices-seguro/page.tsx + actions.ts + ApoliceForm.tsx. CRUD direto
// (sem RPC própria — RLS tenant_all já cobre a autorização, mesmo padrão
// da web). Status (Ativa/Vencendo/Vencida) é calculado em runtime, não
// persistido no banco — replicado aqui igual à comparação de strings ISO
// (YYYY-MM-DD) usada na web.
class ApoliceSeguro {
  final String id;
  final String empresaId;
  final String? placa;
  final String seguradora;
  final String numeroApolice;
  final String vigenciaInicio;
  final String vigenciaFim;
  final String? cobertura;
  final double? valorFranquia;
  final double? valorPremio;
  final String? observacoes;

  const ApoliceSeguro({
    required this.id,
    required this.empresaId,
    required this.placa,
    required this.seguradora,
    required this.numeroApolice,
    required this.vigenciaInicio,
    required this.vigenciaFim,
    required this.cobertura,
    required this.valorFranquia,
    required this.valorPremio,
    required this.observacoes,
  });

  bool get vencida {
    final hoje = DateTime.now();
    final hojeIso = _isoData(hoje);
    return vigenciaFim.substring(0, 10).compareTo(hojeIso) < 0;
  }

  bool get vencendoEm30Dias {
    if (vencida) return false;
    final hoje = DateTime.now();
    final em30 = hoje.add(const Duration(days: 30));
    final hojeIso = _isoData(hoje);
    final em30Iso = _isoData(em30);
    final fim = vigenciaFim.substring(0, 10);
    return fim.compareTo(hojeIso) >= 0 && fim.compareTo(em30Iso) <= 0;
  }

  static String _isoData(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  factory ApoliceSeguro.fromMap(Map<String, dynamic> m) => ApoliceSeguro(
        id: m['id'] as String,
        empresaId: m['empresa_id'] as String,
        placa: m['placa'] as String?,
        seguradora: m['seguradora'] as String,
        numeroApolice: m['numero_apolice'] as String,
        vigenciaInicio: m['vigencia_inicio'] as String,
        vigenciaFim: m['vigencia_fim'] as String,
        cobertura: m['cobertura'] as String?,
        valorFranquia: (m['valor_franquia'] as num?)?.toDouble(),
        valorPremio: (m['valor_premio'] as num?)?.toDouble(),
        observacoes: m['observacoes'] as String?,
      );
}

class ApolicesSeguroService {
  final _supabase = SupabaseService.client;

  Future<List<ApoliceSeguro>> buscar(String empresaId) async {
    final rows = await _supabase
        .from('apolices_seguro')
        .select(
          'id, empresa_id, placa, seguradora, numero_apolice, vigencia_inicio, vigencia_fim, cobertura, valor_franquia, valor_premio, observacoes',
        )
        .eq('empresa_id', empresaId)
        .order('vigencia_fim', ascending: true);
    return rows.map((m) => ApoliceSeguro.fromMap(m)).toList();
  }

  Future<String?> criar({
    required String empresaId,
    String? placa,
    required String seguradora,
    required String numeroApolice,
    required String vigenciaInicio,
    required String vigenciaFim,
    String? cobertura,
    double? valorFranquia,
    double? valorPremio,
    String? observacoes,
  }) async {
    final erro = _validar(
        seguradora, numeroApolice, vigenciaInicio, vigenciaFim);
    if (erro != null) return erro;
    final email = _supabase.auth.currentUser?.email;
    try {
      await _supabase.from('apolices_seguro').insert({
        'empresa_id': empresaId,
        'placa': _vazioParaNull(placa)?.toUpperCase(),
        'seguradora': seguradora.trim(),
        'numero_apolice': numeroApolice.trim(),
        'vigencia_inicio': vigenciaInicio,
        'vigencia_fim': vigenciaFim,
        'cobertura': _vazioParaNull(cobertura),
        'valor_franquia': valorFranquia,
        'valor_premio': valorPremio,
        'observacoes': _vazioParaNull(observacoes),
        'criado_por': email,
      });
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  Future<String?> atualizar({
    required String id,
    String? placa,
    required String seguradora,
    required String numeroApolice,
    required String vigenciaInicio,
    required String vigenciaFim,
    String? cobertura,
    double? valorFranquia,
    double? valorPremio,
    String? observacoes,
  }) async {
    final erro = _validar(
        seguradora, numeroApolice, vigenciaInicio, vigenciaFim);
    if (erro != null) return erro;
    try {
      await _supabase.from('apolices_seguro').update({
        'placa': _vazioParaNull(placa)?.toUpperCase(),
        'seguradora': seguradora.trim(),
        'numero_apolice': numeroApolice.trim(),
        'vigencia_inicio': vigenciaInicio,
        'vigencia_fim': vigenciaFim,
        'cobertura': _vazioParaNull(cobertura),
        'valor_franquia': valorFranquia,
        'valor_premio': valorPremio,
        'observacoes': _vazioParaNull(observacoes),
        'atualizado_em': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  Future<String?> excluir(String id) async {
    try {
      await _supabase.from('apolices_seguro').delete().eq('id', id);
      return null;
    } catch (e) {
      return 'Não foi possível excluir: $e';
    }
  }

  String? _validar(String seguradora, String numeroApolice,
      String vigenciaInicio, String vigenciaFim) {
    if (seguradora.trim().isEmpty ||
        numeroApolice.trim().isEmpty ||
        vigenciaInicio.trim().isEmpty ||
        vigenciaFim.trim().isEmpty) {
      return 'Seguradora, número da apólice e vigência (início e fim) são obrigatórios.';
    }
    return null;
  }

  String? _vazioParaNull(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v.trim();
}
