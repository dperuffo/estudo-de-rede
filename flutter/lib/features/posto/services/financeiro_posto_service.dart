import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../providers/financeiro_posto_provider.dart';

// Fase FLT-2 — porta de financeiro-posto/actions.ts (lançar/marcar paga/
// excluir despesa, marcar fatura paga).
class FinanceiroPostoService {
  final _supabase = SupabaseService.client;

  Future<String?> lancarDespesa({
    required String empresaPostoId,
    required String tipo,
    required double valor,
    required String competencia,
    required String vencimento,
    String? descricao,
    required bool recorrente,
  }) async {
    if (!tiposDespesaPosto.contains(tipo)) return 'Tipo de despesa inválido.';
    if (valor <= 0) return 'Valor inválido.';
    if (competencia.isEmpty) return 'Informe a competência (mês da despesa).';
    if (vencimento.isEmpty) return 'Informe o vencimento.';

    final email = AuthService().emailAtual;
    try {
      await _supabase.from('despesas_postos').insert({
        'empresa_posto_id': empresaPostoId,
        'tipo': tipo,
        'valor': valor,
        'competencia': competencia,
        'vencimento': vencimento,
        'descricao': (descricao == null || descricao.trim().isEmpty) ? null : descricao.trim(),
        'recorrente': recorrente,
        'criado_por': email,
        'atualizado_por': email,
      });
      return null;
    } on PostgrestException catch (e) {
      return 'Não foi possível lançar a despesa: ${e.message}';
    }
  }

  Future<String?> marcarDespesaPaga(String despesaId) async {
    try {
      await _supabase.from('despesas_postos').update({
        'status': 'paga',
        'pago_em': DateTime.now().toUtc().toIso8601String(),
        'atualizado_em': DateTime.now().toUtc().toIso8601String(),
        'atualizado_por': AuthService().emailAtual,
      }).eq('id', despesaId).eq('status', 'aberta');
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    }
  }

  Future<String?> excluirDespesa(String despesaId) async {
    try {
      await _supabase.from('despesas_postos').delete().eq('id', despesaId);
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    }
  }
}
