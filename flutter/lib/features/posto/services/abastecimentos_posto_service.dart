import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — porta (com escopo reduzido, ver README) de
// AbastecimentosPosto.tsx da web: abastecimentos que ESTE posto forneceu,
// multi-provedor (PróFrotas + externos via abastecimentos_unificado).
//
// Fora do escopo desta primeira versão (ver README pra detalhes):
// paginação de verdade (só traz os N mais recentes), os filtros/contadores
// de status de NF-e (só o badge por linha), e navegação pra tela de
// detalhe/ajuste (ainda não existe no Flutter).

const produtosPosto = [
  'Gasolina Comum',
  'Gasolina Aditivada',
  'Gasolina Alta Octanagem',
  'Etanol Comum',
  'Etanol Aditivado',
  'Diesel S-10 Comum',
  'Diesel S-10 Aditivado',
  'Diesel S-500 Comum',
  'Diesel S-500 Aditivado',
  'GNV',
  'GLP',
];

const coresProvedor = <String, int>{
  'profrotas': 0xFFDBEAFE, // azul
  'Valecard': 0xFFEDE9FE, // roxo
  'RedeFrota': 0xFFFFEDD5, // laranja
  'TicketLog': 0xFFCCFBF1, // teal
  'Veloe': 0xFFFCE7F3, // rosa
};

String nomeProvedor(String provedor) => provedor == 'profrotas' ? 'PróFrotas' : provedor;

class FiltrosAbastecimentosPosto {
  final String? combustivel;
  final String? provedor;
  final String? clienteId;
  final String? q;
  final String? de;
  final String? ate;
  const FiltrosAbastecimentosPosto({
    this.combustivel,
    this.provedor,
    this.clienteId,
    this.q,
    this.de,
    this.ate,
  });
}

class RegistroAbastecimentoPosto {
  final String id;
  final String provedor;
  final String? codigoAbastecimento;
  final String? dataAbastecimento;
  final String? empresaId;
  final String? placa;
  final String? motoristaNome;
  final String? produto;
  final double? litros;
  final double? valorTotal;

  const RegistroAbastecimentoPosto({
    required this.id,
    required this.provedor,
    this.codigoAbastecimento,
    this.dataAbastecimento,
    this.empresaId,
    this.placa,
    this.motoristaNome,
    this.produto,
    this.litros,
    this.valorTotal,
  });

  String get chave => '$provedor:$id';

  factory RegistroAbastecimentoPosto.fromMap(Map<String, dynamic> m) => RegistroAbastecimentoPosto(
        id: m['id'].toString(),
        provedor: m['provedor'] as String? ?? '',
        codigoAbastecimento: m['codigo_abastecimento'] as String?,
        dataAbastecimento: m['data_abastecimento'] as String?,
        empresaId: m['empresa_id'] as String?,
        placa: m['placa'] as String?,
        motoristaNome: m['motorista_nome'] as String?,
        produto: m['produto'] as String?,
        litros: (m['litros'] as num?)?.toDouble(),
        valorTotal: (m['valor_total'] as num?)?.toDouble(),
      );
}

class ResultadoAbastecimentosPosto {
  final List<RegistroAbastecimentoPosto> registros;
  final int total;
  final double volumeTotal;
  final double receitaTotal;
  final List<({String id, String nome})> clientesOpcoes;
  final List<String> provedoresOpcoes;
  // Chave "provedor:id" -> número da NF (pode ser null mesmo emitida).
  final Map<String, String?> notaPorAbastecimento;
  // Chave "provedor:id" -> motivo resumido da rejeição.
  final Map<String, String> pendenciaPorAbastecimento;
  final Set<String> comAjustePendente;

  const ResultadoAbastecimentosPosto({
    required this.registros,
    required this.total,
    required this.volumeTotal,
    required this.receitaTotal,
    required this.clientesOpcoes,
    required this.provedoresOpcoes,
    required this.notaPorAbastecimento,
    required this.pendenciaPorAbastecimento,
    required this.comAjustePendente,
  });

  static const vazio = ResultadoAbastecimentosPosto(
    registros: [],
    total: 0,
    volumeTotal: 0,
    receitaTotal: 0,
    clientesOpcoes: [],
    provedoresOpcoes: [],
    notaPorAbastecimento: {},
    pendenciaPorAbastecimento: {},
    comAjustePendente: {},
  );
}

const _motivoLabel = <String, String>{
  'cnpj_divergente': 'CNPJ do emitente não confere.',
  'produto_divergente': 'Produto do XML não confere.',
  'quantidade_divergente': 'Quantidade do XML não confere.',
  'valor_divergente': 'Valor do XML não confere.',
  'nao_encontrado': 'Não foi possível achar o abastecimento correspondente.',
  'erro_leitura_xml': 'Erro ao ler o arquivo XML.',
};

