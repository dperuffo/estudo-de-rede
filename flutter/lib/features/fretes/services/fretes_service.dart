import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import 'cte_parser.dart';

// Fase PWA-Fretes — porta manual de fretes/actions.ts (mesmo aviso já dado
// nos outros *_service.dart deste app: sem RPC pra criação/cancelamento —
// é regra de negócio replicada à mão, segurança de verdade vem da RLS).
class FretesService {
  final _supabase = SupabaseService.client;

  Future<String?> criarFrete({
    required String empresaId,
    required String titulo,
    String? descricao,
    required String origemLabel,
    required double origemLat,
    required double origemLon,
    required String destinoLabel,
    required double destinoLat,
    required double destinoLon,
    String? tipoCarga,
    double? pesoCargaKg,
    String? dataSaidaPrevista,
    String? prazoEntrega,
    double? kmEstimado,
    required double valorOferecido,
    String? motoristaId,
    // Fase Fretes-Dados-Completos — pedido do Daniel: motorista precisa de
    // endereço completo, horário e dimensões pra decidir se aceita o frete.
    double? cargaComprimentoM,
    double? cargaLarguraM,
    double? cargaAlturaM,
    Map<String, String?>? coleta,
    Map<String, String?>? entrega,
    List<String> veiculosAceitos = const [],
    List<String> carroceriasAceitas = const [],
    // Fase Fretes-Adiantamento-Combustível (19/07) — pedido do Daniel:
    // entrada/saldo final (default 30/70, geradas automaticamente pelo
    // banco quando o frete é aceito) e reserva opcional de combustível
    // (consumida antes da cota do veículo — ver alocar_abastecimento_saldo).
    double percentualAdiantamento = 30,
    String? saldoCombustivelTipo,
    double? saldoCombustivelAlocado,
  }) async {
    if (titulo.trim().isEmpty) return 'Título é obrigatório.';
    if (valorOferecido <= 0) return 'Informe um valor de frete válido.';
    if (percentualAdiantamento < 0 || percentualAdiantamento > 100) {
      return 'Percentual de adiantamento precisa estar entre 0 e 100.';
    }
    if (saldoCombustivelTipo != null && (saldoCombustivelAlocado == null || saldoCombustivelAlocado <= 0)) {
      return 'Informe um valor válido pra reserva de combustível.';
    }

    // Gestão de Fretes é exclusiva do plano Enterprise (com exceção do
    // período de trial) — pedido do Daniel (18/07), mesma regra de
    // verificarAcessoFretes em src/lib/limitePlano.ts (Next.js). A trava de
    // verdade é a policy RESTRICTIVE fretes_insere_somente_enterprise_ou_
    // trial na RLS (protege este app E o painel web); esta checagem aqui é
    // só pra devolver mensagem amigável antes de bater na RLS.
    final empresa = await _supabase
        .from('empresas')
        .select('plano, status')
        .eq('id', empresaId)
        .maybeSingle();
    final plano = empresa?['plano'] as String?;
    final status = empresa?['status'] as String?;
    if (empresa != null && plano != 'enterprise' && status != 'trial') {
      return 'Gestão de Fretes é exclusiva do plano Enterprise (ou liberada durante o período de trial). '
          'Faça upgrade em Minha Assinatura para publicar novos fretes.';
    }

    // Modo direto exige que o motorista escolhido seja próprio ou parceiro
    // ativo — mesma checagem de empresaPertenceAoUsuario/criarFrete da web
    // (a RLS não valida isso sozinha, motorista_id é só uma FK solta).
    if (motoristaId != null) {
      final proprio = await _supabase
          .from('motoristas')
          .select('id')
          .eq('id', motoristaId)
          .eq('empresa_id', empresaId)
          .maybeSingle();
      if (proprio == null) {
        final parceiro = await _supabase
            .from('empresas_motoristas_parceiros')
            .select('id')
            .eq('empresa_id', empresaId)
            .eq('motorista_id', motoristaId)
            .eq('status', 'ativo')
            .maybeSingle();
        if (parceiro == null) return 'Esse motorista não é da sua empresa nem um parceiro ativo.';
      }
    }

    try {
      await _supabase.from('fretes').insert({
        'empresa_id': empresaId,
        'titulo': titulo.trim(),
        'descricao': descricao?.trim().isEmpty == true ? null : descricao?.trim(),
        'origem_label': origemLabel,
        'origem_lat': origemLat,
        'origem_lon': origemLon,
        'destino_label': destinoLabel,
        'destino_lat': destinoLat,
        'destino_lon': destinoLon,
        'tipo_carga': tipoCarga?.trim().isEmpty == true ? null : tipoCarga?.trim(),
        'peso_carga_kg': pesoCargaKg,
        // data_saida_prevista/prazo_entrega (colunas antigas, só data) ficam
        // preenchidas a partir da coleta/entrega novas quando não vierem
        // explícitas — quem ainda lê essas colunas não fica sem nada.
        'data_saida_prevista': dataSaidaPrevista ?? coleta?['data'],
        'prazo_entrega': prazoEntrega ?? entrega?['data'],
        'km_estimado': kmEstimado,
        'valor_oferecido': valorOferecido,
        'motorista_id': motoristaId,
        'status': motoristaId != null ? 'aguardando_confirmacao' : 'disponivel',
        'criado_por': AuthService().emailAtual,
        'carga_comprimento_m': cargaComprimentoM,
        'carga_largura_m': cargaLarguraM,
        'carga_altura_m': cargaAlturaM,
        'coleta_rua': coleta?['rua'],
        'coleta_numero': coleta?['numero'],
        'coleta_bairro': coleta?['bairro'],
        'coleta_cidade': coleta?['cidade'],
        'coleta_uf': coleta?['uf'],
        'coleta_cep': coleta?['cep'],
        'coleta_referencia': coleta?['referencia'],
        'coleta_data': coleta?['data'],
        'coleta_hora': coleta?['hora'],
        'coleta_contato_nome': coleta?['contato_nome'],
        'coleta_contato_telefone': coleta?['contato_telefone'],
        'entrega_rua': entrega?['rua'],
        'entrega_numero': entrega?['numero'],
        'entrega_bairro': entrega?['bairro'],
        'entrega_cidade': entrega?['cidade'],
        'entrega_uf': entrega?['uf'],
        'entrega_cep': entrega?['cep'],
        'entrega_referencia': entrega?['referencia'],
        'entrega_data': entrega?['data'],
        'entrega_hora': entrega?['hora'],
        'entrega_contato_nome': entrega?['contato_nome'],
        'entrega_contato_telefone': entrega?['contato_telefone'],
        'veiculos_aceitos': veiculosAceitos,
        'carrocerias_aceitas': carroceriasAceitas,
        'percentual_adiantamento': percentualAdiantamento,
        'saldo_combustivel_tipo': saldoCombustivelTipo,
        'saldo_combustivel_alocado': saldoCombustivelAlocado,
      });
      return null;
    } catch (e) {
      return 'Não foi possível publicar o frete: $e';
    }
  }

