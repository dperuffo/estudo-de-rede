import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../posto/providers/assinatura_provider.dart' show PrecoPlano, precosPlanosProvider;

// Fase FLT-4 — Assinaturas (admin), porta de assinaturas/page.tsx +
// _components/IndicadoresFinanceirosFni.tsx (componente compartilhado
// com /financeiro na web quando o admin não tem cliente selecionado —
// aqui vira sua própria tela, ligada direto no menu Administração). RLS
// conferida antes de portar: `empresas` e `invoices` já liberam SELECT
// total pra quem é admin (mesma policy usada no resto do FLT-4) — dá pra
// ler direto do app. Preço real de cada plano vem da Edge Function
// `planos-precos` (verify_jwt:false, só usa o anon key) — reaproveitada
// via `show` do provider que a visão Posto já usa pra mostrar preço de
// assinatura (`precosPlanosProvider`/`PrecoPlano`, em
// posto/providers/assinatura_provider.dart), nenhum código novo de
// chamada à function.
//
// Fora do escopo: nenhum — a tela é só leitura (KPIs + tabela); ações de
// assinatura de um cliente específico (mudar plano, cancelar) já existem
// na tela /assinatura (singular, ver assinatura_cliente_screen.dart) e
// não são repetidas aqui, mesmo espírito do link "Ver assinatura" da web
// (que só navega, não edita nada nesta página).

class EmpresaAssinatura {
  final String id;
  final String nome;
  final String plano;
  final String status;
  final String? trialEndsAt;
  final String? stripeCustomerId;
  final String? createdAt;
  final String? canceladoEm;

  const EmpresaAssinatura({
    required this.id,
    required this.nome,
    required this.plano,
    required this.status,
    this.trialEndsAt,
    this.stripeCustomerId,
    this.createdAt,
    this.canceladoEm,
  });

  factory EmpresaAssinatura.fromMap(Map<String, dynamic> m) => EmpresaAssinatura(
        id: m['id'] as String,
        nome: m['nome'] as String? ?? '—',
        plano: m['plano'] as String? ?? 'gratuito',
        status: m['status'] as String? ?? 'trial',
        trialEndsAt: m['trial_ends_at'] as String?,
        stripeCustomerId: m['stripe_customer_id'] as String?,
        createdAt: m['created_at'] as String?,
        canceladoEm: m['cancelado_em'] as String?,
      );
}

const planoLabel = {
  'gratuito': 'Gratuito',
  'basico': 'Básico',
  'profissional': 'Profissional',
  'enterprise': 'Enterprise',
};

const statusEmpresaLabel = {
  'trial': 'Em teste (trial)',
  'ativo': 'Ativo',
  'suspenso': 'Suspenso',
  'cancelado': 'Cancelado',
};

class IndicadoresFinanceirosFni {
  final int totalClientes;
  final int totalTrial;
  final int totalAtivos;
  final int totalSuspensos;
  final int totalCancelados;
  final int mrrCents;
  final int faturamentoMesCents;
  final int inadimplenciaMesCents;
  final int qtdInvoicesFalhas;
  final int novosAssinantesDoMes;
  final List<EmpresaAssinatura> churnDoMes;
  final List<EmpresaAssinatura> trialsEmRisco;
  final int taxaConversao;
  final List<EmpresaAssinatura> empresas;

  const IndicadoresFinanceirosFni({
    required this.totalClientes,
    required this.totalTrial,
    required this.totalAtivos,
    required this.totalSuspensos,
    required this.totalCancelados,
    required this.mrrCents,
    required this.faturamentoMesCents,
    required this.inadimplenciaMesCents,
    required this.qtdInvoicesFalhas,
    required this.novosAssinantesDoMes,
    required this.churnDoMes,
    required this.trialsEmRisco,
    required this.taxaConversao,
    required this.empresas,
  });
}

