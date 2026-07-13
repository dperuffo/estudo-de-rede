import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — porta de motoristas/actions.ts (criarMotorista/
// atualizarMotorista/alternarAtivoMotorista). Mesma checagem de duplicado
// via RPC `motorista_duplicado` (o índice único no banco é a trava
// definitiva; a checagem aqui só dá uma mensagem melhor, igual à web).
class MotoristasService {
  final _supabase = SupabaseService.client;

  Map<String, dynamic> _payload({
    required String nomeCompleto,
    required String cpf,
    String? telefone,
    String? email,
    required String classificacao,
    String? cnh,
    String? cnhVencimento,
    String? centroCustoId,
  }) {
    return {
      'nome_completo': nomeCompleto.trim(),
      'cpf': cpf.trim(),
      'telefone': (telefone == null || telefone.trim().isEmpty) ? null : telefone.trim(),
      'email': (email == null || email.trim().isEmpty) ? null : email.trim(),
      'classificacao': classificacoesValidas.contains(classificacao) ? classificacao : 'Próprio',
      'cnh': (cnh == null || cnh.trim().isEmpty) ? null : cnh.trim(),
      'cnh_vencimento': (cnhVencimento == null || cnhVencimento.isEmpty) ? null : cnhVencimento,
      'centro_custo_id': (centroCustoId == null || centroCustoId.isEmpty) ? null : centroCustoId,
    };
  }

  static const classificacoesValidas = ['Próprio', 'Agregado'];

  Future<({String? erro, String? id})> criarMotorista({
    required String empresaId,
    required String nomeCompleto,
    required String cpf,
    String? telefone,
    String? email,
    required String classificacao,
    String? cnh,
    String? cnhVencimento,
    String? centroCustoId,
  }) async {
    final nomeLimpo = nomeCompleto.trim();
    final cpfLimpo = cpf.trim();
    if (nomeLimpo.isEmpty || cpfLimpo.isEmpty) {
      return (erro: 'Nome completo e CPF são obrigatórios.', id: null);
    }

    try {
      final duplicado = await _supabase.rpc('motorista_duplicado', params: {
        'p_empresa_id': empresaId,
        'p_cpf': cpfLimpo,
      }) as bool?;
      if (duplicado == true) {
        return (erro: 'Já existe um motorista cadastrado com o CPF $cpfLimpo para este cliente.', id: null);
      }

      final payload = _payload(
        nomeCompleto: nomeCompleto,
        cpf: cpf,
        telefone: telefone,
        email: email,
        classificacao: classificacao,
        cnh: cnh,
        cnhVencimento: cnhVencimento,
        centroCustoId: centroCustoId,
      );
      final email2 = _supabase.auth.currentUser?.email;
      final row = await _supabase
          .from('motoristas')
          .insert({...payload, 'empresa_id': empresaId, 'status': 'Ativo', 'criado_por': email2})
          .select('id')
          .single();
      return (erro: null, id: row['id'] as String);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('23505') || msg.toLowerCase().contains('duplicate')) {
        return (erro: 'Já existe um motorista cadastrado com o CPF $cpfLimpo para este cliente.', id: null);
      }
      return (erro: 'Não foi possível salvar: $e', id: null);
    }
  }

  Future<String?> atualizarMotorista({
    required String id,
    required String empresaId,
    required String nomeCompleto,
    required String cpf,
    String? telefone,
    String? email,
    required String classificacao,
    String? cnh,
    String? cnhVencimento,
    String? centroCustoId,
    required bool ativo,
  }) async {
    final nomeLimpo = nomeCompleto.trim();
    final cpfLimpo = cpf.trim();
    if (nomeLimpo.isEmpty || cpfLimpo.isEmpty) {
      return 'Nome completo e CPF são obrigatórios.';
    }
    try {
      final duplicado = await _supabase.rpc('motorista_duplicado', params: {
        'p_empresa_id': empresaId,
        'p_cpf': cpfLimpo,
        'p_excluir_id': id,
      }) as bool?;
      if (duplicado == true) {
        return 'Já existe outro motorista cadastrado com o CPF $cpfLimpo para este cliente.';
      }

      final payload = _payload(
        nomeCompleto: nomeCompleto,
        cpf: cpf,
        telefone: telefone,
        email: email,
        classificacao: classificacao,
        cnh: cnh,
        cnhVencimento: cnhVencimento,
        centroCustoId: centroCustoId,
      );
      await _supabase.from('motoristas').update({...payload, 'status': ativo ? 'Ativo' : 'Inativo'}).eq('id', id);
      return null;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('23505') || msg.toLowerCase().contains('duplicate')) {
        return 'Já existe outro motorista cadastrado com o CPF $cpfLimpo para este cliente.';
      }
      return 'Não foi possível salvar: $e';
    }
  }

  Future<String?> alternarAtivo({required String id, required bool ativo}) async {
    try {
      await _supabase.from('motoristas').update({'status': ativo ? 'Ativo' : 'Inativo'}).eq('id', id);
      return null;
    } catch (e) {
      return 'Não foi possível atualizar: $e';
    }
  }
}
