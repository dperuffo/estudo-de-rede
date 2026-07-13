import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — porta de BotaoAssinarPlano.tsx + BotaoPortalPagamento.tsx.
// Chama as MESMAS Edge Functions da web (create-checkout-session,
// create-billing-portal-session) — nenhuma lógica de cobrança nova, só o
// client que dispara. Escopo reduzido em relação à web: não gera nem
// sobe o comprovante em PDF do Termo de Adesão (@react-pdf/renderer não
// tem equivalente direto no Flutter) — confirmado lendo o código da Edge
// Function create-checkout-session que o registro de aceite (hash, versão,
// IP, timestamp — o que importa legalmente) é gravado no banco
// (`termos_aceite`) ANTES da sessão do Stripe ser criada, então não
// depende do PDF pra ser válido; o PDF na web é só um comprovante bonito
// anexado depois no e-mail de confirmação pelo stripe-webhook.
class ResultadoCheckout {
  final String? url;
  final String? erro;
  const ResultadoCheckout.ok(this.url) : erro = null;
  const ResultadoCheckout.erro(this.erro) : url = null;
}

class AssinaturaService {
  final _supabase = SupabaseService.client;

  Future<ResultadoCheckout> criarCheckout({required String empresaId, required String plano}) async {
    try {
      final resposta = await _supabase.functions.invoke(
        'create-checkout-session',
        body: {'empresa_id': empresaId, 'plano': plano, 'aceite_termo': true},
      );
      final data = resposta.data as Map<String, dynamic>?;
      final url = data?['url'] as String?;
      if (url == null) {
        return ResultadoCheckout.erro(data?['erro'] as String? ?? 'Não foi possível iniciar o checkout.');
      }
      return ResultadoCheckout.ok(url);
    } catch (e) {
      return const ResultadoCheckout.erro('Não foi possível falar com o Stripe agora. Tente novamente.');
    }
  }

  Future<ResultadoCheckout> abrirPortalPagamento({required String empresaId}) async {
    try {
      final resposta = await _supabase.functions.invoke(
        'create-billing-portal-session',
        body: {'empresa_id': empresaId},
      );
      final data = resposta.data as Map<String, dynamic>?;
      final url = data?['url'] as String?;
      if (url == null) {
        return ResultadoCheckout.erro(data?['erro'] as String? ?? 'Não foi possível abrir o portal de pagamento.');
      }
      return ResultadoCheckout.ok(url);
    } catch (e) {
      return const ResultadoCheckout.erro('Não foi possível falar com o Stripe agora. Tente novamente.');
    }
  }
}
