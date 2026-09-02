import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-Tabelas-Frete (02/09/2026, pedido do Daniel: "equalizar o PWA
// Cliente com as funcionalidades construídas para a web cliente") — porta
// de tabelas-frete/novo + [id] + actions.ts. Sem RPC própria — CRUD direto
// (RLS tenant_all cobre a autorização). Faixas usam a mesma estratégia da
// web: delete + insert de todas as faixas a cada salvamento (não há
// update linha a linha), e faixas com valor_por_kg<=0 e valor_minimo<=0
// são descartadas antes de salvar.
class FaixaPesoEditavel {
  double? pesoMinKg;
  double? pesoMaxKg; // null = sem limite (faixa aberta)
  double? valorPorKg;
  double? valorMinimo;

  FaixaPesoEditavel(
      {this.pesoMinKg, this.pesoMaxKg, this.valorPorKg, this.valorMinimo});

  factory FaixaPesoEditavel.fromMap(Map<String, dynamic> m) =>
      FaixaPesoEditavel(
        pesoMinKg: (m['peso_min_kg'] as num?)?.toDouble(),
        pesoMaxKg: (m['peso_max_kg'] as num?)?.toDouble(),
        valorPorKg: (m['valor_por_kg'] as num?)?.toDouble(),
        valorMinimo: (m['valor_minimo'] as num?)?.toDouble(),
      );

  bool get valida =>
      (valorPorKg ?? 0) > 0 || (valorMinimo ?? 0) > 0;
}

class TabelaFreteDetalhe {
  final String id;
  final String nome;
  final bool ativo;
  final String? clienteTomadorId;
  final String? ufOrigem;
  final String? cidadeOrigem;
  final String? ufDestino;
  final String? cidadeDestino;
  final double percentualAdValorem;
  final double percentualGris;
  final double valorTde;
  final double valorTda;
  final double valorDespacho;
  final double valorPedagio;
  final double percentualIcms;

  const TabelaFreteDetalhe({
    required this.id,
    required this.nome,
    required this.ativo,
    required this.clienteTomadorId,
    required this.ufOrigem,
    required this.cidadeOrigem,
    required this.ufDestino,
    required this.cidadeDestino,
    required this.percentualAdValorem,
    required this.percentualGris,
    required this.valorTde,
    required this.valorTda,
    required this.valorDespacho,
    required this.valorPedagio,
    required this.percentualIcms,
  });

  factory TabelaFreteDetalhe.fromMap(Map<String, dynamic> m) =>
      TabelaFreteDetalhe(
        id: m['id'] as String,
        nome: m['nome'] as String,
        ativo: m['ativo'] as bool? ?? true,
        clienteTomadorId: m['cliente_tomador_id'] as String?,
        ufOrigem: m['uf_origem'] as String?,
        cidadeOrigem: m['cidade_origem'] as String?,
        ufDestino: m['uf_destino'] as String?,
        cidadeDestino: m['cidade_destino'] as String?,
        percentualAdValorem:
            (m['percentual_ad_valorem'] as num?)?.toDouble() ?? 0,
        percentualGris: (m['percentual_gris'] as num?)?.toDouble() ?? 0,
        valorTde: (m['valor_tde'] as num?)?.toDouble() ?? 0,
        valorTda: (m['valor_tda'] as num?)?.toDouble() ?? 0,
        valorDespacho: (m['valor_despacho'] as num?)?.toDouble() ?? 0,
        valorPedagio: (m['valor_pedagio'] as num?)?.toDouble() ?? 0,
        percentualIcms: (m['percentual_icms'] as num?)?.toDouble() ?? 0,
      );
}

class ParceiroTomador {
  final String id;
  final String razaoSocial;
  final String? cnpjCpf;
  const ParceiroTomador({required this.id, required this.razaoSocial, this.cnpjCpf});
}

class TabelasFreteService {
  final _supabase = SupabaseService.client;

  Future<List<TabelaFreteDetalhe>> buscar(String empresaId) async {
    final rows = await _supabase
        .from('tabelas_frete')
        .select(
          'id, nome, ativo, cliente_tomador_id, uf_origem, cidade_origem, uf_destino, cidade_destino, percentual_ad_valorem, percentual_gris, valor_tde, valor_tda, valor_despacho, valor_pedagio, percentual_icms',
        )
        .eq('empresa_id', empresaId)
        .order('nome');
    return rows.map((m) => TabelaFreteDetalhe.fromMap(m)).toList();
  }

  Future<TabelaFreteDetalhe?> buscarDetalhe(String id) async {
    final m = await _supabase
        .from('tabelas_frete')
        .select(
          'id, nome, ativo, cliente_tomador_id, uf_origem, cidade_origem, uf_destino, cidade_destino, percentual_ad_valorem, percentual_gris, valor_tde, valor_tda, valor_despacho, valor_pedagio, percentual_icms',
        )
        .eq('id', id)
        .maybeSingle();
    if (m == null) return null;
    return TabelaFreteDetalhe.fromMap(m);
  }

  Future<List<FaixaPesoEditavel>> buscarFaixas(String tabelaFreteId) async {
    final rows = await _supabase
        .from('tabelas_frete_faixas')
        .select('peso_min_kg, peso_max_kg, valor_por_kg, valor_minimo')
        .eq('tabela_frete_id', tabelaFreteId)
        .order('peso_min_kg');
    return rows.map((m) => FaixaPesoEditavel.fromMap(m)).toList();
  }

  Future<List<ParceiroTomador>> buscarParceirosTomadores(
      String empresaId) async {
    final rows = await _supabase
        .from('cadastros_parceiros')
        .select('id, razao_social, cnpj_cpf')
        .eq('empresa_id', empresaId)
        .eq('papel', 'tomador')
        .order('razao_social');
    return rows
        .map((m) => ParceiroTomador(
            id: m['id'] as String,
            razaoSocial: m['razao_social'] as String,
            cnpjCpf: m['cnpj_cpf'] as String?))
        .toList();
  }

  Future<String?> _gravarFaixas(
      String tabelaFreteId, List<FaixaPesoEditavel> faixas) async {
    final validas = faixas.where((f) => f.valida).toList();
    if (validas.isEmpty) return 'Cadastre pelo menos uma faixa de peso.';
    try {
      await _supabase
          .from('tabelas_frete_faixas')
          .delete()
          .eq('tabela_frete_id', tabelaFreteId);
      await _supabase.from('tabelas_frete_faixas').insert(validas
          .map((f) => {
                'tabela_frete_id': tabelaFreteId,
                'peso_min_kg': f.pesoMinKg ?? 0,
                'peso_max_kg': f.pesoMaxKg,
                'valor_por_kg': f.valorPorKg ?? 0,
                'valor_minimo': f.valorMinimo ?? 0,
              })
          .toList());
      return null;
    } catch (e) {
      return 'Não foi possível salvar as faixas: $e';
    }
  }

  Future<({String? id, String? erro})> criar({
    required String empresaId,
    required String nome,
    String? clienteTomadorId,
    String? ufOrigem,
    String? cidadeOrigem,
    String? ufDestino,
    String? cidadeDestino,
    double percentualAdValorem = 0,
    double percentualGris = 0,
    double valorTde = 0,
    double valorTda = 0,
    double valorDespacho = 0,
    double valorPedagio = 0,
    double percentualIcms = 0,
    required List<FaixaPesoEditavel> faixas,
  }) async {
    if (nome.trim().isEmpty) {
      return (id: null, erro: 'O nome da tabela é obrigatório.');
    }
    if (!faixas.any((f) => f.valida)) {
      return (id: null, erro: 'Cadastre pelo menos uma faixa de peso.');
    }
    try {
      final inserida = await _supabase
          .from('tabelas_frete')
          .insert({
            'empresa_id': empresaId,
            'nome': nome.trim(),
            'ativo': true,
            'cliente_tomador_id': clienteTomadorId,
            'uf_origem': _vazioParaNull(ufOrigem),
            'cidade_origem': _vazioParaNull(cidadeOrigem),
            'uf_destino': _vazioParaNull(ufDestino),
            'cidade_destino': _vazioParaNull(cidadeDestino),
            'percentual_ad_valorem': percentualAdValorem,
            'percentual_gris': percentualGris,
            'valor_tde': valorTde,
            'valor_tda': valorTda,
            'valor_despacho': valorDespacho,
            'valor_pedagio': valorPedagio,
            'percentual_icms': percentualIcms,
            'criado_por': AuthService().emailAtual,
          })
          .select('id')
          .single();
      final id = inserida['id'] as String;
      final erroFaixas = await _gravarFaixas(id, faixas);
      if (erroFaixas != null) {
        return (id: id, erro: 'Tabela criada, mas houve erro ao salvar as faixas: $erroFaixas');
      }
      return (id: id, erro: null);
    } catch (e) {
      return (id: null, erro: 'Não foi possível salvar: $e');
    }
  }

  Future<String?> atualizar({
    required String id,
    required String nome,
    String? clienteTomadorId,
    String? ufOrigem,
    String? cidadeOrigem,
    String? ufDestino,
    String? cidadeDestino,
    double percentualAdValorem = 0,
    double percentualGris = 0,
    double valorTde = 0,
    double valorTda = 0,
    double valorDespacho = 0,
    double valorPedagio = 0,
    double percentualIcms = 0,
    required List<FaixaPesoEditavel> faixas,
  }) async {
    if (nome.trim().isEmpty) return 'O nome da tabela é obrigatório.';
    if (!faixas.any((f) => f.valida)) {
      return 'Cadastre pelo menos uma faixa de peso.';
    }
    try {
      await _supabase.from('tabelas_frete').update({
        'nome': nome.trim(),
        'cliente_tomador_id': clienteTomadorId,
        'uf_origem': _vazioParaNull(ufOrigem),
        'cidade_origem': _vazioParaNull(cidadeOrigem),
        'uf_destino': _vazioParaNull(ufDestino),
        'cidade_destino': _vazioParaNull(cidadeDestino),
        'percentual_ad_valorem': percentualAdValorem,
        'percentual_gris': percentualGris,
        'valor_tde': valorTde,
        'valor_tda': valorTda,
        'valor_despacho': valorDespacho,
        'valor_pedagio': valorPedagio,
        'percentual_icms': percentualIcms,
        'atualizado_em': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      return await _gravarFaixas(id, faixas);
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  Future<String?> alternarAtivo(String id, bool ativo) async {
    try {
      await _supabase.from('tabelas_frete').update({
        'ativo': ativo,
        'atualizado_em': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      return null;
    } catch (e) {
      return 'Não foi possível atualizar: $e';
    }
  }

  Future<String?> excluir(String id) async {
    try {
      await _supabase.from('tabelas_frete').delete().eq('id', id);
      return null;
    } catch (e) {
      return 'Não foi possível excluir — verifique se ela não está sendo usada por alguma cotação: $e';
    }
  }

  String? _vazioParaNull(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v.trim();
}
