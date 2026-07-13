import 'package:dio/dio.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — porta de usuarios/actions.ts. `convidarUsuario` é a única
// operação desta tela que NÃO fala direto com o Supabase: convidar usa a
// Auth Admin API (service role key, secreta) — mesma razão de existir da
// rota /api/assistente. As outras duas (`atualizarUsuario`,
// `alternarAtivo`) usam o client normal (RLS-scoped), igual a web.
const _baseUrlSite = 'https://fxgestaodefrotasonline.com';

class UsuariosService {
  final _supabase = SupabaseService.client;
  final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrlSite,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'Content-Type': 'application/json'},
  ));

  // Convites nesta tela são sempre pro time da própria empresa — sem
  // dropdown de perfil/segmento como a web tem (que atende admin também
  // na mesma tela). `perfil`/`segmento` têm default 'posto'/'Revenda'
  // (comportamento original, usado pelo UsuarioNovoScreen do Posto);
  // Fase FLT-3 — UsuarioNovoClienteScreen passa 'gestor_frota'/'Frota'
  // (mesmo default que a web usa pro perfil de acesso — ver
  // PERFIL_LABEL/PERFIS em constants.ts — quando quem convida não é
  // admin escolhendo outro perfil).
  Future<String?> convidarUsuario({
    required String empresaId,
    required String nome,
    required String email,
    String? cpf,
    String? telefone,
    String perfil = 'posto',
    String segmento = 'Revenda',
  }) async {
    final nomeLimpo = nome.trim();
    final emailLimpo = email.trim().toLowerCase();
    if (nomeLimpo.isEmpty || emailLimpo.isEmpty) return 'Nome e e-mail são obrigatórios.';

    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null) return 'Sessão expirada, faça login novamente.';

    try {
      await _dio.post(
        '/api/usuarios/convidar',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        data: {
          'email': emailLimpo,
          'nome': nomeLimpo,
          'cpf': cpf,
          'telefone': telefone,
          'perfil': perfil,
          'segmento': segmento,
          'empresa_id': empresaId,
        },
      );
      return null;
    } on DioException catch (e) {
      final corpo = e.response?.data;
      if (corpo is Map && corpo['erro'] != null) return corpo['erro'] as String;
      return 'Não foi possível convidar o usuário agora. Tente novamente.';
    }
  }

  Future<String?> atualizarUsuario({
    required String email,
    required String nome,
    String? cpf,
    String? telefone,
    required bool ativo,
  }) async {
    final nomeLimpo = nome.trim();
    if (nomeLimpo.isEmpty) return 'Nome é obrigatório.';
    try {
      await _supabase.from('usuarios_app').update({
        'nome': nomeLimpo,
        'cpf': (cpf == null || cpf.trim().isEmpty) ? null : cpf.trim(),
        'telefone': (telefone == null || telefone.trim().isEmpty) ? null : telefone.trim(),
        'ativo': ativo,
      }).eq('email', email);
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  Future<String?> alternarAtivo({required String email, required bool ativo}) async {
    try {
      await _supabase.from('usuarios_app').update({'ativo': ativo}).eq('email', email);
      await _supabase.from('usuarios_empresas').update({'ativo': ativo}).eq('user_email', email);
      return null;
    } catch (e) {
      return 'Não foi possível atualizar: $e';
    }
  }
}
