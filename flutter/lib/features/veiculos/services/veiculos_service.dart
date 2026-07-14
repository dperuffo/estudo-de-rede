import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — porta de veiculos/actions.ts (criarVeiculo/atualizarVeiculo/
// alternarAtivoVeiculo) + centroCusto.ts (alocarVeiculoCentroCusto). A
// alocação de centro de custo mantém HISTÓRICO em centros_custo_veiculos
// (fecha a alocação ativa atual, abre uma nova) e sincroniza
// cadastro_veiculos.centro_custo_id/nome — mesma lógica exata da web, só
// portada de TS pra Dart (não tem RPC, é escrita direta em 2-3 tabelas).
class VeiculosService {
  final _supabase = SupabaseService.client;

  Map<String, dynamic> _payloadBase({
    required String placa,
    String? marca,
    String? modelo,
    String? motor,
    int? anoModelo,
    int? anoFabricacao,
    double? hodometroAtual,
    String? combustivel,
    double? tanque,
    double? autonomia,
    String? cor,
    String? chassi,
    String? renavam,
    String? municipio,
    String? tipoVeiculo,
    String? ufVeiculo,
    int? numeroEixos,
    required String classificacao,
    String? tipo,
  }) {
    return {
      'placa': placa.trim().toUpperCase(),
      'marca': (marca == null || marca.trim().isEmpty) ? null : marca.trim(),
      'modelo': (modelo == null || modelo.trim().isEmpty) ? null : modelo.trim(),
      'motor': (motor == null || motor.trim().isEmpty) ? null : motor.trim(),
      'ano_modelo': anoModelo,
      'ano_fabricacao': anoFabricacao,
      'hodometro_atual': hodometroAtual,
      'combustivel': (combustivel == null || combustivel.trim().isEmpty) ? null : combustivel.trim(),
      'tanque': tanque,
      'autonomia': autonomia,
      'cor': (cor == null || cor.trim().isEmpty) ? null : cor.trim(),
      'chassi': (chassi == null || chassi.trim().isEmpty) ? null : chassi.trim(),
      'renavam': (renavam == null || renavam.trim().isEmpty) ? null : renavam.trim(),
      'municipio': (municipio == null || municipio.trim().isEmpty) ? null : municipio.trim(),
      'tipo_veiculo': (tipoVeiculo == null || tipoVeiculo.trim().isEmpty) ? null : tipoVeiculo.trim(),
      'uf_veiculo': (ufVeiculo == null || ufVeiculo.trim().isEmpty) ? null : ufVeiculo.trim(),
      'numero_eixos': numeroEixos,
      'classificacao': classificacoesValidas.contains(classificacao) ? classificacao : 'Próprio',
      'tipo': tiposPorteValidos.contains(tipo) ? tipo : null,
    };
  }

  static const classificacoesValidas = ['Próprio', 'Agregado'];
  static const tiposPorteValidos = ['Leve', 'Pesado'];

  Future<({String? erro, String? id})> criarVeiculo({
    required String empresaId,
    required String placa,
    String? marca,
    String? modelo,
    String? motor,
    int? anoModelo,
    int? anoFabricacao,
    double? hodometroAtual,
    String? combustivel,
    double? tanque,
    double? autonomia,
    String? cor,
    String? chassi,
    String? renavam,
    String? municipio,
    String? tipoVeiculo,
    String? ufVeiculo,
    int? numeroEixos,
    String classificacao = 'Próprio',
    String? tipo,
    String? centroCustoId,
  }) async {
    final placaLimpa = placa.trim();
    if (placaLimpa.isEmpty) return (erro: 'Placa é obrigatória.', id: null);
    try {
      final empresa = await _supabase.from('empresas').select('cnpj').eq('id', empresaId).maybeSingle();
      final cnpj = empresa?['cnpj'] as String?;
      if (cnpj == null || cnpj.isEmpty) {
        return (erro: 'Não foi possível identificar o CNPJ da sua empresa.', id: null);
      }

      final duplicado = await _supabase.rpc('veiculo_duplicado', params: {
        'p_cnpj_frota': cnpj,
        'p_placa': placaLimpa.toUpperCase(),
      }) as bool?;
      if (duplicado == true) {
        return (erro: 'Já existe um veículo cadastrado com a placa $placaLimpa para sua empresa.', id: null);
      }

      final payload = _payloadBase(
        placa: placaLimpa,
        marca: marca,
        modelo: modelo,
        motor: motor,
        anoModelo: anoModelo,
        anoFabricacao: anoFabricacao,
        hodometroAtual: hodometroAtual,
        combustivel: combustivel,
        tanque: tanque,
        autonomia: autonomia,
        cor: cor,
        chassi: chassi,
        renavam: renavam,
        municipio: municipio,
        tipoVeiculo: tipoVeiculo,
        ufVeiculo: ufVeiculo,
        numeroEixos: numeroEixos,
        classificacao: classificacao,
        tipo: tipo,
      );

      final row = await _supabase
          .from('cadastro_veiculos')
          .insert({...payload, 'cnpj_frota': cnpj, 'ativo': true})
          .select('id')
          .single();
      final id = row['id'] as String;

      if (centroCustoId != null) {
        final erroAlocacao = await alocarCentroCusto(
          placa: payload['placa'] as String,
          centroCustoId: centroCustoId,
          empresaId: empresaId,
        );
        if (erroAlocacao != null) return (erro: erroAlocacao, id: id);
      }

      return (erro: null, id: id);
    } catch (e) {
      return (erro: 'Não foi possível salvar: $e', id: null);
    }
  }

  Future<String?> atualizarVeiculo({
    required String id,
    required String placa,
    String? marca,
    String? modelo,
    String? motor,
    int? anoModelo,
    int? anoFabricacao,
    double? hodometroAtual,
    String? combustivel,
    double? tanque,
    double? autonomia,
    String? cor,
    String? chassi,
    String? renavam,
    String? municipio,
    String? tipoVeiculo,
    String? ufVeiculo,
    int? numeroEixos,
    String classificacao = 'Próprio',
    String? tipo,
    required bool ativo,
    String? centroCustoId,
  }) async {
    final placaLimpa = placa.trim();
    if (placaLimpa.isEmpty) return 'Placa é obrigatória.';
    try {
      final existente = await _supabase.from('cadastro_veiculos').select('cnpj_frota').eq('id', id).maybeSingle();
      final cnpjFrota = existente?['cnpj_frota'] as String?;

      if (cnpjFrota != null) {
        final duplicado = await _supabase.rpc('veiculo_duplicado', params: {
          'p_cnpj_frota': cnpjFrota,
          'p_placa': placaLimpa.toUpperCase(),
          'p_excluir_id': id,
        }) as bool?;
        if (duplicado == true) {
          return 'Já existe outro veículo cadastrado com a placa $placaLimpa para sua empresa.';
        }
      }

      final payload = _payloadBase(
        placa: placaLimpa,
        marca: marca,
        modelo: modelo,
        motor: motor,
        anoModelo: anoModelo,
        anoFabricacao: anoFabricacao,
        hodometroAtual: hodometroAtual,
        combustivel: combustivel,
        tanque: tanque,
        autonomia: autonomia,
        cor: cor,
        chassi: chassi,
        renavam: renavam,
        municipio: municipio,
        tipoVeiculo: tipoVeiculo,
        ufVeiculo: ufVeiculo,
        numeroEixos: numeroEixos,
        classificacao: classificacao,
        tipo: tipo,
      );

      await _supabase.from('cadastro_veiculos').update({...payload, 'ativo': ativo}).eq('id', id);

      if (cnpjFrota != null) {
        final empresa = await _supabase.from('empresas').select('id').eq('cnpj', cnpjFrota).maybeSingle();
        final erroAlocacao = await alocarCentroCusto(
          placa: payload['placa'] as String,
          centroCustoId: centroCustoId,
          empresaId: empresa?['id'] as String?,
        );
        if (erroAlocacao != null) return erroAlocacao;
      }

      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  Future<String?> alternarAtivo({required String id, required bool ativo}) async {
    try {
      await _supabase.from('cadastro_veiculos').update({'ativo': ativo}).eq('id', id);
      return null;
    } catch (e) {
      return 'Não foi possível atualizar: $e';
    }
  }

  // Porta fiel de alocarVeiculoCentroCusto (src/lib/centroCusto.ts): fecha
  // a alocação ativa atual (data_fim = hoje) e abre uma nova, em vez de
  // sobrescrever — mantém histórico. `centroCustoId == null` desaloca.
  Future<String?> alocarCentroCusto({
    required String placa,
    required String? centroCustoId,
    required String? empresaId,
  }) async {
    final hoje = DateTime.now().toIso8601String().substring(0, 10);
    try {
      final atual = await _supabase
          .from('centros_custo_veiculos')
          .select('id, centro_custo_id')
          .eq('placa', placa)
          .eq('ativo', true)
          .isFilter('data_fim', null)
          .maybeSingle();

      if ((atual?['centro_custo_id'] as String?) == centroCustoId) {
        return null;
      }

      if (atual != null) {
        await _supabase
            .from('centros_custo_veiculos')
            .update({'data_fim': hoje, 'ativo': false}).eq('id', atual['id']);
      }

      String? nomeCentroCusto;
      if (centroCustoId != null) {
        final cc = await _supabase.from('centros_custo').select('nome').eq('id', centroCustoId).maybeSingle();
        nomeCentroCusto = cc?['nome'] as String?;

        final email = _supabase.auth.currentUser?.email;
        await _supabase.from('centros_custo_veiculos').insert({
          'centro_custo_id': centroCustoId,
          'empresa_id': empresaId,
          'placa': placa,
          'data_inicio': hoje,
          'ativo': true,
          'criado_por': email ?? '',
        });
      }

      await _supabase
          .from('cadastro_veiculos')
          .update({'centro_custo_id': centroCustoId, 'centro_custo_nome': nomeCentroCusto}).eq('placa', placa);

      return null;
    } catch (e) {
      return 'Não foi possível atualizar o centro de custo: $e';
    }
  }
}
