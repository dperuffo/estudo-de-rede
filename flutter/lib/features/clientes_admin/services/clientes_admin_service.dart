import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-4 — porta de alternarAtivoCliente (clientes/actions.ts). RLS
// `empresas_update_admin` já garante que só admin (ou o e-mail
// superusuário) consegue de fato gravar — a tela só evita oferecer a
// ação pra quem não é admin.
class ClientesAdminService {
  final _supabase = SupabaseService.client;

  Future<String?> alternarAtivo({required String empresaId, required bool ativar}) async {
    try {
      await _supabase.from('empresas').update({'status': ativar ? 'ativo' : 'suspenso'}).eq('id', empresaId);
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    }
  }
}
