import '../../../core/services/supabase_service.dart';
import '../../../core/utils/sha256.dart';

// Fase FLT-Conciliação-Bancária (02/09/2026, pedido do Daniel: "equalizar
// o PWA Cliente com as funcionalidades construídas para a web cliente") —
// porta de conciliacao-bancaria/page.tsx + actions.ts +
// src/lib/conciliacaoBancaria.ts. Todo o parsing de OFX/CSV e o algoritmo
// de sugestão (sugerirContas) é lógica pura, replicada aqui 1:1 (mesmos
// critérios: valor exato, janela de 15 dias, similaridade de nome por
// tokens). Sem RPC própria de matching — só reaproveita as RPCs de baixa
// já existentes (baixar_conta_pagar/baixar_conta_receber, as mesmas
// usadas em /financeiro).
const _janelaDiasSugestao = 15;

class LancamentoExtrato {
  final String id;
  final String empresaId;
  final String data;
  final String descricao;
  final double valor;
  final String tipo; // credito | debito
  final String? contaBancaria;
  final String status; // pendente | conciliado | ignorado
  final String? conciliadoComTipo;
  final String? conciliadoComId;
  final String? conciliadoEm;
  final String? conciliadoPor;

  const LancamentoExtrato({
    required this.id,
    required this.empresaId,
    required this.data,
    required this.descricao,
    required this.valor,
    required this.tipo,
    required this.contaBancaria,
    required this.status,
    required this.conciliadoComTipo,
    required this.conciliadoComId,
    required this.conciliadoEm,
    required this.conciliadoPor,
  });

  factory LancamentoExtrato.fromMap(Map<String, dynamic> m) =>
      LancamentoExtrato(
        id: m['id'] as String,
        empresaId: m['empresa_id'] as String,
        data: m['data'] as String,
        descricao: m['descricao'] as String,
        valor: (m['valor'] as num).toDouble(),
        tipo: m['tipo'] as String,
        contaBancaria: m['conta_bancaria'] as String?,
        status: m['status'] as String,
        conciliadoComTipo: m['conciliado_com_tipo'] as String?,
        conciliadoComId: m['conciliado_com_id'] as String?,
        conciliadoEm: m['conciliado_em'] as String?,
        conciliadoPor: m['conciliado_por'] as String?,
      );
}

class ContaEmAberto {
  final String id;
  final String tipo; // contas_pagar | contas_receber
  final String nome; // credor_nome ou devedor_nome
  final String descricao;
  final double valorOriginal;
  final double valorPago;
  final String vencimento;

  const ContaEmAberto({
    required this.id,
    required this.tipo,
    required this.nome,
    required this.descricao,
    required this.valorOriginal,
    required this.valorPago,
    required this.vencimento,
  });

  double get saldoEmAberto => valorOriginal - valorPago;
}

class SugestaoConta {
  final ContaEmAberto conta;
  final String confianca; // alta | media | baixa
  final int diferencaDias;
  final double similaridadeNome;

  const SugestaoConta({
    required this.conta,
    required this.confianca,
    required this.diferencaDias,
    required this.similaridadeNome,
  });
}

class ConciliacaoBancariaService {
  final _supabase = SupabaseService.client;

  // ── Parsing de extrato ────────────────────────────────────────────────

  List<Map<String, dynamic>> parseExtrato(String nomeArquivo, String texto) {
    final ehOfx = nomeArquivo.toLowerCase().endsWith('.ofx') ||
        RegExp(r'<OFX>|<STMTTRN>', caseSensitive: false)
            .hasMatch(texto.substring(0, texto.length > 2000 ? 2000 : texto.length));
    return ehOfx ? _parseOfx(texto) : _parseCsv(texto);
  }

  List<Map<String, dynamic>> _parseOfx(String texto) {
    final resultado = <Map<String, dynamic>>[];
    final blocos = RegExp(r'<STMTTRN>([\s\S]*?)<\/STMTTRN>', caseSensitive: false)
        .allMatches(texto);
    for (final bloco in blocos) {
      final trecho = bloco.group(1) ?? '';
      final dtPosted =
          RegExp(r'<DTPOSTED>([^\s<]+)', caseSensitive: false)
              .firstMatch(trecho)
              ?.group(1);
      final trnAmt = RegExp(r'<TRNAMT>([^\s<]+)', caseSensitive: false)
          .firstMatch(trecho)
          ?.group(1);
      final memo = RegExp(r'<MEMO>([^\n<]+)', caseSensitive: false)
              .firstMatch(trecho)
              ?.group(1) ??
          RegExp(r'<NAME>([^\n<]+)', caseSensitive: false)
              .firstMatch(trecho)
              ?.group(1);
      if (dtPosted == null || trnAmt == null || dtPosted.length < 8) continue;
      final dataIso =
          '${dtPosted.substring(0, 4)}-${dtPosted.substring(4, 6)}-${dtPosted.substring(6, 8)}';
      final valor = double.tryParse(trnAmt.replaceAll(',', '.'));
      if (valor == null || valor == 0) continue;
      resultado.add({
        'data': dataIso,
        'descricao': (memo ?? '').trim().isEmpty ? '(sem descrição)' : memo!.trim(),
        'valor': valor,
        'tipo': valor < 0 ? 'debito' : 'credito',
      });
    }
    return resultado;
  }

