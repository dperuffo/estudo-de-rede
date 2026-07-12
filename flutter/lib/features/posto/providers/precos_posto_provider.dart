import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — "Meus Preços" da visão Posto, porta (com escopo reduzido —
// ver README) de precos-postos/page.tsx + FormularioPrecosPosto.tsx da
// web, só o lado posto (`PainelPosto`) — o lado cliente (ver preços dos
// postos parceiros) não se aplica aqui, essa tela só existe no shell
// /posto. Upsert simples: 1 preço "vigente" por combustível, sem
// histórico — mesma regra da web.

class PrecoPosto {
  final String combustivel;
  final double preco;
  final String atualizadoEm;
  final String? atualizadoPor;

  const PrecoPosto({
    required this.combustivel,
    required this.preco,
    required this.atualizadoEm,
    this.atualizadoPor,
  });

  factory PrecoPosto.fromMap(Map<String, dynamic> m) => PrecoPosto(
        combustivel: m['combustivel'] as String,
        preco: (m['preco'] as num).toDouble(),
        atualizadoEm: m['atualizado_em'] as String,
        atualizadoPor: m['atualizado_por'] as String?,
      );
}

final precosPostoProvider = FutureProvider.autoDispose<List<PrecoPosto>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];

  final rows = await SupabaseService.client
      .from('precos_postos')
      .select('combustivel, preco, atualizado_em, atualizado_por')
      .eq('empresa_posto_id', empresaId);

  return rows.map((m) => PrecoPosto.fromMap(m)).toList();
});

class PrecosPostoService {
  final _supabase = SupabaseService.client;

  // "precos": mapa combustivel -> preço em texto (campo em branco = não
  // grava linha, igual à web — não exclui um preço já salvo). Retorna
  // mensagem de erro, ou null se deu certo.
  Future<String?> salvar({required String empresaPostoId, required Map<String, String> precos}) async {
    final agora = DateTime.now().toUtc().toIso8601String();
    final email = AuthService().emailAtual;
    final linhas = <Map<String, dynamic>>[];

    for (final entry in precos.entries) {
      final bruto = entry.value.trim();
      if (bruto.isEmpty) continue;
      final preco = double.tryParse(bruto.replaceAll(',', '.'));
      if (preco == null || preco <= 0) {
        return 'Preço inválido para "${entry.key}".';
      }
      linhas.add({
        'empresa_posto_id': empresaPostoId,
        'combustivel': entry.key,
        'preco': preco,
        'atualizado_por': email,
        'atualizado_em': agora,
      });
    }

    if (linhas.isEmpty) return 'Informe pelo menos um preço.';

    try {
      await _supabase.from('precos_postos').upsert(linhas, onConflict: 'empresa_posto_id,combustivel');
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