final assinaturasAdminProvider = FutureProvider.autoDispose<IndicadoresFinanceirosFni>((ref) async {
  final agora = DateTime.now();
  final inicioMes = DateTime(agora.year, agora.month, 1);
  final fimMes = DateTime(agora.year, agora.month + 1, 0, 23, 59, 59);

  final precos = await ref.watch(precosPlanosProvider.future);

  final resultados = await Future.wait([
    SupabaseService.client
        .from('empresas')
        .select('id, nome, plano, status, trial_ends_at, stripe_customer_id, created_at, cancelado_em')
        .order('created_at', ascending: false),
    SupabaseService.client
        .from('invoices')
        .select('empresa_id, valor_cents, status')
        .gte('criado_em', inicioMes.toIso8601String())
        .lte('criado_em', fimMes.toIso8601String()),
  ]);

  final empresasRows = resultados[0] as List;
  final invoicesRows = resultados[1] as List;

  final empresas = empresasRows.map((r) => EmpresaAssinatura.fromMap(r as Map<String, dynamic>)).toList();

  var totalTrial = 0, totalAtivos = 0, totalSuspensos = 0, totalCancelados = 0;
  var mrrCents = 0;
  final trialsEmRisco = <EmpresaAssinatura>[];

  for (final e in empresas) {
    switch (e.status) {
      case 'trial':
        totalTrial++;
        break;
      case 'ativo':
        totalAtivos++;
        break;
      case 'suspenso':
        totalSuspensos++;
        break;
      case 'cancelado':
        totalCancelados++;
        break;
    }
    if (e.status == 'ativo') {
      final preco = precos[e.plano];
      mrrCents += preco?.unitAmount ?? 0;
    }
    if (e.status == 'trial' && e.trialEndsAt != null) {
      final diasRestantes = DateTime.parse(e.trialEndsAt!).difference(DateTime.now()).inHours / 24;
      if (diasRestantes.ceil() <= 3) trialsEmRisco.add(e);
    }
  }

  final totalClientes = empresas.length;
  final taxaConversao = totalClientes > 0 ? ((totalAtivos / totalClientes) * 100).round() : 0;

  final invoicesPagas = invoicesRows.where((i) => (i as Map<String, dynamic>)['status'] == 'pago').toList();
  final invoicesFalhas = invoicesRows.where((i) => (i as Map<String, dynamic>)['status'] == 'falhou').toList();
  final faturamentoMesCents = invoicesPagas.fold<int>(0, (s, i) => s + (((i as Map<String, dynamic>)['valor_cents'] as num?)?.toInt() ?? 0));
  final inadimplenciaMesCents = invoicesFalhas.fold<int>(0, (s, i) => s + (((i as Map<String, dynamic>)['valor_cents'] as num?)?.toInt() ?? 0));

  // Comparação por DateTime de verdade (não string) — os timestamps que
  // voltam do banco têm timezone explícito (+00:00), diferente de
  // `inicioMes`/`fimMes` (hora local sem offset); comparar como texto
  // daria resultado errado. `DateTime.parse` entende os dois formatos.
  bool dentroDoMes(String? iso) {
    if (iso == null) return false;
    final d = DateTime.parse(iso);
    return !d.isBefore(inicioMes) && !d.isAfter(fimMes);
  }

  final churnDoMes = empresas.where((e) => dentroDoMes(e.canceladoEm)).toList();
  final novosAssinantesDoMes = empresas.where((e) => e.plano != 'gratuito' && dentroDoMes(e.createdAt)).length;

  return IndicadoresFinanceirosFni(
    totalClientes: totalClientes,
    totalTrial: totalTrial,
    totalAtivos: totalAtivos,
    totalSuspensos: totalSuspensos,
    totalCancelados: totalCancelados,
    mrrCents: mrrCents,
    faturamentoMesCents: faturamentoMesCents,
    inadimplenciaMesCents: inadimplenciaMesCents,
    qtdInvoicesFalhas: invoicesFalhas.length,
    novosAssinantesDoMes: novosAssinantesDoMes,
    churnDoMes: churnDoMes,
    trialsEmRisco: trialsEmRisco,
    taxaConversao: taxaConversao,
    empresas: empresas,
  );
});
