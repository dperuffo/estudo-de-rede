import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/sessao_provider.dart';
import '../services/supabase_service.dart';

// Fase FLT-7 — pedido do Daniel: "o mesmo sistema de notificação no PWA que
// tem na web". Na web (ver src/app/(dashboard)/layout.tsx) não existe um
// sino/central de notificações — é um conjunto de 7 "bolinhas" vermelhas
// com contagem, ao lado de itens específicos do menu lateral, cada uma vinda
// de uma Server Action `contar*Acao()` própria (chamados/actions.ts,
// negociacoes/actions.ts, abastecimentos/actions.ts, clientes/actions.ts,
// avaliacoes/actions.ts, documentos-empresas/actions.ts,
// anomalias/actions.ts). Portado aqui 1:1: mesmas 7 contagens, mesmos
// filtros, mesma regra "falha vira 0" (a web já documenta isso — Fase
// 27.29 — como proteção pra uma contagem lenta/quebrada nunca derrubar o
// menu inteiro; mesmo espírito do hotfix já aplicado no Dashboard).
//
// Quem vê o quê (mesma lógica condicional da web):
//   - Chamados: todos os perfis (RLS de `tickets` já inclui bypass admin).
//   - Negociações: todos — cliente/posto veem só o que "cabe a eles"
//     responder (pendente_cliente/pendente_posto); admin vê TODAS as
//     pendentes da rede.
//   - Ajustes de abastecimento (badge no item "Abastecimentos"): mesma
//     ideia — cliente/posto veem o que cabe a eles responder; admin não
//     tem abastecimentos próprios, então esta conta natural (via RLS)
//     sempre 0 pra ele, sem precisar de caso especial (igual à web).
//   - Anomalias: todos os perfis (RLS de `anomalias_abastecimento` já
//     inclui bypass admin).
//   - Acessos de clientes / Avaliações / Documentos pendentes: SÓ admin
//     (a própria RLS dessas 3 tabelas restringe SELECT a admin/dono).
class NotificacoesBadges {
  final int chamados;
  final int negociacoes;
  final int ajustesAbastecimento;
  final int anomalias;
  final int acessosClientes;
  final int avaliacoes;
  final int documentosPendentes;
  final int antifraude;

  const NotificacoesBadges({
    required this.chamados,
    required this.negociacoes,
    required this.ajustesAbastecimento,
    required this.anomalias,
    required this.acessosClientes,
    required this.avaliacoes,
    required this.documentosPendentes,
    required this.antifraude,
  });

  static const vazio = NotificacoesBadges(
    chamados: 0,
    negociacoes: 0,
    ajustesAbastecimento: 0,
    anomalias: 0,
    acessosClientes: 0,
    avaliacoes: 0,
    documentosPendentes: 0,
    antifraude: 0,
  );
}

// "Best effort" — mesmo padrão já usado no Dashboard (Fase FLT-6): uma
// contagem que falhar vira 0 (bolinha some) em vez de derrubar o menu.
Future<int> _contagemSegura(Future<int> Function() consulta) async {
  try {
    return await consulta();
  } catch (_) {
    return 0;
  }
}

final notificacoesBadgesProvider = FutureProvider.autoDispose<NotificacoesBadges>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final supabase = SupabaseService.client;
  final statusQueMeCabeResponder = sessao.ehPosto ? 'pendente_posto' : 'pendente_cliente';

  Future<int> contarChamados() async {
    final rows = await supabase
        .from('tickets')
        .select('atualizado_em, usuario_visto_em, admin_visto_em')
        .neq('status', 'fechado') as List;
    final vistoEmChave = sessao.ehAdmin ? 'admin_visto_em' : 'usuario_visto_em';
    return rows.where((r) {
      final m = r as Map<String, dynamic>;
      final atualizadoEm = m['atualizado_em'] as String?;
      if (atualizadoEm == null) return false;
      final vistoEm = m[vistoEmChave] as String?;
      if (vistoEm == null) return true;
      final a = DateTime.tryParse(atualizadoEm);
      final v = DateTime.tryParse(vistoEm);
      if (a == null || v == null) return false;
      return a.isAfter(v);
    }).length;
  }

  Future<int> contarNegociacoes() async {
    if (sessao.ehAdmin) {
      final resp = await supabase
          .from('negociacoes_postos')
          .select('id')
          .inFilter('status', ['pendente_cliente', 'pendente_posto'])
          .count(CountOption.exact);
      return resp.count;
    }
    final resp = await supabase
        .from('negociacoes_postos')
        .select('id')
        .eq('status', statusQueMeCabeResponder)
        .count(CountOption.exact);
    return resp.count;
  }

  Future<int> contarAjustesAbastecimento() async {
    final resp = await supabase
        .from('ajustes_abastecimentos')
        .select('id')
        .eq('status', statusQueMeCabeResponder)
        .count(CountOption.exact);
    return resp.count;
  }

  Future<int> contarAnomalias() async {
    final resp =
        await supabase.from('anomalias_abastecimento').select('id').filter('revisado_em', 'is', null).count(CountOption.exact);
    return resp.count;
  }

  Future<int> contarAcessosClientes() async {
    if (!sessao.ehAdmin) return 0;
    final resp =
        await supabase.from('acessos_clientes').select('id').filter('admin_visto_em', 'is', null).count(CountOption.exact);
    return resp.count;
  }

  Future<int> contarAvaliacoes() async {
    if (!sessao.ehAdmin) return 0;
    final resp =
        await supabase.from('avaliacoes').select('id').filter('resposta_admin', 'is', null).count(CountOption.exact);
    return resp.count;
  }

  Future<int> contarDocumentosPendentes() async {
    if (!sessao.ehAdmin) return 0;
    final resp = await supabase.from('empresas').select('id').eq('documentacao_status', 'pendente').count(CountOption.exact);
    return resp.count;
  }

  // Fase 27.15x — falhas de verificação antifraude (fail-open) ainda não
  // lidas, mesma RLS por empresa de antifraude_verificacoes_falhas (não
  // precisa de caso especial admin/não-admin, igual Anomalias).
  Future<int> contarAntifraude() async {
    final resp =
        await supabase.from('antifraude_verificacoes_falhas').select('id').filter('lida_em', 'is', null).count(CountOption.exact);
    return resp.count;
  }

  final resultados = await Future.wait([
    _contagemSegura(contarChamados),
    _contagemSegura(contarNegociacoes),
    _contagemSegura(contarAjustesAbastecimento),
    _contagemSegura(contarAnomalias),
    _contagemSegura(contarAcessosClientes),
    _contagemSegura(contarAvaliacoes),
    _contagemSegura(contarDocumentosPendentes),
    _contagemSegura(contarAntifraude),
  ]);

  return NotificacoesBadges(
    chamados: resultados[0],
    negociacoes: resultados[1],
    ajustesAbastecimento: resultados[2],
    anomalias: resultados[3],
    acessosClientes: resultados[4],
    avaliacoes: resultados[5],
    documentosPendentes: resultados[6],
    antifraude: resultados[7],
  );
});
