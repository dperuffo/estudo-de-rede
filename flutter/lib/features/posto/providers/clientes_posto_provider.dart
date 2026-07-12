import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — Clientes da visão Posto, porta de
// src/app/(dashboard)/clientes-posto/page.tsx: TODAS as transportadoras que
// já negociaram com este posto (qualquer status), com resumo de
// negociações. Vem da RPC `clientes_do_posto` (SECURITY DEFINER) — RLS de
// `empresas` bloqueia SELECT cross-tenant direto pra quem não é membro,
// mesmo problema já documentado nas Fases 27.68/FLT-2 (RLS cruzada).

String formatarCnpj(String? cnpj) {
  if (cnpj == null) return '—';
  final s = cnpj.replaceAll(RegExp(r'\D'), '');
  if (s.length != 14) return cnpj;
  return '${s.substring(0, 2)}.${s.substring(2, 5)}.${s.substring(5, 8)}/${s.substring(8, 12)}-${s.substring(12)}';
}

class ClientePosto {
  final String id;
  final String nome;
  final String? cnpj;
  final String? municipio;
  final String? uf;
  final String? porte;
  final String? segmentoTransporte;
  final String? telefoneContato;
  final String? emailContato;
  final String? statusNegociacao;
  final int negociacoesCount;
  final String? ultimaAtualizacao;

  const ClientePosto({
    required this.id,
    required this.nome,
    this.cnpj,
    this.municipio,
    this.uf,
    this.porte,
    this.segmentoTransporte,
    this.telefoneContato,
    this.emailContato,
    this.statusNegociacao,
    required this.negociacoesCount,
    this.ultimaAtualizacao,
  });

  factory ClientePosto.fromMap(Map<String, dynamic> m) => ClientePosto(
        id: m['id'] as String,
        nome: m['nome'] as String? ?? '—',
        cnpj: m['cnpj'] as String?,
        municipio: m['municipio'] as String?,
        uf: m['uf'] as String?,
        porte: m['porte'] as String?,
        segmentoTransporte: m['segmento_transporte'] as String?,
        telefoneContato: m['telefone_contato'] as String?,
        emailContato: m['email_contato'] as String?,
        statusNegociacao: m['status_negociacao'] as String?,
        negociacoesCount: (m['negociacoes_count'] as num?)?.toInt() ?? 0,
        ultimaAtualizacao: m['ultima_atualizacao'] as String?,
      );
}

final clientesPostoProvider = FutureProvider.autoDispose<List<ClientePosto>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];

  final rows = await SupabaseService.client
      .rpc('clientes_do_posto', params: {'p_empresa_posto_id': empresaId});

  return (rows as List)
      .map((m) => ClientePosto.fromMap(m as Map<String, dynamic>))
      .toList();
});
