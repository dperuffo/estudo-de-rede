import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-Bolsa-Fretes (02/09/2026, pedido do Daniel: "equalizar o PWA
// Cliente com as funcionalidades construídas para a web cliente") — porta
// de bolsa-fretes/page.tsx + actions.ts. v1 restrita a empresas do MESMO
// Grupo Econômico (não é cross-tenant entre clientes diferentes — RPC
// bolsa_fretes_grupo já faz essa restrição no servidor). Sem
// oferta/negociação nesta v1 — só declarar capacidade ociosa própria e
// ver, em modo leitura, os fretes "disponivel" postados pelas empresas
// irmãs do grupo (sem preço/contato, só dados de rota/peso/prazo).
class CapacidadeOciosa {
  final String id;
  final String empresaId;
  final String? placa;
  final String? tipoVeiculo;
  final String origemCidade;
  final String origemUf;
  final String? destinoPretendido;
  final String disponivelAPartir;
  final double? capacidadeKg;
  final String? observacoes;
  final String status; // ativo | utilizada | cancelada
  final String criadoEm;

  const CapacidadeOciosa({
    required this.id,
    required this.empresaId,
    required this.placa,
    required this.tipoVeiculo,
    required this.origemCidade,
    required this.origemUf,
    required this.destinoPretendido,
    required this.disponivelAPartir,
    required this.capacidadeKg,
    required this.observacoes,
    required this.status,
    required this.criadoEm,
  });

  factory CapacidadeOciosa.fromMap(Map<String, dynamic> m) => CapacidadeOciosa(
        id: m['id'] as String,
        empresaId: m['empresa_id'] as String,
        placa: m['placa'] as String?,
        tipoVeiculo: m['tipo_veiculo'] as String?,
        origemCidade: m['origem_cidade'] as String? ?? '',
        origemUf: m['origem_uf'] as String? ?? '',
        destinoPretendido: m['destino_pretendido'] as String?,
        disponivelAPartir: m['disponivel_a_partir'] as String? ?? '',
        capacidadeKg: (m['capacidade_kg'] as num?)?.toDouble(),
        observacoes: m['observacoes'] as String?,
        status: m['status'] as String? ?? 'ativo',
        criadoEm: m['criado_em'] as String? ?? '',
      );
}

class FreteDoGrupo {
  final String freteId;
  final String empresaNome;
  final String? titulo;
  final String? origemCidade;
  final String? origemUf;
  final String? destinoCidade;
  final String? destinoUf;
  final String? tipoCarga;
  final double? pesoCargaKg;
  final double? kmEstimado;
  final String? dataSaidaPrevista;
  final String? prazoEntrega;

  const FreteDoGrupo({
    required this.freteId,
    required this.empresaNome,
    required this.titulo,
    required this.origemCidade,
    required this.origemUf,
    required this.destinoCidade,
    required this.destinoUf,
    required this.tipoCarga,
    required this.pesoCargaKg,
    required this.kmEstimado,
    required this.dataSaidaPrevista,
    required this.prazoEntrega,
  });

  factory FreteDoGrupo.fromMap(Map<String, dynamic> m) => FreteDoGrupo(
        freteId: m['frete_id'] as String,
        empresaNome: m['empresa_nome'] as String? ?? '',
        titulo: m['titulo'] as String?,
        origemCidade: m['origem_cidade'] as String?,
        origemUf: m['origem_uf'] as String?,
        destinoCidade: m['destino_cidade'] as String?,
        destinoUf: m['destino_uf'] as String?,
        tipoCarga: m['tipo_carga'] as String?,
        pesoCargaKg: (m['peso_carga_kg'] as num?)?.toDouble(),
        kmEstimado: (m['km_estimado'] as num?)?.toDouble(),
        dataSaidaPrevista: m['data_saida_prevista'] as String?,
        prazoEntrega: m['prazo_entrega'] as String?,
      );
}

class BolsaFretesService {
  final _supabase = SupabaseService.client;

  Future<List<CapacidadeOciosa>> buscarMinhaCapacidade(
      String empresaId) async {
    final rows = await _supabase
        .from('capacidade_ociosa_frota')
        .select()
        .eq('empresa_id', empresaId)
        .order('criado_em', ascending: false);
    return rows.map((m) => CapacidadeOciosa.fromMap(m)).toList();
  }

  /// Chama a RPC bolsa_fretes_grupo, que já resolve autorização e escopo
  /// de grupo econômico no servidor. Se a empresa não pertence a nenhum
  /// grupo (ou o grupo não tem empresas irmãs), retorna lista vazia.
  Future<({List<FreteDoGrupo> fretes, String? erro})> buscarFretesDoGrupo(
      String empresaId) async {
    try {
      final rows = await _supabase
          .rpc('bolsa_fretes_grupo', params: {'p_empresa_id': empresaId});
      final lista =
          (rows as List).map((m) => FreteDoGrupo.fromMap(m)).toList();
      return (fretes: lista, erro: null);
    } catch (e) {
      return (
        fretes: <FreteDoGrupo>[],
        erro: 'Não foi possível carregar os fretes do grupo: $e'
      );
    }
  }

  String? _validar({
    required String origemCidade,
    required String origemUf,
    required String disponivelAPartir,
  }) {
    if (origemCidade.trim().isEmpty) return 'Informe a cidade de origem.';
    if (origemUf.trim().length != 2) return 'Informe a UF (2 letras).';
    if (disponivelAPartir.trim().isEmpty) {
      return 'Informe a partir de quando o veículo está disponível.';
    }
    return null;
  }

  Future<String?> criar({
    required String empresaId,
    String? placa,
    String? tipoVeiculo,
    required String origemCidade,
    required String origemUf,
    String? destinoPretendido,
    required String disponivelAPartir,
    double? capacidadeKg,
    String? observacoes,
  }) async {
    final erro = _validar(
      origemCidade: origemCidade,
      origemUf: origemUf,
      disponivelAPartir: disponivelAPartir,
    );
    if (erro != null) return erro;
    try {
      await _supabase.from('capacidade_ociosa_frota').insert({
        'empresa_id': empresaId,
        'placa': (placa == null || placa.trim().isEmpty)
            ? null
            : placa.trim().toUpperCase(),
        'tipo_veiculo':
            (tipoVeiculo == null || tipoVeiculo.trim().isEmpty)
                ? null
                : tipoVeiculo.trim(),
        'origem_cidade': origemCidade.trim(),
        'origem_uf': origemUf.trim().toUpperCase(),
        'destino_pretendido':
            (destinoPretendido == null || destinoPretendido.trim().isEmpty)
                ? null
                : destinoPretendido.trim(),
        'disponivel_a_partir': disponivelAPartir,
        'capacidade_kg': capacidadeKg,
        'observacoes': (observacoes == null || observacoes.trim().isEmpty)
            ? null
            : observacoes.trim(),
        'status': 'ativo',
        'criado_por': AuthService().emailAtual,
      });
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  Future<String?> atualizarStatus(String id, String status) async {
    try {
      await _supabase.from('capacidade_ociosa_frota').update({
        'status': status,
        'atualizado_em': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      return null;
    } catch (e) {
      return 'Não foi possível atualizar: $e';
    }
  }

  Future<String?> excluir(String id) async {
    try {
      await _supabase.from('capacidade_ociosa_frota').delete().eq('id', id);
      return null;
    } catch (e) {
      return 'Não foi possível excluir: $e';
    }
  }
}
