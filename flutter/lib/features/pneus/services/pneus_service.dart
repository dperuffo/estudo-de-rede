import '../../../core/services/supabase_service.dart';

// Fase FLT-Gestão-Pneus (02/09/2026, pedido do Daniel: "equalizar o PWA
// Cliente com as funcionalidades construídas para a web cliente") — porta
// de pneus/page.tsx + actions.ts + AcoesPneu.tsx + PneuForm.tsx. CRUD direto
// (RLS tenant_all já cobre a autorização, igual à web), exceto recapagem
// (RPC registrar_recapagem_pneu — soma concorrente segura).
const posicoesSugeridasPneu = [
  'Dianteiro Esquerdo',
  'Dianteiro Direito',
  'Traseiro Esquerdo Externo',
  'Traseiro Esquerdo Interno',
  'Traseiro Direito Externo',
  'Traseiro Direito Interno',
  'Estepe',
];

class Pneu {
  final String id;
  final String empresaId;
  final String placa;
  final String posicao;
  final String? numeroFogo;
  final String? marca;
  final String? modelo;
  final String? medida;
  final String status;
  final String dataInstalacao;
  final double hodometroInstalacao;
  final double? valorAquisicao;
  final int numeroRecapagens;
  final double custoRecapagensTotal;
  final double? hodometroRemocao;
  final String? observacoes;

  const Pneu({
    required this.id,
    required this.empresaId,
    required this.placa,
    required this.posicao,
    required this.numeroFogo,
    required this.marca,
    required this.modelo,
    required this.medida,
    required this.status,
    required this.dataInstalacao,
    required this.hodometroInstalacao,
    required this.valorAquisicao,
    required this.numeroRecapagens,
    required this.custoRecapagensTotal,
    required this.hodometroRemocao,
    required this.observacoes,
  });

  bool get ativo => status == 'Em uso' || status == 'Estepe';

  factory Pneu.fromMap(Map<String, dynamic> m) => Pneu(
        id: m['id'] as String,
        empresaId: m['empresa_id'] as String,
        placa: m['placa'] as String,
        posicao: m['posicao'] as String,
        numeroFogo: m['numero_fogo'] as String?,
        marca: m['marca'] as String?,
        modelo: m['modelo'] as String?,
        medida: m['medida'] as String?,
        status: m['status'] as String,
        dataInstalacao: m['data_instalacao'] as String,
        hodometroInstalacao: (m['hodometro_instalacao'] as num).toDouble(),
        valorAquisicao: (m['valor_aquisicao'] as num?)?.toDouble(),
        numeroRecapagens: (m['numero_recapagens'] as num).toInt(),
        custoRecapagensTotal:
            (m['custo_recapagens_total'] as num).toDouble(),
        hodometroRemocao: (m['hodometro_remocao'] as num?)?.toDouble(),
        observacoes: m['observacoes'] as String?,
      );
}

class PneusService {
  final _supabase = SupabaseService.client;

  Future<List<Pneu>> buscar(String empresaId) async {
    final rows = await _supabase
        .from('pneus')
        .select(
          'id, empresa_id, placa, posicao, numero_fogo, marca, modelo, medida, status, data_instalacao, hodometro_instalacao, valor_aquisicao, numero_recapagens, custo_recapagens_total, hodometro_remocao, observacoes',
        )
        .eq('empresa_id', empresaId)
        .order('placa')
        .order('posicao');
    return rows.map((m) => Pneu.fromMap(m)).toList();
  }

  Future<String?> criar({
    required String empresaId,
    required String placa,
    required String posicao,
    String? numeroFogo,
    String? marca,
    String? modelo,
    String? medida,
    required String dataInstalacao,
    double? hodometroInstalacao,
    double? valorAquisicao,
    String? observacoes,
  }) async {
    if (placa.trim().isEmpty) return 'Placa é obrigatória.';
    if (posicao.trim().isEmpty) return 'Posição no veículo é obrigatória.';
    if (dataInstalacao.trim().isEmpty) {
      return 'Data de instalação é obrigatória.';
    }
    final email = _supabase.auth.currentUser?.email;
    try {
      await _supabase.from('pneus').insert({
        'empresa_id': empresaId,
        'placa': placa.trim().toUpperCase(),
        'posicao': posicao.trim(),
        'numero_fogo': _vazioParaNull(numeroFogo),
        'marca': _vazioParaNull(marca),
        'modelo': _vazioParaNull(modelo),
        'medida': _vazioParaNull(medida),
        'data_instalacao': dataInstalacao,
        'hodometro_instalacao': hodometroInstalacao ?? 0,
        'valor_aquisicao': valorAquisicao,
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
    required String placa,
    required String posicao,
    String? numeroFogo,
    String? marca,
    String? modelo,
    String? medida,
    required String dataInstalacao,
    double? hodometroInstalacao,
    double? valorAquisicao,
    String? observacoes,
  }) async {
    if (placa.trim().isEmpty) return 'Placa é obrigatória.';
    if (posicao.trim().isEmpty) return 'Posição no veículo é obrigatória.';
    if (dataInstalacao.trim().isEmpty) {
      return 'Data de instalação é obrigatória.';
    }
    try {
      await _supabase.from('pneus').update({
        'placa': placa.trim().toUpperCase(),
        'posicao': posicao.trim(),
        'numero_fogo': _vazioParaNull(numeroFogo),
        'marca': _vazioParaNull(marca),
        'modelo': _vazioParaNull(modelo),
        'medida': _vazioParaNull(medida),
        'data_instalacao': dataInstalacao,
        'hodometro_instalacao': hodometroInstalacao ?? 0,
        'valor_aquisicao': valorAquisicao,
        'observacoes': _vazioParaNull(observacoes),
        'atualizado_em': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  Future<String?> registrarRecapagem(String id, double valor) async {
    if (!valor.isFinite || valor < 0) return 'Valor inválido.';
    try {
      await _supabase.rpc('registrar_recapagem_pneu',
          params: {'p_pneu_id': id, 'p_valor': valor});
      return null;
    } catch (e) {
      return 'Não foi possível registrar: $e';
    }
  }

  // status: "Removido" ou "Descartado".
  Future<String?> remover({
    required String id,
    required String status,
    double? hodometroRemocao,
    String motivo = '',
  }) async {
    try {
      await _supabase.from('pneus').update({
        'status': status,
        'data_remocao': DateTime.now().toIso8601String().substring(0, 10),
        'hodometro_remocao': hodometroRemocao,
        'motivo_remocao': motivo.trim().isEmpty ? null : motivo.trim(),
        'atualizado_em': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  Future<String?> excluir(String id) async {
    try {
      await _supabase.from('pneus').delete().eq('id', id);
      return null;
    } catch (e) {
      return 'Não foi possível excluir: $e';
    }
  }

  String? _vazioParaNull(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v.trim();
}