class AbastecimentosPostoService {
  final _supabase = SupabaseService.client;

  // Porta de mascararCnpj (AbastecimentosPosto.tsx) — posto_cnpj na tabela
  // de externos vem em formatos variados por provedor; compara contra as
  // duas variantes mais prováveis (crua e com máscara padrão).
  List<String> _variantesCnpj(String cnpjLimpo) {
    final digitos = cnpjLimpo.replaceAll(RegExp(r'\D'), '');
    if (digitos.length != 14) return [cnpjLimpo];
    final mascarado =
        '${digitos.substring(0, 2)}.${digitos.substring(2, 5)}.${digitos.substring(5, 8)}/${digitos.substring(8, 12)}-${digitos.substring(12, 14)}';
    return [cnpjLimpo, mascarado];
  }

  Future<ResultadoAbastecimentosPosto> buscar({
    required String empresaPostoId,
    FiltrosAbastecimentosPosto filtros = const FiltrosAbastecimentosPosto(),
    int limite = 50,
  }) async {
    final empresa =
        await _supabase.from('empresas').select('cnpj').eq('id', empresaPostoId).maybeSingle();
    final meuCnpj = empresa?['cnpj'] as String?;
    if (meuCnpj == null || meuCnpj.isEmpty) return ResultadoAbastecimentosPosto.vazio;

    final variantes = _variantesCnpj(meuCnpj);

    // Opções pros filtros de cliente/provedor — mesma ideia da web: 1
    // coluna só, com um limite alto (é metadado, não a listagem principal).
    final clientesRaw = await _supabase
        .from('abastecimentos_unificado')
        .select('empresa_id')
        .inFilter('posto_cnpj', variantes)
        .limit(20000);
    final provedoresRaw = await _supabase
        .from('abastecimentos_unificado')
        .select('provedor')
        .inFilter('posto_cnpj', variantes)
        .limit(20000);

    final idsClientes = <String>{
      for (final m in clientesRaw)
        if (m['empresa_id'] != null) m['empresa_id'] as String,
    }.toList();
    List<({String id, String nome})> clientesOpcoes = [];
    if (idsClientes.isNotEmpty) {
      final empresasRaw =
          await _supabase.from('empresas').select('id, nome').inFilter('id', idsClientes);
      clientesOpcoes = empresasRaw
          .map((m) => (id: m['id'] as String, nome: m['nome'] as String? ?? '—'))
          .toList()
        ..sort((a, b) => a.nome.compareTo(b.nome));
    }
    final provedoresOpcoes = <String>{
      for (final m in provedoresRaw)
        if (m['provedor'] != null) m['provedor'] as String,
    }.toList()
      ..sort((a, b) => nomeProvedor(a).compareTo(nomeProvedor(b)));

    // Se o campo de busca livre bater com nome de cliente, inclui os
    // empresa_id encontrados no filtro OR abaixo (mesma ideia da web).
    List<String> idsClientesQ = [];
    final termo = filtros.q?.trim();
    if (termo != null && termo.isNotEmpty) {
      final match =
          await _supabase.from('empresas').select('id').ilike('nome', '%$termo%').limit(200);
      idsClientesQ = match.map((m) => m['id'] as String).toList();
    }

    PostgrestFilterBuilder<T> aplicar<T>(PostgrestFilterBuilder<T> query) {
      var q = query.inFilter('posto_cnpj', variantes);
      if (filtros.combustivel != null) q = q.eq('produto', filtros.combustivel!);
      if (filtros.clienteId != null) q = q.eq('empresa_id', filtros.clienteId!);
      if (filtros.provedor != null) q = q.eq('provedor', filtros.provedor!);
      if (termo != null && termo.isNotEmpty) {
        final clausulas = [
          'placa.ilike.%$termo%',
          'motorista_nome.ilike.%$termo%',
          'codigo_abastecimento.ilike.%$termo%',
        ];
        if (idsClientesQ.isNotEmpty) clausulas.add('empresa_id.in.(${idsClientesQ.join(",")})');
        q = q.or(clausulas.join(','));
      }
      if (filtros.de != null && filtros.de!.isNotEmpty) q = q.gte('data_abastecimento', filtros.de!);
      if (filtros.ate != null && filtros.ate!.isNotEmpty) {
        q = q.lte('data_abastecimento', '${filtros.ate}T23:59:59');
      }
      return q;
    }

    final contagemResp =
        await aplicar(_supabase.from('abastecimentos_unificado').select('id')).count(CountOption.exact);
    final total = contagemResp.count;

    final agregadosRaw =
        await aplicar(_supabase.from('abastecimentos_unificado').select('litros, valor_total')).limit(50000);
    var volumeTotal = 0.0;
    var receitaTotal = 0.0;
    for (final r in agregadosRaw) {
      volumeTotal += (r['litros'] as num?)?.toDouble() ?? 0;
      receitaTotal += (r['valor_total'] as num?)?.toDouble() ?? 0;
    }

    final paginaRaw = await aplicar(_supabase.from('abastecimentos_unificado').select(
          'id, provedor, codigo_abastecimento, data_abastecimento, empresa_id, placa, motorista_nome, produto, litros, valor_total',
        ))
        .order('data_abastecimento', ascending: false)
        .limit(limite);
    final registros = paginaRaw.map((m) => RegistroAbastecimentoPosto.fromMap(m)).toList();

    // NF-e emitida/rejeitada + ajuste pendente por linha — mesmas 3 tabelas
    // já usadas na web (RLS própria por empresa_posto_id). Só cobre a
    // página atual (ids visíveis), não a base inteira — suficiente pros
    // badges de cada linha.
    //
    // `abastecimento_externo_id` (nas 3 tabelas abaixo) aponta pra
    // `abastecimentos_externos.id`, que é uma sequência ÚNICA e
    // compartilhada por TODOS os provedores externos (Valecard/RedeFrota/
    // TicketLog/Veloe são só valores diferentes da coluna `provedor` na
    // MESMA tabela) — diferente de `abastecimento_id` (profrotas), que é
    // uma tabela/sequência à parte e pode colidir numericamente com o id
    // externo. Por isso: monta um mapa "id externo -> registro real desta
    // página" (não precisa adivinhar o provedor), e o profrotas usa a
    // chave "profrotas:id" direto.
    final registroPorIdExterno = <String, RegistroAbastecimentoPosto>{
      for (final r in registros)
        if (r.provedor != 'profrotas') r.id: r,
    };
    final notaPorAbastecimento = <String, String?>{};
    final pendenciaPorAbastecimento = <String, String>{};
    final comAjustePendente = <String>{};

    if (registros.isNotEmpty) {
      final notasRaw = await _supabase
          .from('notas_fiscais_abastecimento')
          .select('abastecimento_id, abastecimento_externo_id, numero_nf')
          .eq('empresa_posto_id', empresaPostoId)
          .limit(20000);
      final pendenciasRaw = await _supabase
          .from('notas_fiscais_pendencias')
          .select('abastecimento_id, abastecimento_externo_id, motivo')
          .eq('empresa_posto_id', empresaPostoId)
          .limit(20000);
      final ajustesRaw = await _supabase
          .from('ajustes_abastecimentos')
          .select('abastecimento_id, abastecimento_externo_id')
          .eq('empresa_posto_id', empresaPostoId)
          .inFilter('status', ['pendente_cliente', 'pendente_posto']);

      for (final n in notasRaw) {
        final idProfrotas = n['abastecimento_id'];
        final idExterno = n['abastecimento_externo_id'];
        final numero = n['numero_nf'] as String?;
        if (idProfrotas != null) notaPorAbastecimento.putIfAbsent('profrotas:$idProfrotas', () => numero);
        final registroExterno = idExterno != null ? registroPorIdExterno[idExterno.toString()] : null;
        if (registroExterno != null) notaPorAbastecimento.putIfAbsent(registroExterno.chave, () => numero);
      }
      for (final p in pendenciasRaw) {
        final idProfrotas = p['abastecimento_id'];
        final idExterno = p['abastecimento_externo_id'];
        final motivo = _motivoLabel[p['motivo']] ?? 'NF-e rejeitada.';
        if (idProfrotas != null) {
          final chave = 'profrotas:$idProfrotas';
          if (!notaPorAbastecimento.containsKey(chave)) pendenciaPorAbastecimento.putIfAbsent(chave, () => motivo);
        }
        final registroExterno = idExterno != null ? registroPorIdExterno[idExterno.toString()] : null;
        if (registroExterno != null && !notaPorAbastecimento.containsKey(registroExterno.chave)) {
          pendenciaPorAbastecimento.putIfAbsent(registroExterno.chave, () => motivo);
        }
      }
      for (final a in ajustesRaw) {
        final idProfrotas = a['abastecimento_id'];
        final idExterno = a['abastecimento_externo_id'];
        if (idProfrotas != null) comAjustePendente.add('profrotas:$idProfrotas');
        final registroExterno = idExterno != null ? registroPorIdExterno[idExterno.toString()] : null;
        if (registroExterno != null) comAjustePendente.add(registroExterno.chave);
      }
    }

    return ResultadoAbastecimentosPosto(
      registros: registros,
      total: total,
      volumeTotal: volumeTotal,
      receitaTotal: receitaTotal,
      clientesOpcoes: clientesOpcoes,
      provedoresOpcoes: provedoresOpcoes,
      notaPorAbastecimento: notaPorAbastecimento,
      pendenciaPorAbastecimento: pendenciaPorAbastecimento,
      comAjustePendente: comAjustePendente,
    );
  }
}
