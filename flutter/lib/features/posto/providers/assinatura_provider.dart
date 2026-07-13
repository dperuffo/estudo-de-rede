import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — porta de src/app/(dashboard)/assinatura/page.tsx pro
// Flutter, escopo reduzido ao caminho POSTO (segmento "Revenda"): a web
// tem dois caminhos — dimensionar plano por usuários/veículos (frota) ou
// por tamanho da Rede de Postos (posto, Fase 27.125) — aqui só o segundo
// se aplica, já que o shell /posto é sempre Revenda. Também não replica o
// seletor de "Cliente" (só existe pro admin apoiar qualquer empresa; o
// Flutter já resolve a empresa atual via sessao/seletor de posto).
class EmpresaAssinatura {
  final String id;
  final String nome;
  final String? cnpj;
  final String plano;
  final String status;
  final String? trialEndsAt;
  final String? stripeCustomerId;
  const EmpresaAssinatura({
    required this.id,
    required this.nome,
    required this.cnpj,
    required this.plano,
    required this.status,
    required this.trialEndsAt,
    required this.stripeCustomerId,
  });
}

class FaturaAssinatura {
  final String id;
  final int? valorCents;
  final String status;
  final String criadoEm;
  final String? periodoInicio;
  final String? periodoFim;
  const FaturaAssinatura({
    required this.id,
    required this.valorCents,
    required this.status,
    required this.criadoEm,
    required this.periodoInicio,
    required this.periodoFim,
  });
  factory FaturaAssinatura.fromMap(Map<String, dynamic> m) => FaturaAssinatura(
        id: m['id'] as String,
        valorCents: (m['valor_cents'] as num?)?.toInt(),
        status: m['status'] as String? ?? '—',
        criadoEm: m['criado_em'] as String,
        periodoInicio: m['periodo_inicio'] as String?,
        periodoFim: m['periodo_fim'] as String?,
      );
}

class AssinaturaDetalhe {
  final EmpresaAssinatura empresa;
  // Nº de postos na Rede a que este posto pertence (ou 1, se não pertence
  // a nenhuma — mesma regra do page.tsx original).
  final int qtdPostosNaRede;
  final List<FaturaAssinatura> invoices;
  const AssinaturaDetalhe({required this.empresa, required this.qtdPostosNaRede, required this.invoices});
}

final assinaturaProvider = FutureProvider.autoDispose<AssinaturaDetalhe?>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return null;
  final supabase = SupabaseService.client;

  final empresaMap = await supabase
      .from('empresas')
      .select('id, nome, cnpj, plano, status, trial_ends_at, stripe_customer_id')
      .eq('id', empresaId)
      .single();

  final empresa = EmpresaAssinatura(
    id: empresaMap['id'] as String,
    nome: empresaMap['nome'] as String? ?? '—',
    cnpj: empresaMap['cnpj'] as String?,
    plano: empresaMap['plano'] as String? ?? 'gratuito',
    status: empresaMap['status'] as String? ?? 'trial',
    trialEndsAt: empresaMap['trial_ends_at'] as String?,
    stripeCustomerId: empresaMap['stripe_customer_id'] as String?,
  );

  // Mesma consulta da Fase 27.125 (assinatura/page.tsx): conta quantos
  // postos existem em qualquer Rede (segmento "Revenda") da qual esta
  // empresa é membro; se não estiver em nenhuma Rede, conta como 1 (o
  // próprio posto).
  final meusVinculos =
      await supabase.from('grupos_economicos_empresas').select('grupo_economico_id').eq('empresa_id', empresaId)
          as List;
  int qtdPostosNaRede = 1;
  if (meusVinculos.isNotEmpty) {
    final redeId = meusVinculos.first['grupo_economico_id'] as String;
    final rede = await supabase.from('grupos_economicos').select('segmento').eq('id', redeId).maybeSingle();
    if (rede != null && rede['segmento'] == 'Revenda') {
      final countResp = await supabase
          .from('grupos_economicos_empresas')
          .select('empresa_id')
          .eq('grupo_economico_id', redeId)
          .count(CountOption.exact);
      qtdPostosNaRede = countResp.count;
    }
  }

  final invoicesRaw = await supabase
      .from('invoices')
      .select('id, valor_cents, status, criado_em, periodo_inicio, periodo_fim')
      .eq('empresa_id', empresaId)
      .order('criado_em', ascending: false)
      .limit(24) as List;
  final invoices = invoicesRaw.map((m) => FaturaAssinatura.fromMap(m as Map<String, dynamic>)).toList();

  return AssinaturaDetalhe(empresa: empresa, qtdPostosNaRede: qtdPostosNaRede, invoices: invoices);
});

// Mesma régua da Fase 27.125 (combinada com o Daniel): 1 a 10 postos na
// rede = Básico, 11 a 50 = Profissional, acima de 50 = Enterprise.
String planoRecomendadoPorRede(int qtdPostosNaRede) {
  if (qtdPostosNaRede <= 10) return 'basico';
  if (qtdPostosNaRede <= 50) return 'profissional';
  return 'enterprise';
}

// Preço real de cada plano, buscado da Edge Function `planos-precos`
// (nunca hardcoded — mesma razão de buscarPrecosPlanos() na web: não
// desatualizar se o preço mudar no Stripe). verify_jwt:false na function.
class PrecoPlano {
  final int? unitAmount;
  final String currency;
  final String? interval;
  const PrecoPlano({required this.unitAmount, required this.currency, required this.interval});
  factory PrecoPlano.fromMap(Map<String, dynamic> m) => PrecoPlano(
        unitAmount: (m['unit_amount'] as num?)?.toInt(),
        currency: m['currency'] as String? ?? 'brl',
        interval: m['interval'] as String?,
      );
}

final precosPlanosProvider = FutureProvider.autoDispose<Map<String, PrecoPlano>>((ref) async {
  try {
    final resposta = await SupabaseService.client.functions.invoke('planos-precos');
    final data = resposta.data as Map<String, dynamic>;
    return data.map((k, v) => MapEntry(k, PrecoPlano.fromMap(v as Map<String, dynamic>)));
  } catch (_) {
    return {};
  }
});

String formatarPrecoPlano(PrecoPlano? preco) {
  if (preco == null || preco.unitAmount == null) return 'Preço sob consulta';
  final valor = preco.unitAmount! / 100;
  final valorFmt = 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  if (preco.interval == null) return valorFmt;
  final porIntervalo = preco.interval == 'month' ? 'mês' : (preco.interval == 'year' ? 'ano' : preco.interval!);
  return '$valorFmt/$porIntervalo';
}
