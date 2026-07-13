import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — porta de minha-empresa/actions.ts (atualizarPixChaveAcao +
// atualizarDadosBancariosAcao). Só o segmento "Revenda" (posto) usa esta
// tela — na web o item de menu só aparece pro posto, e o shell Flutter
// /posto nunca é acessado por outro perfil, então não precisa repetir o
// filtro por segmento aqui. Mesmas validações client-side da web
// (tamanho máximo por campo, string vazia vira null, tipo_conta só
// aceita corrente/poupanca) — a permissão de quem pode editar continua
// sendo garantida pela RLS `empresas_update_admin` da tabela `empresas`
// (apesar do nome, libera update pra qualquer vinculado à própria
// empresa, não só admin).
class MeusDadosService {
  final _supabase = SupabaseService.client;

  String? _limpar(String v, int max) {
    final t = v.trim();
    if (t.isEmpty) return null;
    return t.length > max ? t.substring(0, max) : t;
  }

  Future<String?> atualizarPixChave({required String empresaId, required String pixChave}) async {
    final valor = _limpar(pixChave, 140);
    try {
      await _supabase.from('empresas').update({'pix_chave': valor}).eq('id', empresaId);
      return null;
    } catch (e) {
      return 'Não foi possível salvar a chave PIX: $e';
    }
  }

  Future<String?> atualizarDadosBancarios({
    required String empresaId,
    required String bancoCodigo,
    required String bancoNome,
    required String agencia,
    required String agenciaDigito,
    required String conta,
    required String contaDigito,
    required String tipoConta,
    required String titularNome,
    required String titularDocumento,
  }) async {
    if (tipoConta.isNotEmpty && tipoConta != 'corrente' && tipoConta != 'poupanca') {
      return 'Tipo de conta inválido.';
    }
    try {
      await _supabase.from('empresas').update({
        'banco_codigo': _limpar(bancoCodigo, 10),
        'banco_nome': _limpar(bancoNome, 140),
        'agencia': _limpar(agencia, 20),
        'agencia_digito': _limpar(agenciaDigito, 5),
        'conta': _limpar(conta, 30),
        'conta_digito': _limpar(contaDigito, 5),
        'tipo_conta': tipoConta.isEmpty ? null : tipoConta,
        'titular_nome': _limpar(titularNome, 140),
        'titular_documento': _limpar(titularDocumento, 20),
      }).eq('id', empresaId);
      return null;
    } catch (e) {
      return 'Não foi possível salvar os dados bancários: $e';
    }
  }
}