  List<Map<String, dynamic>> _parseCsv(String texto) {
    final linhas = texto
        .split(RegExp(r'\r\n|\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (linhas.isEmpty) return [];
    final sep = linhas.first.contains(';') ? ';' : ',';
    final cabecalho =
        linhas.first.split(sep).map((h) => _normalizar(h)).toList();

    int? achar(List<String> alvos) {
      for (final alvo in alvos) {
        final idx = cabecalho.indexOf(alvo);
        if (idx >= 0) return idx;
      }
      return null;
    }

    final idxData = achar(['data', 'data lancamento', 'dt', 'date']);
    final idxDescricao = achar(
        ['descricao', 'historico', 'memo', 'lancamento']);
    final idxValor = achar(['valor', 'valor (r\$)', 'amount', 'vlr']);
    if (idxData == null || idxDescricao == null || idxValor == null) {
      return [];
    }

    final resultado = <Map<String, dynamic>>[];
    for (final linha in linhas.skip(1)) {
      final campos = linha.split(sep);
      if (campos.length <= [idxData, idxDescricao, idxValor].reduce((a, b) => a > b ? a : b)) {
        continue;
      }
      final dataTexto = campos[idxData].trim();
      final descricao = campos[idxDescricao].trim();
      var valorTexto = campos[idxValor].trim().replaceAll('R\$', '').trim();
      if (valorTexto.contains(',')) {
        valorTexto = valorTexto.replaceAll('.', '').replaceAll(',', '.');
      }
      final valor = double.tryParse(valorTexto);
      final dataIso = _paraIso(dataTexto);
      if (valor == null || valor == 0 || dataIso == null) continue;
      resultado.add({
        'data': dataIso,
        'descricao': descricao.isEmpty ? '(sem descrição)' : descricao,
        'valor': valor,
        'tipo': valor < 0 ? 'debito' : 'credito',
      });
    }
    return resultado;
  }

  String? _paraIso(String texto) {
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(texto)) return texto;
    final m = RegExp(r'^(\d{2})\/(\d{2})\/(\d{4})$').firstMatch(texto);
    if (m != null) return '${m.group(3)}-${m.group(2)}-${m.group(1)}';
    return null;
  }

  String _normalizar(String texto) => texto
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[áàâã]'), 'a')
      .replaceAll(RegExp(r'[éê]'), 'e')
      .replaceAll('í', 'i')
      .replaceAll(RegExp(r'[óôõ]'), 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c');

  String calcularHashDedupe({
    required String empresaId,
    required String data,
    required double valor,
    required String descricao,
  }) {
    final descNormalizada =
        descricao.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final texto =
        '$empresaId|$data|${valor.toStringAsFixed(2)}|$descNormalizada';
    return sha256Hex(texto);
  }

  // ── Import ─────────────────────────────────────────────────────────

  Future<({int novos, int duplicados, String? erro})> importar({
    required String empresaId,
    required String nomeArquivo,
    required String conteudo,
  }) async {
    final linhas = parseExtrato(nomeArquivo, conteudo);
    if (linhas.isEmpty) {
      return (novos: 0, duplicados: 0, erro: 'Nenhum lançamento reconhecido no arquivo.');
    }
    final email = _supabase.auth.currentUser?.email;
    final comHash = linhas
        .map((l) => {
              ...l,
              'hash_dedupe': calcularHashDedupe(
                empresaId: empresaId,
                data: l['data'] as String,
                valor: l['valor'] as double,
                descricao: l['descricao'] as String,
              ),
            })
        .toList();
    final hashes = comHash.map((l) => l['hash_dedupe'] as String).toSet();
    List<dynamic> existentes;
    try {
      existentes = await _supabase
          .from('extrato_bancario_lancamentos')
          .select('hash_dedupe')
          .eq('empresa_id', empresaId)
          .inFilter('hash_dedupe', hashes.toList());
    } catch (e) {
      return (novos: 0, duplicados: 0, erro: 'Não foi possível checar duplicados: $e');
    }
    final hashesExistentes =
        existentes.map((m) => m['hash_dedupe'] as String).toSet();
    final inditos =
        comHash.where((l) => !hashesExistentes.contains(l['hash_dedupe'])).toList();
    if (inditos.isEmpty) {
      return (novos: 0, duplicados: comHash.length, erro: null);
    }
    try {
      await _supabase.from('extrato_bancario_lancamentos').insert(inditos
          .map((l) => {
                'empresa_id': empresaId,
                'data': l['data'],
                'descricao': l['descricao'],
                'valor': l['valor'],
                'tipo': l['tipo'],
                'hash_dedupe': l['hash_dedupe'],
                'status': 'pendente',
                'arquivo_origem': nomeArquivo,
                'importado_por': email,
              })
          .toList());
      return (novos: inditos.length, duplicados: comHash.length - inditos.length, erro: null);
    } catch (e) {
      return (novos: 0, duplicados: 0, erro: 'Não foi possível salvar: $e');
    }
  }

  // ── Busca ──────────────────────────────────────────────────────────

  Future<List<LancamentoExtrato>> buscarLancamentos(String empresaId) async {
    final rows = await _supabase
        .from('extrato_bancario_lancamentos')
        .select(
          'id, empresa_id, data, descricao, valor, tipo, conta_bancaria, status, conciliado_com_tipo, conciliado_com_id, conciliado_em, conciliado_por',
        )
        .eq('empresa_id', empresaId)
        .order('data', ascending: false)
        .limit(1000);
    return rows.map((m) => LancamentoExtrato.fromMap(m)).toList();
  }

  Future<List<ContaEmAberto>> buscarContasEmAberto(String empresaId) async {
    final pagar = await _supabase
        .from('contas_pagar')
        .select('id, credor_nome, descricao, valor_original, valor_pago, vencimento')
        .eq('empresa_id', empresaId)
        .inFilter('status', ['aberto', 'baixado_parcial']);
    final receber = await _supabase
        .from('contas_receber')
        .select('id, devedor_nome, descricao, valor_original, valor_pago, vencimento')
        .eq('empresa_id', empresaId)
        .inFilter('status', ['aberto', 'baixado_parcial']);
    return [
      ...pagar.map((m) => ContaEmAberto(
            id: m['id'] as String,
            tipo: 'contas_pagar',
            nome: m['credor_nome'] as String? ?? '',
            descricao: m['descricao'] as String? ?? '',
            valorOriginal: (m['valor_original'] as num).toDouble(),
            valorPago: (m['valor_pago'] as num?)?.toDouble() ?? 0,
            vencimento: m['vencimento'] as String,
          )),
      ...receber.map((m) => ContaEmAberto(
            id: m['id'] as String,
            tipo: 'contas_receber',
            nome: m['devedor_nome'] as String? ?? '',
            descricao: m['descricao'] as String? ?? '',
            valorOriginal: (m['valor_original'] as num).toDouble(),
            valorPago: (m['valor_pago'] as num?)?.toDouble() ?? 0,
            vencimento: m['vencimento'] as String,
          )),
    ];
  }

  // ── Matching / sugestão ───────────────────────────────────────────

  List<SugestaoConta> sugerirContas(
      LancamentoExtrato lancamento, List<ContaEmAberto> contas,
      {int limite = 3}) {
    final tipoAlvo =
        lancamento.tipo == 'debito' ? 'contas_pagar' : 'contas_receber';
    final valorAbs = lancamento.valor.abs();
    final dataLancamento = DateTime.tryParse(lancamento.data);
    if (dataLancamento == null) return [];

    final candidatas = <SugestaoConta>[];
    for (final conta in contas) {
      if (conta.tipo != tipoAlvo) continue;
      if ((conta.saldoEmAberto - valorAbs).abs() >= 0.01) continue;
      final vencimento = DateTime.tryParse(conta.vencimento);
      if (vencimento == null) continue;
      final diferencaDias =
          dataLancamento.difference(vencimento).inDays.abs();
      if (diferencaDias > _janelaDiasSugestao) continue;
      final similaridade = _similaridadeNomes(lancamento.descricao, conta.nome);
      final confianca = _calcularConfianca(diferencaDias, similaridade);
      candidatas.add(SugestaoConta(
        conta: conta,
        confianca: confianca,
        diferencaDias: diferencaDias,
        similaridadeNome: similaridade,
      ));
    }
    const ordem = {'alta': 0, 'media': 1, 'baixa': 2};
    candidatas.sort((a, b) {
      final c = ordem[a.confianca]!.compareTo(ordem[b.confianca]!);
      if (c != 0) return c;
      return a.diferencaDias.compareTo(b.diferencaDias);
    });
    return candidatas.take(limite).toList();
  }

  String _calcularConfianca(int diferencaDias, double similaridadeNome) {
    if (diferencaDias <= 3 && similaridadeNome >= 0.5) return 'alta';
    if (diferencaDias <= 7 || similaridadeNome >= 0.3) return 'media';
    return 'baixa';
  }

  double _similaridadeNomes(String descricaoExtrato, String nomeConta) {
    final descNorm = _normalizarNome(descricaoExtrato);
    final nomeNorm = _normalizarNome(nomeConta);
    final tokens = nomeNorm
        .split(' ')
        .where((t) => t.replaceAll(RegExp(r'[^a-z]'), '').length >= 3)
        .toList();
    if (tokens.isEmpty) return 0;
    final encontrados = tokens.where((t) => descNorm.contains(t)).length;
    return encontrados / tokens.length;
  }

  String _normalizarNome(String texto) {
    var t = _normalizar(texto);
    t = t.replaceAll(
        RegExp(r'\b(ltda|me|eireli|s\/a|epp|mei)\b'), '');
    t = t.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  // ── Ações ──────────────────────────────────────────────────────────

  Future<String?> conciliarManual({
    required String lancamentoId,
    required String contaTipo,
    required String contaId,
    required double valorLancamento,
    required double saldoConta,
  }) async {
    final valorBaixa =
        valorLancamento.abs() < saldoConta ? valorLancamento.abs() : saldoConta;
    try {
      if (contaTipo == 'contas_pagar') {
        await _supabase.rpc('baixar_conta_pagar', params: {
          'p_conta_id': contaId,
          'p_valor': valorBaixa,
          'p_forma': 'conciliacao_bancaria',
          'p_observacao': 'Conciliado manualmente via conferência de extrato.',
        });
      } else {
        await _supabase.rpc('baixar_conta_receber', params: {
          'p_conta_id': contaId,
          'p_valor': valorBaixa,
          'p_forma': 'conciliacao_bancaria',
          'p_gateway_ref': null,
          'p_observacao': 'Conciliado manualmente via conferência de extrato.',
        });
      }
      final email = _supabase.auth.currentUser?.email;
      await _supabase.from('extrato_bancario_lancamentos').update({
        'status': 'conciliado',
        'conciliado_com_tipo': contaTipo,
        'conciliado_com_id': contaId,
        'conciliado_em': DateTime.now().toUtc().toIso8601String(),
        'conciliado_por': email,
      }).eq('id', lancamentoId);
      return null;
    } catch (e) {
      return 'Não foi possível conciliar: $e';
    }
  }

  Future<({int conciliados, int erros})> conciliarAutomatico(
      String empresaId) async {
    final pendentes = (await buscarLancamentos(empresaId))
        .where((l) => l.status == 'pendente')
        .toList();
    final contas = await buscarContasEmAberto(empresaId);
    var conciliados = 0;
    var erros = 0;
    for (final lancamento in pendentes) {
      final sugestoes = sugerirContas(lancamento, contas);
      final altas = sugestoes.where((s) => s.confianca == 'alta').toList();
      if (altas.length != 1) continue;
      final sugestao = altas.first;
      final erro = await conciliarManual(
        lancamentoId: lancamento.id,
        contaTipo: sugestao.conta.tipo,
        contaId: sugestao.conta.id,
        valorLancamento: lancamento.valor,
        saldoConta: sugestao.conta.saldoEmAberto,
      );
      if (erro == null) {
        conciliados++;
      } else {
        erros++;
      }
    }
    return (conciliados: conciliados, erros: erros);
  }

  Future<String?> ignorar(String id) async {
    try {
      await _supabase
          .from('extrato_bancario_lancamentos')
          .update({'status': 'ignorado'}).eq('id', id);
      return null;
    } catch (e) {
      return 'Não foi possível ignorar: $e';
    }
  }

  Future<String?> reabrir(String id) async {
    try {
      await _supabase.from('extrato_bancario_lancamentos').update({
        'status': 'pendente',
        'conciliado_com_tipo': null,
        'conciliado_com_id': null,
        'conciliado_em': null,
        'conciliado_por': null,
      }).eq('id', id);
      return null;
    } catch (e) {
      return 'Não foi possível reabrir: $e';
    }
  }

  Future<String?> excluir(String id) async {
    try {
      await _supabase.from('extrato_bancario_lancamentos').delete().eq('id', id);
      return null;
    } catch (e) {
      return 'Não foi possível excluir: $e';
    }
  }
}
