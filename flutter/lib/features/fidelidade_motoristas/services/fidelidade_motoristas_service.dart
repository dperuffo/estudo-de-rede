import '../../../core/services/supabase_service.dart';

// Fase FLT-Fidelidade-Motoristas (02/09/2026, pedido do Daniel: "equalizar
// o PWA Cliente com as funcionalidades construídas para a web cliente") —
// porta de fidelidade-motoristas/page.tsx + missoesActions.ts. Indicadores
// vêm da RPC agregadora indicadores_fidelidade_motoristas (SECURITY
// DEFINER — o ledger de pontos em si não é lido direto por este app,
// igual à web). Missões são CRUD direto contra fidelidade_missoes, RLS já
// garante que só dá pra editar missão cujo criador_empresa_id seja a
// empresa do usuário (mesmo padrão de fidelidade_catalogo_itens usado em
// Parcerias Locais).
const niveisFidelidade = [
  ('Bronze', 0),
  ('Prata', 10000),
  ('Ouro', 30000),
  ('Diamante', 70000),
  ('Herói da Estrada', 150000),
];

String nivelDoSaldo(num saldo) {
  var nivel = niveisFidelidade.first.$1;
  for (final (nome, min) in niveisFidelidade) {
    if (saldo >= min) nivel = nome;
  }
  return nivel;
}

class IndicadorFidelidadeMotorista {
  final String motoristaId;
  final String nomeCompleto;
  final String? telefone;
  final bool aderido;
  final String? aderiuEm;
  final double saldoPontos;
  final int abastecimentosConfirmados;
  final int missoesConcluidas;
  final int resgatesTotal;
  final int resgatesConcluidos;

  const IndicadorFidelidadeMotorista({
    required this.motoristaId,
    required this.nomeCompleto,
    required this.telefone,
    required this.aderido,
    required this.aderiuEm,
    required this.saldoPontos,
    required this.abastecimentosConfirmados,
    required this.missoesConcluidas,
    required this.resgatesTotal,
    required this.resgatesConcluidos,
  });

  factory IndicadorFidelidadeMotorista.fromMap(Map<String, dynamic> m) =>
      IndicadorFidelidadeMotorista(
        motoristaId: m['motorista_id'] as String,
        nomeCompleto: m['nome_completo'] as String,
        telefone: m['telefone'] as String?,
        aderido: m['aderido'] as bool? ?? false,
        aderiuEm: m['aderiu_em'] as String?,
        saldoPontos: (m['saldo_pontos'] as num?)?.toDouble() ?? 0,
        abastecimentosConfirmados:
            (m['abastecimentos_confirmados'] as num?)?.toInt() ?? 0,
        missoesConcluidas: (m['missoes_concluidas'] as num?)?.toInt() ?? 0,
        resgatesTotal: (m['resgates_total'] as num?)?.toInt() ?? 0,
        resgatesConcluidos:
            (m['resgates_concluidos'] as num?)?.toInt() ?? 0,
      );
}

class MissaoFidelidade {
  final String id;
  final String? empresaId;
  final String codigo;
  final String titulo;
  final String? descricao;
  final String tipoMetrica;
  final double meta;
  final double bonus;
  final bool ativa;

  const MissaoFidelidade({
    required this.id,
    required this.empresaId,
    required this.codigo,
    required this.titulo,
    required this.descricao,
    required this.tipoMetrica,
    required this.meta,
    required this.bonus,
    required this.ativa,
  });

  factory MissaoFidelidade.fromMap(Map<String, dynamic> m) =>
      MissaoFidelidade(
        id: m['id'] as String,
        empresaId: m['empresa_id'] as String?,
        codigo: m['codigo'] as String,
        titulo: m['titulo'] as String,
        descricao: m['descricao'] as String?,
        tipoMetrica: m['tipo_metrica'] as String,
        meta: (m['meta'] as num).toDouble(),
        bonus: (m['bonus'] as num).toDouble(),
        ativa: m['ativa'] as bool? ?? true,
      );
}

class FidelidadeMotoristasService {
  final _supabase = SupabaseService.client;

  Future<List<IndicadorFidelidadeMotorista>> buscarIndicadores(
      String empresaId) async {
    final rows = await _supabase.rpc('indicadores_fidelidade_motoristas',
        params: {'p_empresa_id': empresaId});
    return (rows as List)
        .map((m) =>
            IndicadorFidelidadeMotorista.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  Future<List<MissaoFidelidade>> buscarMissoes(String empresaId) async {
    final rows = await _supabase
        .from('fidelidade_missoes')
        .select(
          'id, empresa_id, codigo, titulo, descricao, tipo_metrica, meta, bonus, ativa',
        )
        .or('empresa_id.eq.$empresaId,criador_empresa_id.eq.$empresaId')
        .order('criado_em', ascending: false);
    return rows.map((m) => MissaoFidelidade.fromMap(m)).toList();
  }

  Future<String?> criarMissao({
    required String empresaId,
    required String codigo,
    required String titulo,
    String? descricao,
    required String tipoMetrica,
    required double meta,
    required double bonus,
  }) async {
    if (codigo.trim().isEmpty ||
        titulo.trim().isEmpty ||
        tipoMetrica.trim().isEmpty) {
      return 'Código, título e tipo de métrica são obrigatórios.';
    }
    try {
      await _supabase.from('fidelidade_missoes').insert({
        'criador_empresa_id': empresaId,
        'codigo': codigo.trim(),
        'titulo': titulo.trim(),
        'descricao': _vazioParaNull(descricao),
        'tipo_metrica': tipoMetrica.trim(),
        'meta': meta,
        'bonus': bonus,
        'ativa': true,
      });
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  Future<String?> alternarAtiva(String id, bool ativa) async {
    try {
      await _supabase
          .from('fidelidade_missoes')
          .update({'ativa': ativa}).eq('id', id);
      return null;
    } catch (e) {
      return 'Não foi possível atualizar: $e';
    }
  }

  Future<String?> excluirMissao(String id) async {
    try {
      await _supabase.from('fidelidade_missoes').delete().eq('id', id);
      return null;
    } catch (e) {
      return 'Não foi possível excluir: $e';
    }
  }

  String? _vazioParaNull(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v.trim();
}
