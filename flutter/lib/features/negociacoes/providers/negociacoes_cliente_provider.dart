import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../posto/providers/negociacoes_provider.dart' show NegociacaoResumo;

// Fase FLT-3 — Negociações com Postos (cliente), porta de
// negociacoes/page.tsx (lado cliente — a web serve os 2 lados na mesma
// tela; aqui é o espelho de negociacoes_provider.dart, que já cobre o lado
// posto desde a FLT-2). RLS conferida antes de portar: `negociacoes_postos`
// e `negociacoes_postos_rodadas` têm self-service COMPLETO (ALL) via
// `empresa_cliente_id` — CRUD direto, sem RPC, igual à web. Reaproveita as
// constantes (status/labels/produtos) direto de negociacoes_provider.dart
// (lado posto) — são as mesmas, só o lado que muda.
final negociacoesClienteProvider = FutureProvider.autoDispose<List<NegociacaoResumo>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];

  final rows = await SupabaseService.client
      .from('negociacoes_postos')
      .select(
        'id, posto_cnpj, status, rodada_atual, criado_em, atualizado_em, atualizado_por, cliente_nome, posto_nome, vigencia_inicio, vigencia_fim',
      )
      .eq('empresa_cliente_id', empresaId)
      .order('atualizado_em', ascending: false)
      .limit(500);

  return rows.map((m) => NegociacaoResumo.fromMap(m as Map<String, dynamic>)).toList();
});

String hojeIsoUtcCliente() => DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc());
