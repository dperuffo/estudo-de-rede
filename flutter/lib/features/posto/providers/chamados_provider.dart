import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — Gestão de Chamados (suporte), porta com escopo reduzido (ver
// README) de chamados/page.tsx + chamados/[id]/page.tsx + ThreadChamado.tsx
// + lib/chamados.ts da web. Diferente da web (que serve admin — vê tickets
// de TODOS os clientes, com seletor — e cliente/posto comuns, que só veem
// os da própria empresa), aqui só existe o lado posto de UMA empresa já
// resolvida pela sessão (ver seletor de empresa da Fase FLT-2) — sem
// seletor de cliente.

const ticketBucketAnexos = 'ticket-anexos';
const ticketTamanhoMaxAnexoBytes = 20 * 1024 * 1024;

const tiposTicket = <String, String>{'incidente': 'Incidente', 'melhoria': 'Melhoria'};
const statusTicket = <String, String>{
  'aberto': 'Aberto',
  'em_analise': 'Em análise',
  'resolvido': 'Resolvido',
  'fechado': 'Fechado',
};
const prioridadesTicket = <String, String>{'baixa': 'Baixa', 'media': 'Média', 'alta': 'Alta', 'critica': 'Crítica'};

String formatarTamanhoAnexo(int? bytes) {
  if (bytes == null) return '—';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class Ticket {
  final String id;
  final int numero;
  final String tipo;
  final String titulo;
  final String descricao;
  final String status;
  final String prioridade;
  final String? respostaAdmin;
  final String? criadoEm;
  final String? atualizadoEm;
  final String? usuarioVistoEm;
  final String? adminVistoEm;
  final String userEmail;

  const Ticket({
    required this.id,
    required this.numero,
    required this.tipo,
    required this.titulo,
    required this.descricao,
    required this.status,
    required this.prioridade,
    this.respostaAdmin,
    this.criadoEm,
    this.atualizadoEm,
    this.usuarioVistoEm,
    this.adminVistoEm,
    required this.userEmail,
  });

  factory Ticket.fromMap(Map<String, dynamic> m) => Ticket(
        id: m['id'].toString(),
        numero: (m['numero'] as num?)?.toInt() ?? 0,
        tipo: m['tipo'] as String? ?? '',
        titulo: m['titulo'] as String? ?? '',
        descricao: m['descricao'] as String? ?? '',
        status: m['status'] as String? ?? 'aberto',
        prioridade: m['prioridade'] as String? ?? 'media',
        respostaAdmin: m['resposta_admin'] as String?,
        criadoEm: m['criado_em'] as String?,
        atualizadoEm: m['atualizado_em'] as String?,
        usuarioVistoEm: m['usuario_visto_em'] as String?,
        adminVistoEm: m['admin_visto_em'] as String?,
        userEmail: m['user_email'] as String? ?? '',
      );

  // Fase FLT-2 — mesma regra de temAtualizacaoNaoVista (lib/chamados.ts):
  // posto nunca é "admin" de verdade aqui (só o superusuário seria, caso
  // raro de teste), então sempre compara com usuarioVistoEm.
  bool get naoVisto {
    if (atualizadoEm == null) return false;
    if (usuarioVistoEm == null) return true;
    return DateTime.parse(atualizadoEm!).isAfter(DateTime.parse(usuarioVistoEm!));
  }
}

final chamadosPostoProvider = FutureProvider.autoDispose<List<Ticket>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client
      .from('tickets')
      .select(
          'id, numero, tipo, titulo, descricao, status, prioridade, resposta_admin, criado_em, atualizado_em, usuario_visto_em, admin_visto_em, user_email')
      .eq('empresa_id', empresaId)
      .order('criado_em', ascending: false);
  return rows.map((m) => Ticket.fromMap(m)).toList();
});

class TicketComentario {
  final String id;
  final String autorEmail;
  final String autorTipo;
  final String texto;
  final String criadoEm;

  const TicketComentario({
    required this.id,
    required this.autorEmail,
    required this.autorTipo,
    required this.texto,
    required this.criadoEm,
  });

  factory TicketComentario.fromMap(Map<String, dynamic> m) => TicketComentario(
        id: m['id'].toString(),
        autorEmail: m['autor_email'] as String? ?? '',
        autorTipo: m['autor_tipo'] as String? ?? 'usuario',
        texto: m['texto'] as String? ?? '',
        criadoEm: m['criado_em'] as String? ?? '',
      );
}

class TicketAnexo {
  final String id;
  final String nome;
  final int? tamanho;
  final String? autorEmail;
  final String? criadoEm;
  final String? url;
  String? urlAssinada;

  TicketAnexo({
    required this.id,
    required this.nome,
    this.tamanho,
    this.autorEmail,
    this.criadoEm,
    this.url,
    this.urlAssinada,
  });

  factory TicketAnexo.fromMap(Map<String, dynamic> m) => TicketAnexo(
        id: m['id'].toString(),
        nome: m['nome'] as String? ?? 'arquivo',
        tamanho: (m['tamanho'] as num?)?.toInt(),
        autorEmail: m['autor_email'] as String?,
        criadoEm: m['criado_em'] as String?,
        url: m['url'] as String?,
      );
}

class ChamadoDetalhe {
  final Ticket ticket;
  final List<TicketComentario> comentarios;
  final List<TicketAnexo> anexos;

  const ChamadoDetalhe({required this.ticket, required this.comentarios, required this.anexos});
}

final chamadoDetalheProvider =
    FutureProvider.autoDispose.family<ChamadoDetalhe?, String>((ref, ticketId) async {
  final supabase = SupabaseService.client;

  final ticketRaw = await supabase
      .from('tickets')
      .select(
          'id, numero, tipo, titulo, descricao, status, prioridade, resposta_admin, criado_em, atualizado_em, usuario_visto_em, admin_visto_em, user_email')
      .eq('id', ticketId)
      .maybeSingle();
  if (ticketRaw == null) return null;

  final comentariosRaw = await supabase
      .from('ticket_comentarios')
      .select('id, autor_email, autor_tipo, texto, criado_em')
      .eq('ticket_id', ticketId)
      .order('criado_em', ascending: true);
  final comentarios = comentariosRaw.map((m) => TicketComentario.fromMap(m)).toList();

  final anexosRaw = await supabase
      .from('ticket_anexos')
      .select('id, nome, tamanho, autor_email, criado_em, url')
      .eq('ticket_id', ticketId)
      .order('criado_em', ascending: true);
  final anexos = anexosRaw.map((m) => TicketAnexo.fromMap(m)).toList();
  for (final a in anexos) {
    if (a.url == null) continue;
    try {
      a.urlAssinada = await supabase.storage.from(ticketBucketAnexos).createSignedUrl(a.url!, 3600);
    } catch (_) {
      // Anexo com objeto ausente/corrompido no Storage não pode derrubar a
      // tela — mesmo tratamento da web (chamados/[id]/page.tsx).
    }
  }

  return ChamadoDetalhe(ticket: Ticket.fromMap(ticketRaw), comentarios: comentarios, anexos: anexos);
});
