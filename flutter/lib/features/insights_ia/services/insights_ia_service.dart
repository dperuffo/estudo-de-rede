import '../../../core/services/supabase_service.dart';

// Fase FLT-Insights-IA (02/09/2026, pedido do Daniel: "equalizar o PWA
// Cliente com as funcionalidades construídas para a web cliente") — porta
// de insights-ia/page.tsx + actions.ts. Só o lado leitura/interação
// (listar, marcar lido, dispensar) — a geração em si (coletar_sinais +
// chamada ao Claude) roda 1x/dia via cron no servidor Next.js, não faz
// sentido/não é alcançável rodar isso a partir do app mobile.
class InsightIA {
  final String id;
  final String categoria;
  final String titulo;
  final String descricao;
  final String? recomendacao;
  final String severidade; // baixa | media | alta | critica
  final double? valorImpactoEstimado;
  final String status; // novo | lido | dispensado
  final String geradoEm;

  const InsightIA({
    required this.id,
    required this.categoria,
    required this.titulo,
    required this.descricao,
    required this.recomendacao,
    required this.severidade,
    required this.valorImpactoEstimado,
    required this.status,
    required this.geradoEm,
  });

  factory InsightIA.fromMap(Map<String, dynamic> m) => InsightIA(
        id: m['id'] as String,
        categoria: m['categoria'] as String? ?? '',
        titulo: m['titulo'] as String? ?? '',
        descricao: m['descricao'] as String? ?? '',
        recomendacao: m['recomendacao'] as String?,
        severidade: m['severidade'] as String? ?? 'media',
        valorImpactoEstimado:
            (m['valor_impacto_estimado'] as num?)?.toDouble(),
        status: m['status'] as String? ?? 'novo',
        geradoEm: m['gerado_em'] as String? ?? '',
      );
}

const categoriaLabel = <String, String>{
  'combustivel_posto_caro': 'Posto de combustível caro',
  'combustivel_consumo_baixo': 'Consumo de combustível baixo',
  'manutencao_custo_subindo': 'Custo de manutenção subindo',
  'manutencao_componente_recorrente': 'Componente recorrente na manutenção',
  'pneus_vida_util_baixa': 'Vida útil baixa dos pneus',
  'sinistros_recorrentes': 'Sinistros recorrentes',
  'multas_pontos_acumulados': 'Pontos acumulados em multas',
  'aprovacoes_paradas': 'Aprovações paradas',
  'seguro_vencendo': 'Apólice de seguro vencendo',
  'documentos_motorista_vencendo': 'Documentos de motorista vencendo',
};

const _ordemSeveridade = {'critica': 0, 'alta': 1, 'media': 2, 'baixa': 3};

class InsightsIaService {
  final _supabase = SupabaseService.client;

  Future<List<InsightIA>> listar(String empresaId,
      {bool incluirDispensados = false}) async {
    var query = _supabase
        .from('insights_proativos_ia')
        .select()
        .eq('empresa_id', empresaId);
    if (!incluirDispensados) {
      query = query.neq('status', 'dispensado');
    }
    final rows = await query.order('gerado_em', ascending: false);
    final lista = rows.map((m) => InsightIA.fromMap(m)).toList();
    lista.sort((a, b) {
      final statusA = a.status == 'novo' ? 0 : 1;
      final statusB = b.status == 'novo' ? 0 : 1;
      if (statusA != statusB) return statusA.compareTo(statusB);
      final sevA = _ordemSeveridade[a.severidade] ?? 4;
      final sevB = _ordemSeveridade[b.severidade] ?? 4;
      if (sevA != sevB) return sevA.compareTo(sevB);
      final impA = a.valorImpactoEstimado ?? 0;
      final impB = b.valorImpactoEstimado ?? 0;
      return impB.compareTo(impA);
    });
    return lista;
  }

  Future<int> contarNovos(String empresaId) async {
    final rows = await _supabase
        .from('insights_proativos_ia')
        .select('id')
        .eq('empresa_id', empresaId)
        .eq('status', 'novo');
    return rows.length;
  }

  /// Gate de plano específico deste recurso (só ele, na web, é gated por
  /// plano além do mapa de permissões padrão): admin sempre libera; senão
  /// libera se a empresa tem plano 'enterprise' OU a flag manual
  /// acesso_insights_ia_liberado=true.
  Future<bool> temAcessoPorPlano(String empresaId, String? perfil) async {
    if (perfil == 'admin') return true;
    final m = await _supabase
        .from('empresas')
        .select('plano, acesso_insights_ia_liberado')
        .eq('id', empresaId)
        .maybeSingle();
    if (m == null) return false;
    return m['plano'] == 'enterprise' ||
        m['acesso_insights_ia_liberado'] == true;
  }

  Future<String?> marcarLido(String id) async {
    try {
      await _supabase.rpc('marcar_insight_lido', params: {'p_id': id});
      return null;
    } catch (e) {
      return 'Não foi possível marcar como lido: $e';
    }
  }

  Future<String?> dispensar(String id) async {
    try {
      await _supabase.rpc('dispensar_insight', params: {'p_id': id});
      return null;
    } catch (e) {
      return 'Não foi possível dispensar: $e';
    }
  }
}
