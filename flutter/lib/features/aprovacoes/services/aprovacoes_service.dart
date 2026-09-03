import '../../../core/services/supabase_service.dart';

// Fase FLT-Aprovações (03/09/2026, pedido do Daniel: "equalizar o PWA
// Cliente com as funcionalidades construídas para a web cliente") — porta
// de aprovacoes/page.tsx + actions.ts (fluxo de aprovação multi-nível).
//
// Igual na web, toda a lógica de negócio mora nas RPCs SECURITY DEFINER —
// aqui só chamamos elas e mostramos a mensagem de erro que voltar
// (permissão por nível, etc. já são checadas no servidor).
//
// Aprovação é SEQUENCIAL, não paralela: existe um único `nivel_atual` na
// solicitação. Nível 1 pode ser decidido por qualquer perfil com acesso à
// empresa; nível 2 (só existe quando niveis_necessarios=2, valor>2000)
// exige perfil gestor_frota ou admin — a RPC já barra isso, aqui só
// exibimos o erro devolvido.
class SolicitacaoAprovacao {
  final String id;
  final String categoria; // manutencao | frete | peca | outro
  final String titulo;
  final String? descricao;
  final double valor;
  final String solicitanteEmail;
  final String status; // pendente | aprovada | reprovada | executada | cancelada
  final int nivelAtual;
  final int niveisNecessarios;
  final String criadoEm;
  final String? executadoEm;

  const SolicitacaoAprovacao({
    required this.id,
    required this.categoria,
    required this.titulo,
    required this.descricao,
    required this.valor,
    required this.solicitanteEmail,
    required this.status,
    required this.nivelAtual,
    required this.niveisNecessarios,
    required this.criadoEm,
    required this.executadoEm,
  });

  factory SolicitacaoAprovacao.fromMap(Map<String, dynamic> m) =>
      SolicitacaoAprovacao(
        id: m['id'] as String,
        categoria: m['categoria'] as String? ?? 'outro',
        titulo: m['titulo'] as String? ?? '',
        descricao: m['descricao'] as String?,
        valor: (m['valor'] as num?)?.toDouble() ?? 0,
        solicitanteEmail: m['solicitante_email'] as String? ?? '',
        status: m['status'] as String? ?? 'pendente',
        nivelAtual: (m['nivel_atual'] as num?)?.toInt() ?? 1,
        niveisNecessarios: (m['niveis_necessarios'] as num?)?.toInt() ?? 1,
        criadoEm: m['criado_em'] as String? ?? '',
        executadoEm: m['executado_em'] as String?,
      );
}

const categoriasAprovacao = <String, String>{
  'manutencao': 'Manutenção',
  'frete': 'Frete',
  'peca': 'Peça',
  'outro': 'Outro',
};

class AprovacoesService {
  final _supabase = SupabaseService.client;

  Future<List<SolicitacaoAprovacao>> buscar(String empresaId) async {
    final rows = await _supabase
        .from('solicitacoes_aprovacao')
        .select()
        .eq('empresa_id', empresaId)
        .order('criado_em', ascending: false)
        .limit(200);
    return rows.map((m) => SolicitacaoAprovacao.fromMap(m)).toList();
  }

  /// Solicitações de manutenção já aprovadas mas ainda não vinculadas a um
  /// lançamento (status='aprovada') — usado pro form de Manutenção
  /// Preditiva escolher qual solicitação vincular ao registrar um custo
  /// acima do limiar configurado.
  Future<List<SolicitacaoAprovacao>> buscarAprovadasDeManutencao(
      String empresaId) async {
    final rows = await _supabase
        .from('solicitacoes_aprovacao')
        .select()
        .eq('empresa_id', empresaId)
        .eq('categoria', 'manutencao')
        .eq('status', 'aprovada')
        .order('criado_em', ascending: false);
    return rows.map((m) => SolicitacaoAprovacao.fromMap(m)).toList();
  }

  Future<String?> criar({
    required String empresaId,
    required String categoria,
    required String titulo,
    String? descricao,
    required double valor,
  }) async {
    if (titulo.trim().isEmpty) return 'Informe o título da solicitação.';
    if (valor <= 0) return 'Informe um valor maior que zero.';
    if (!categoriasAprovacao.containsKey(categoria)) {
      return 'Categoria inválida.';
    }
    try {
      await _supabase.rpc('criar_solicitacao_aprovacao', params: {
        'p_empresa_id': empresaId,
        'p_categoria': categoria,
        'p_titulo': titulo.trim(),
        'p_descricao':
            (descricao == null || descricao.trim().isEmpty) ? null : descricao.trim(),
        'p_valor': valor,
      });
      return null;
    } catch (e) {
      return 'Não foi possível criar a solicitação: $e';
    }
  }

  Future<String?> decidir({
    required String id,
    required String decisao, // aprovado | reprovado
    String? comentario,
  }) async {
    try {
      await _supabase.rpc('decidir_solicitacao_aprovacao', params: {
        'p_solicitacao_id': id,
        'p_decisao': decisao,
        'p_comentario': (comentario == null || comentario.trim().isEmpty)
            ? null
            : comentario.trim(),
      });
      return null;
    } catch (e) {
      return 'Não foi possível registrar a decisão: $e';
    }
  }

  Future<String?> marcarExecutada(String id) async {
    try {
      await _supabase
          .rpc('marcar_solicitacao_executada', params: {'p_solicitacao_id': id});
      return null;
    } catch (e) {
      return 'Não foi possível marcar como executada: $e';
    }
  }

  Future<String?> cancelar(String id) async {
    try {
      await _supabase
          .rpc('cancelar_solicitacao_aprovacao', params: {'p_solicitacao_id': id});
      return null;
    } catch (e) {
      return 'Não foi possível cancelar: $e';
    }
  }
}
