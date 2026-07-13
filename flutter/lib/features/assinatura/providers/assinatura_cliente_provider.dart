import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../posto/providers/assinatura_provider.dart' show FaturaAssinatura;

// Fase FLT-3 — porta de src/app/(dashboard)/assinatura/page.tsx pro shell
// Cliente. Web tem 2 caminhos de dimensionamento de plano: por tamanho da
// Rede de Postos (segmento "Revenda" — já portado à parte na FLT-2, ver
// posto/providers/assinatura_provider.dart) ou por uso de
// usuários/veículos (qualquer outro segmento — o caso daqui). Reaproveita
// `FaturaAssinatura` do arquivo do Posto (import direto — classe já era
// genérica, sem nada posto-específico) em vez de duplicar o modelo.
// `LIMITES_PLANO` copiado 1:1 de src/lib/constants.ts (constante estática,
// sem RPC/tabela própria — mesmo valor nos dois lados).
const limitesPlano = <String, ({int maxUsuarios, int maxVeiculos})>{
  'gratuito': (maxUsuarios: 1, maxVeiculos: 10),
  'basico': (maxUsuarios: 5, maxVeiculos: 50),
  'profissional': (maxUsuarios: 20, maxVeiculos: 200),
  'enterprise': (maxUsuarios: -1, maxVeiculos: -1),
};

class EmpresaAssinaturaCliente {
  final String id;
  final String nome;
  final String plano;
  final String status;
  final String? trialEndsAt;
  final String? stripeCustomerId;
  const EmpresaAssinaturaCliente({
    required this.id,
    required this.nome,
    required this.plano,
    required this.status,
    required this.trialEndsAt,
    required this.stripeCustomerId,
  });
}

class AssinaturaClienteDetalhe {
  final EmpresaAssinaturaCliente empresa;
  final int qtdUsuarios;
  final int qtdVeiculos;
  final List<FaturaAssinatura> invoices;
  const AssinaturaClienteDetalhe({
    required this.empresa,
    required this.qtdUsuarios,
    required this.qtdVeiculos,
    required this.invoices,
  });
}

final assinaturaClienteProvider = FutureProvider.autoDispose<AssinaturaClienteDetalhe?>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return null;
  final supabase = SupabaseService.client;

  final empresaMap = await supabase
      .from('empresas')
      .select('id, nome, plano, status, trial_ends_at, stripe_customer_id')
      .eq('id', empresaId)
      .single();

  final empresa = EmpresaAssinaturaCliente(
    id: empresaMap['id'] as String,
    nome: empresaMap['nome'] as String? ?? '—',
    plano: empresaMap['plano'] as String? ?? 'gratuito',
    status: empresaMap['status'] as String? ?? 'trial',
    trialEndsAt: empresaMap['trial_ends_at'] as String?,
    stripeCustomerId: empresaMap['stripe_customer_id'] as String?,
  );

  final usuariosResp = await supabase
      .from('usuarios_empresas')
      .select('user_email')
      .eq('empresa_id', empresaId)
      .eq('ativo', true)
      .count(CountOption.exact);
  final qtdUsuarios = usuariosResp.count;

  final qtdVeiculos =
      await supabase.rpc('contar_veiculos_reais_empresa', params: {'p_empresa_id': empresaId}) as int? ?? 0;

  final invoicesRaw = await supabase
      .from('invoices')
      .select('id, valor_cents, status, criado_em, periodo_inicio, periodo_fim')
      .eq('empresa_id', empresaId)
      .order('criado_em', ascending: false)
      .limit(24) as List;
  final invoices = invoicesRaw.map((m) => FaturaAssinatura.fromMap(m as Map<String, dynamic>)).toList();

  return AssinaturaClienteDetalhe(
    empresa: empresa,
    qtdUsuarios: qtdUsuarios,
    qtdVeiculos: qtdVeiculos,
    invoices: invoices,
  );
});
