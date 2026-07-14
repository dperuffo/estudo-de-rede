import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — porta fiel de src/lib/ajustesAbastecimentos.ts (funções
// criarSolicitacaoAjuste/adicionarContrapropostaAjuste/decidirAjuste/
// cancelarAjuste) pro Flutter. Mesma máquina de estados de
// negociacoes_service.dart (cabeçalho + rodadas, turno alternado), com uma
// diferença chave: quando aceito, os campos propostos são de fato
// aplicados no abastecimento (não é só "fotografado"), por isso
// `decidirAjuste` chama a RPC SECURITY DEFINER `decidir_ajuste_abastecimento`
// em vez de um UPDATE direto.
//
// Diferente da web (que serve os dois lados e precisa RESOLVER quem é
// posto/cliente por CNPJ), aqui já sabemos o lado por contexto — cada tela
// que usa esta classe passa o próprio "empresaId" certo. "autor"/"meuLado"
// era sempre "posto" (única tela existente até a Fase FLT-2); a Fase FLT-3
// (Abastecimentos do cliente) reaproveita esta MESMA classe pro lado
// cliente — ganhou um parâmetro opcional `autor` (default `'posto'`,
// preserva 100% o comportamento original) usado em
// criarSolicitacaoAjuste/adicionarContraproposta pra decidir o status
// seguinte (o "turno" da outra parte) e quem assina a rodada.

class IdentificadorAbastecimento {
  final String tipo; // 'profrotas' | 'externo'
  final int id;
  const IdentificadorAbastecimento({required this.tipo, required this.id});
}

class CamposAjuste {
  final String? dataAbastecimento;
  final double? hodometro;
  final String? itemNome;
  final double? itemQuantidade;
  final double? itemValorUnitario;
  final double? itemValorTotal;

  const CamposAjuste({
    this.dataAbastecimento,
    this.hodometro,
    this.itemNome,
    this.itemQuantidade,
    this.itemValorUnitario,
    this.itemValorTotal,
  });

  bool get vazio =>
      dataAbastecimento == null &&
      hodometro == null &&
      itemNome == null &&
      itemQuantidade == null &&
      itemValorUnitario == null &&
      itemValorTotal == null;

  Map<String, dynamic> toMap() => {
        if (dataAbastecimento != null) 'data_abastecimento': dataAbastecimento,
        if (hodometro != null) 'hodometro': hodometro,
        if (itemNome != null) 'item_nome': itemNome,
        if (itemQuantidade != null) 'item_quantidade': itemQuantidade,
        if (itemValorUnitario != null) 'item_valor_unitario': itemValorUnitario,
        if (itemValorTotal != null) 'item_valor_total': itemValorTotal,
      };
}

String? validarCamposAjuste(CamposAjuste campos) {
  if (campos.vazio) return 'Preencha ao menos um campo para propor o ajuste.';
  if (campos.hodometro != null && campos.hodometro! < 0) return 'Hodômetro inválido.';
  if (campos.itemQuantidade != null && campos.itemQuantidade! <= 0) return 'Litros inválido.';
  if (campos.itemValorUnitario != null && campos.itemValorUnitario! <= 0) {
    return 'Preço por litro inválido.';
  }
  if (campos.itemValorTotal != null && campos.itemValorTotal! <= 0) return 'Valor total inválido.';
  if (campos.dataAbastecimento != null && DateTime.tryParse(campos.dataAbastecimento!) == null) {
    return 'Data/hora inválida.';
  }
  return null;
}

class AjustesAbastecimentosService {
  final _supabase = SupabaseService.client;

  String get _meuEmail => AuthService().emailAtual ?? '';

  Future<String?> criarSolicitacaoAjuste({
    required IdentificadorAbastecimento identificador,
    required String empresaClienteId,
    required String empresaPostoId,
    required CamposAjuste campos,
    String? motivo,
    double? valorOriginal,
    String autor = 'posto',
  }) async {
    final erroValidacao = validarCamposAjuste(campos);
    if (erroValidacao != null) return erroValidacao;

    final statusInicial = autor == 'posto' ? 'pendente_cliente' : 'pendente_posto';

    try {
      final ajuste = await _supabase
          .from('ajustes_abastecimentos')
          .insert({
            'abastecimento_id': identificador.tipo == 'profrotas' ? identificador.id : null,
            'abastecimento_externo_id': identificador.tipo == 'externo' ? identificador.id : null,
            'empresa_cliente_id': empresaClienteId,
            'empresa_posto_id': empresaPostoId,
            'origem': autor,
            'status': statusInicial,
            'rodada_atual': 1,
            'criado_por': _meuEmail,
            'atualizado_por': _meuEmail,
            'valor_original': valorOriginal,
          })
          .select('id')
          .single();

      await _supabase.from('ajustes_abastecimentos_rodadas').insert({
        'ajuste_id': ajuste['id'],
        'numero_rodada': 1,
        'autor': autor,
        'motivo': motivo,
        'decisao': 'pendente',
        ...campos.toMap(),
      });
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        return 'Já existe uma solicitação de ajuste em aberto para este abastecimento.';
      }
      return e.message;
    }
  }

  Future<String?> adicionarContraproposta({
    required String ajusteId,
    required CamposAjuste campos,
    String? motivo,
    String autor = 'posto',
  }) async {
    final erroValidacao = validarCamposAjuste(campos);
    if (erroValidacao != null) return erroValidacao;

    final meuTurno = autor == 'posto' ? 'pendente_posto' : 'pendente_cliente';
    final proximoTurno = autor == 'posto' ? 'pendente_cliente' : 'pendente_posto';

    try {
      final ajuste = await _supabase
          .from('ajustes_abastecimentos')
          .select('id, status, rodada_atual')
          .eq('id', ajusteId)
          .maybeSingle();
      if (ajuste == null) return 'Solicitação de ajuste não encontrada.';
      final status = ajuste['status'] as String;
      if (status == 'aceito' || status == 'recusado' || status == 'cancelado') {
        return 'Esta solicitação já foi encerrada e não aceita novas rodadas.';
      }
      if (status != meuTurno) return 'Não é a sua vez de responder esta solicitação.';

      final rodadaAtual = (ajuste['rodada_atual'] as num).toInt();
      final novaRodada = rodadaAtual + 1;
      final agora = DateTime.now().toUtc().toIso8601String();

      await _supabase
          .from('ajustes_abastecimentos_rodadas')
          .update({'decisao': 'contraproposta', 'decidido_em': agora, 'decidido_por': _meuEmail})
          .eq('ajuste_id', ajusteId)
          .eq('numero_rodada', rodadaAtual);

      await _supabase.from('ajustes_abastecimentos_rodadas').insert({
        'ajuste_id': ajusteId,
        'numero_rodada': novaRodada,
        'autor': autor,
        'motivo': motivo,
        'decisao': 'pendente',
        ...campos.toMap(),
      });

      await _supabase.from('ajustes_abastecimentos').update({
        'status': proximoTurno,
        'rodada_atual': novaRodada,
        'atualizado_em': agora,
        'atualizado_por': _meuEmail,
      }).eq('id', ajusteId);

      return null;
    } on PostgrestException catch (e) {
      return e.message;
    }
  }

  Future<String?> decidirAjuste({required String ajusteId, required bool aceitar}) async {
    try {
      await _supabase.rpc('decidir_ajuste_abastecimento', params: {
        'p_ajuste_id': ajusteId,
        'p_decisao': aceitar ? 'aceita' : 'recusada',
        'p_decidido_por': _meuEmail,
      });
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    }
  }

  Future<String?> cancelarAjuste(String ajusteId) async {
    try {
      await _supabase
          .from('ajustes_abastecimentos')
          .update({
            'status': 'cancelado',
            'atualizado_em': DateTime.now().toUtc().toIso8601String(),
            'atualizado_por': _meuEmail,
          })
          .eq('id', ajusteId)
          .inFilter('status', ['pendente_posto', 'pendente_cliente']);
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    }
  }
}
