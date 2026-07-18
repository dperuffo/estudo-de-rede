import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';

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
  }) async {
    if (titulo.trim().isEmpty) return 'Título é obrigatório.';
    if (valorOferecido <= 0) return 'Informe um valor de frete válido.';

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
      });
      return null;
    } catch (e) {
      return 'Não foi possível publicar o frete: $e';
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
}
