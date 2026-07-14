import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-4 — Avaliações dos Clientes (admin), porta de
// avaliacoes/page.tsx + _components/RespostaAvaliacao.tsx + actions.ts.
// RLS conferida antes de portar (`avaliacoes`): SELECT já libera "ver
// tudo" pra quem é admin (`perfil_usuario_atual() = 'admin'`), UPDATE
// (resposta) também só admin/superusuário — dá pra ler/gravar direto do
// app, sem RPC. Tela exclusiva do admin (gate na UI, mesmo texto
// "Acesso restrito" da web — a garantia de verdade é a RLS).
String rotuloNota(int estrelas) {
  if (estrelas >= 5) return 'Excelente';
  if (estrelas == 4) return 'Muito boa';
  if (estrelas == 3) return 'Razoável';
  if (estrelas == 2) return 'Ruim';
  return 'Muito ruim';
}

class Avaliacao {
  final String id;
  final String? empresaNome;
  final String userEmail;
  final int estrelas;
  final String? comentario;
  final String? respostaAdmin;
  final String? respondidoPor;
  final String? respondidoEm;
  final String? criadoEm;

  const Avaliacao({
    required this.id,
    this.empresaNome,
    required this.userEmail,
    required this.estrelas,
    this.comentario,
    this.respostaAdmin,
    this.respondidoPor,
    this.respondidoEm,
    this.criadoEm,
  });

  factory Avaliacao.fromMap(Map<String, dynamic> m) {
    final empresa = m['empresas'] as Map<String, dynamic>?;
    return Avaliacao(
      id: m['id'] as String,
      empresaNome: empresa?['nome'] as String?,
      userEmail: m['user_email'] as String? ?? '',
      estrelas: (m['estrelas'] as num?)?.toInt() ?? 0,
      comentario: m['comentario'] as String?,
      respostaAdmin: m['resposta_admin'] as String?,
      respondidoPor: m['respondido_por'] as String?,
      respondidoEm: m['respondido_em'] as String?,
      criadoEm: m['criado_em'] as String?,
    );
  }
}

final avaliacoesAdminProvider = FutureProvider.autoDispose<List<Avaliacao>>((ref) async {
  final rows = await SupabaseService.client
      .from('avaliacoes')
      .select('id, user_email, estrelas, comentario, resposta_admin, respondido_por, respondido_em, criado_em, empresas(nome)')
      .order('criado_em', ascending: false) as List;
  return rows.map((r) => Avaliacao.fromMap(r as Map<String, dynamic>)).toList();
});

class KpisAvaliacoes {
  final int total;
  final double notaMedia;
  final int pendentes;
  const KpisAvaliacoes({required this.total, required this.notaMedia, required this.pendentes});
}

KpisAvaliacoes calcularKpisAvaliacoes(List<Avaliacao> lista) {
  final total = lista.length;
  final notaMedia = total > 0 ? lista.fold<int>(0, (s, a) => s + a.estrelas) / total : 0.0;
  final pendentes = lista.where((a) => a.respostaAdmin == null || a.respostaAdmin!.isEmpty).length;
  return KpisAvaliacoes(total: total, notaMedia: notaMedia, pendentes: pendentes);
}
