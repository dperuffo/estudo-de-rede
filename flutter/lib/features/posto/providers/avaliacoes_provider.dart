import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — porta de src/app/(dashboard)/avaliar/page.tsx +
// src/lib/avaliacoes.ts pro Flutter.
class Avaliacao {
  final String id;
  final int estrelas;
  final String? comentario;
  final String? respostaAdmin;
  final String? criadoEm;
  const Avaliacao({
    required this.id,
    required this.estrelas,
    required this.comentario,
    required this.respostaAdmin,
    required this.criadoEm,
  });
  factory Avaliacao.fromMap(Map<String, dynamic> m) => Avaliacao(
        id: m['id'] as String,
        estrelas: (m['estrelas'] as num).toInt(),
        comentario: m['comentario'] as String?,
        respostaAdmin: m['resposta_admin'] as String?,
        criadoEm: m['criado_em'] as String?,
      );
}

String rotuloNota(int estrelas) {
  if (estrelas >= 5) return 'Excelente';
  if (estrelas == 4) return 'Muito boa';
  if (estrelas == 3) return 'Razoável';
  if (estrelas == 2) return 'Ruim';
  return 'Muito ruim';
}

final avaliacoesProvider = FutureProvider.autoDispose<List<Avaliacao>>((ref) async {
  final email = AuthService().emailAtual;
  if (email == null) return [];
  final rows = await SupabaseService.client
      .from('avaliacoes')
      .select('id, estrelas, comentario, resposta_admin, criado_em')
      .eq('user_email', email)
      .order('criado_em', ascending: false) as List;
  return rows.map((m) => Avaliacao.fromMap(m as Map<String, dynamic>)).toList();
});
