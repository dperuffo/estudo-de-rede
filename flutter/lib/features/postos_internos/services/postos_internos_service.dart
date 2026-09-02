import '../../../core/services/supabase_service.dart';

// Fase FLT-Postos-Internos (02/09/2026, pedido do Daniel: "equalizar o PWA
// Cliente com as funcionalidades construídas para a web cliente") — porta
// de postos-internos/page.tsx + actions.ts. Representa a garagem/tanque
// próprio de cada empresa (matriz ou filial): enquanto ativo, aparece como
// opção no PWA Motorista (aba Abastecimento Interno) e entra no custo da
// Roteirização. Mesmas 2 tabelas da web: postos_internos (1 linha por
// empresa) e postos_internos_precos (preço por combustível).
//
// Mesma lista de combustíveis do posto externo (produtosPosto, já usada em
// AbastecimentosPostoService) + Arla32 como linha extra — mantém paridade
// exata com COMBUSTIVEIS_POSTO_INTERNO/ARLA32 em src/lib/constants.ts (web).
const String arla32 = 'Arla32';

class PostoInterno {
  final String id;
  final String empresaId;
  final String? nome;
  final bool ativo;
  const PostoInterno({
    required this.id,
    required this.empresaId,
    required this.nome,
    required this.ativo,
  });
}

class PostosInternosService {
  final _supabase = SupabaseService.client;

  // Porta de obterOuCriarPostoInternoAcao — garante que existe uma linha
  // pra essa empresa (cria com ativo=true na primeira vez) e devolve.
  Future<PostoInterno?> obterOuCriar(String empresaId) async {
    final existente = await _supabase
        .from('postos_internos')
        .select('id, empresa_id, nome, ativo')
        .eq('empresa_id', empresaId)
        .maybeSingle();
    if (existente != null) {
      return PostoInterno(
        id: existente['id'] as String,
        empresaId: existente['empresa_id'] as String,
        nome: existente['nome'] as String?,
        ativo: existente['ativo'] as bool,
      );
    }

    final email = _supabase.auth.currentUser?.email;
    try {
      final criado = await _supabase
          .from('postos_internos')
          .insert({
            'empresa_id': empresaId,
            'ativo': true,
            'atualizado_por': email,
          })
          .select('id, empresa_id, nome, ativo')
          .single();
      return PostoInterno(
        id: criado['id'] as String,
        empresaId: criado['empresa_id'] as String,
        nome: criado['nome'] as String?,
        ativo: criado['ativo'] as bool,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, double>> buscarPrecos(String postoInternoId) async {
    final rows = await _supabase
        .from('postos_internos_precos')
        .select('combustivel, preco')
        .eq('posto_interno_id', postoInternoId);
    return {
      for (final r in rows)
        r['combustivel'] as String: (r['preco'] as num).toDouble(),
    };
  }

  // Porta de salvarDadosPostoInternoAcao.
  Future<String?> salvarDados({
    required String postoInternoId,
    required String empresaId,
    required String? nome,
    required bool ativo,
  }) async {
    final email = _supabase.auth.currentUser?.email;
    try {
      await _supabase
          .from('postos_internos')
          .update({
            'nome': (nome?.trim().isEmpty ?? true) ? null : nome!.trim(),
            'ativo': ativo,
            'atualizado_em': DateTime.now().toUtc().toIso8601String(),
            'atualizado_por': email,
          })
          .eq('id', postoInternoId)
          .eq('empresa_id', empresaId);
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  // Porta de salvarPrecosPostoInternoAcao — só grava os combustíveis com
  // preço preenchido (mesmo comportamento da web: campo vazio = não mexe).
  Future<String?> salvarPrecos({
    required String postoInternoId,
    required Map<String, String> precosPorCombustivel,
  }) async {
    final email = _supabase.auth.currentUser?.email;
    final linhas = <Map<String, dynamic>>[];
    for (final entry in precosPorCombustivel.entries) {
      final bruto = entry.value.trim().replaceAll(',', '.');
      if (bruto.isEmpty) continue;
      final preco = double.tryParse(bruto);
      if (preco == null || preco < 0) {
        return 'Preço inválido para ${entry.key}.';
      }
      linhas.add({
        'posto_interno_id': postoInternoId,
        'combustivel': entry.key,
        'preco': preco,
        'atualizado_por': email,
      });
    }
    if (linhas.isEmpty) return 'Informe ao menos um preço.';

    try {
      await _supabase
          .from('postos_internos_precos')
          .upsert(linhas, onConflict: 'posto_interno_id,combustivel');
      return null;
    } catch (e) {
      return 'Não foi possível salvar os preços: $e';
    }
  }
}