  // Fase Fretes-Adiantamento-Combustível (19/07) — confirma o pagamento de
  // uma parcela. A regra "saldo_final só após concluído" mora no banco
  // (marcar_pagamento_frete); aqui só repassa e traduz o erro.
  Future<String?> marcarPagamento({required String freteId, required String tipo}) async {
    try {
      await _supabase.rpc('marcar_pagamento_frete', params: {'p_frete_id': freteId, 'p_tipo': tipo});
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> cancelarFrete(String id) async {
    await _supabase.from('fretes').update({'status': 'cancelado', 'atualizado_em': DateTime.now().toIso8601String()}).eq('id', id);
  }

  Future<void> reabrirFreteParaMercado(String id) async {
    await _supabase
        .from('fretes')
        .update({'motorista_id': null, 'status': 'disponivel', 'atualizado_em': DateTime.now().toIso8601String()}).eq('id', id);
  }

  Future<String?> aceitarProposta(String negociacaoId) async {
    try {
      await _supabase.rpc('aceitar_negociacao_frete', params: {'p_negociacao_id': negociacaoId});
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> recusarProposta(String negociacaoId) async {
    try {
      await _supabase.rpc('recusar_negociacao_frete', params: {'p_negociacao_id': negociacaoId});
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> contraporProposta(String negociacaoId, double valor) async {
    if (valor <= 0) return 'Informe um valor válido.';
    try {
      await _supabase.rpc('propor_rodada_negociacao', params: {
        'p_negociacao_id': negociacaoId,
        'p_valor_proposto': valor,
        'p_mensagem': null,
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> adicionarPostoRecomendado({
    required String freteId,
    required String nomePosto,
    String? itemCatalogoId,
    String? observacao,
  }) async {
    if (nomePosto.trim().isEmpty) return 'Digite o nome do posto.';
    try {
      await _supabase.from('fretes_postos_recomendados').insert({
        'frete_id': freteId,
        'nome_posto': nomePosto.trim(),
        'item_catalogo_id': itemCatalogoId,
        'observacao': observacao?.trim().isEmpty == true ? null : observacao?.trim(),
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> removerPostoRecomendado(String id) async {
    await _supabase.from('fretes_postos_recomendados').delete().eq('id', id);
  }

  Future<String?> avaliarMotorista({
    required String freteId,
    required int estrelas,
    String? comentario,
    List<String> tags = const [],
  }) async {
    try {
      await _supabase.rpc('avaliar_frete', params: {
        'p_frete_id': freteId,
        'p_estrelas': estrelas,
        'p_comentario': (comentario == null || comentario.trim().isEmpty) ? null : comentario.trim(),
        'p_tags': tags,
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Fase Fretes-CIOT-CTe (18/07) — porta de documentosActions.ts (Next.js).
  // Nenhum dos dois é emitido por aqui, ver cte_parser.dart. A trava de
  // verdade continua sendo a RLS (fretes_cte_dono_empresa/fretes_ciot_dono_
  // empresa) — isto aqui só devolve mensagem amigável antes de bater nela.
  Future<String?> enviarCte({required String freteId, required String xmlTexto}) async {
    final parse = parsearXmlCte(xmlTexto);
    if (!parse.ok) return parse.erro;
    final cte = parse.cte!;

    try {
      final existente =
          await _supabase.from('fretes_cte').select('id, frete_id').eq('chave_acesso', cte.chaveAcesso).maybeSingle();
      if (existente != null) {
        return existente['frete_id'] == freteId
            ? 'Este CT-e já está registrado neste frete.'
            : 'Este CT-e já está registrado em outro frete.';
      }

      await _supabase.from('fretes_cte').insert({
        'frete_id': freteId,
        'chave_acesso': cte.chaveAcesso,
        'numero_cte': cte.numeroCte,
        'serie': cte.serieCte,
        'protocolo_autorizacao': cte.protocoloAutorizacao,
        'cnpj_emitente': cte.cnpjEmitente,
        'nome_emitente': cte.nomeEmitente,
        'valor_prestacao': cte.valorPrestacao,
        'data_emissao': cte.dataEmissao.isEmpty ? null : cte.dataEmissao,
        'xml_storage_path': '$freteId/cte-${cte.chaveAcesso}.xml',
        'criado_por': AuthService().emailAtual,
      });

      try {
        await _supabase.storage.from('fretes-documentos').uploadBinary(
              '$freteId/cte-${cte.chaveAcesso}.xml',
              Uint8List.fromList(xmlTexto.codeUnits),
              fileOptions: const FileOptions(contentType: 'text/xml'),
            );
      } catch (_) {
        // best-effort — mesmo padrão do site: o registro já foi gravado,
        // só a cópia do arquivo original pode falhar sem desfazer nada.
      }

      return null;
    } catch (e) {
      return 'Não foi possível registrar o CT-e: $e';
    }
  }

  Future<String?> registrarCiot({
    required String freteId,
    required String numeroCiot,
    String? rntrc,
    String? placaVeiculo,
    double? valorFrete,
    String? dataEmissao,
    String? observacao,
    Uint8List? anexoBytes,
    String? anexoNomeArquivo,
  }) async {
    final numeroLimpo = numeroCiot.replaceAll(RegExp(r'\D'), '');
    if (numeroLimpo.length != 12) {
      return 'O número do CIOT precisa ter 12 dígitos (gerado pela integradora credenciada na ANTT).';
    }

    String? anexoPath;
    try {
      if (anexoBytes != null && anexoBytes.isNotEmpty) {
        if (anexoBytes.length > 5 * 1024 * 1024) return 'O anexo é grande demais (máximo 5 MB).';
        final extensao = (anexoNomeArquivo != null && anexoNomeArquivo.contains('.'))
            ? anexoNomeArquivo.split('.').last
            : 'pdf';
        anexoPath = '$freteId/ciot-$numeroLimpo.$extensao';
        await _supabase.storage.from('fretes-documentos').uploadBinary(
              anexoPath,
              anexoBytes,
              fileOptions: const FileOptions(upsert: true),
            );
      }

      await _supabase.from('fretes_ciot').insert({
        'frete_id': freteId,
        'numero_ciot': numeroLimpo,
        'rntrc': (rntrc == null || rntrc.trim().isEmpty) ? null : rntrc.trim(),
        'placa_veiculo': (placaVeiculo == null || placaVeiculo.trim().isEmpty) ? null : placaVeiculo.trim().toUpperCase(),
        'valor_frete': valorFrete,
        'data_emissao': (dataEmissao == null || dataEmissao.isEmpty) ? null : dataEmissao,
        'observacao': (observacao == null || observacao.trim().isEmpty) ? null : observacao.trim(),
        'anexo_storage_path': anexoPath,
        'criado_por': AuthService().emailAtual,
      });
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '23505') return 'Esse número de CIOT já está registrado neste frete.';
      return 'Não foi possível registrar o CIOT: ${e.message}';
    } catch (e) {
      return 'Não foi possível registrar o CIOT: $e';
    }
  }
}
