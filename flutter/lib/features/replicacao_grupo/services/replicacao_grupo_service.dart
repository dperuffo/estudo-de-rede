import '../../../core/services/supabase_service.dart';

// Fase Replicação-Grupo (04/08/2026) — porta do mecanismo genérico
// "Replicar para o grupo" (web: src/lib/replicacaoGrupo.ts). O motor roda
// inteiro no Postgres (RPCs listar_empresas_alvo_replicacao/
// replicar_para_grupo — ver migração replicacao_grupo_mecanismo_*), então
// aqui só chamamos as RPCs e montamos o relatório. Serve tanto o lado
// cliente quanto o lado posto — é o mesmo mecanismo (Grupo Econômico ou
// Rede de Postos, diferenciados só pelo "segmento" do grupo no banco).

class EmpresaAlvoReplicacao {
  final String empresaId;
  final String nome;
  EmpresaAlvoReplicacao({required this.empresaId, required this.nome});

  factory EmpresaAlvoReplicacao.fromMap(Map<String, dynamic> m) =>
      EmpresaAlvoReplicacao(
        empresaId: m['empresa_id'] as String,
        nome: (m['nome'] as String?) ?? '—',
      );
}

class ItemResultadoReplicacao {
  final String empresaDestinoId;
  final String nomeEmpresa;
  final String status; // sucesso | pulado | erro
  final String? motivo;
  ItemResultadoReplicacao({
    required this.empresaDestinoId,
    required this.nomeEmpresa,
    required this.status,
    this.motivo,
  });
}

class ResultadoReplicacao {
  final String? erro;
  final int totalSucesso;
  final int totalPulado;
  final int totalErro;
  final List<ItemResultadoReplicacao> itens;
  ResultadoReplicacao({
    this.erro,
    this.totalSucesso = 0,
    this.totalPulado = 0,
    this.totalErro = 0,
    this.itens = const [],
  });
}

class ReplicacaoGrupoService {
  final _supabase = SupabaseService.client;

  Future<List<EmpresaAlvoReplicacao>> buscarEmpresasAlvo(
      String empresaOrigemId) async {
    try {
      final rows =
          await _supabase.rpc('listar_empresas_alvo_replicacao', params: {
        'p_empresa_origem_id': empresaOrigemId,
      }) as List;
      return rows
          .map((r) => EmpresaAlvoReplicacao.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<ResultadoReplicacao> replicar({
    required String chaveTabela,
    required String empresaOrigemId,
    String? registroOrigemId,
    String modoConflito = 'pular_se_existir',
  }) async {
    try {
      final loteId = await _supabase.rpc('replicar_para_grupo', params: {
        'p_chave_tabela': chaveTabela,
        'p_empresa_origem_id': empresaOrigemId,
        'p_registro_origem_id': registroOrigemId,
        'p_modo_conflito': modoConflito,
      }) as String;

      final lote = await _supabase
          .from('replicacoes_lote')
          .select('total_sucesso, total_pulado, total_erro')
          .eq('id', loteId)
          .maybeSingle();

      final itensRaw = await _supabase
          .from('replicacoes_lote_itens')
          .select(
              'empresa_destino_id, status, motivo, empresas:empresa_destino_id(nome)')
          .eq('lote_id', loteId) as List;

      final itens = itensRaw.map((raw) {
        final m = raw as Map<String, dynamic>;
        final empresa = m['empresas'] as Map<String, dynamic>?;
        return ItemResultadoReplicacao(
          empresaDestinoId: m['empresa_destino_id'] as String,
          nomeEmpresa: (empresa?['nome'] as String?) ?? '—',
          status: m['status'] as String,
          motivo: m['motivo'] as String?,
        );
      }).toList();

      return ResultadoReplicacao(
        totalSucesso: (lote?['total_sucesso'] as int?) ?? 0,
        totalPulado: (lote?['total_pulado'] as int?) ?? 0,
        totalErro: (lote?['total_erro'] as int?) ?? 0,
        itens: itens,
      );
    } catch (e) {
      return ResultadoReplicacao(erro: 'Não foi possível replicar: $e');
    }
  }
}
