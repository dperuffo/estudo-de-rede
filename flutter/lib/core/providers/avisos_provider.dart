import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/sessao_provider.dart';
import '../services/supabase_service.dart';

// Fase Central-Avisos (28/07/2026) — pedido do Daniel: "Central de Avisos é
// uma funcionalidade do admin da aplicação para os clientes, motoristas e
// postos". Port 1:1 da lógica de `listarAvisosAcao` em
// src/app/(dashboard)/administracao/central-avisos/actions.ts (web): busca
// `comunicados` ativos dentro da janela de publicação/expiração, filtra por
// segmento/plano/empresa do usuário (array vazio na coluna = visível a
// todos) e calcula `lido` a partir de `comunicados_leituras`.
class AvisoUsuario {
  final String id;
  final String tipo; // novidade | correcao | manutencao | aviso_geral
  final String urgencia; // informativo | atencao | critico
  final String titulo;
  final String resumo;
  final String corpo;
  final String? imagemPath;
  final bool fixado;
  final String dataPublicacao;
  final String? dataExpiracao;
  final bool lido;

  const AvisoUsuario({
    required this.id,
    required this.tipo,
    required this.urgencia,
    required this.titulo,
    required this.resumo,
    required this.corpo,
    required this.imagemPath,
    required this.fixado,
    required this.dataPublicacao,
    required this.dataExpiracao,
    required this.lido,
  });

  String? get urlImagem {
    if (imagemPath == null || imagemPath!.isEmpty) return null;
    return '${SupabaseService.supabaseUrl}/storage/v1/object/public/comunicados-imagens/$imagemPath';
  }
}

// Busca a lista completa (dentro da janela de exibição, sem os já
// expirados) — usada tanto pro sino/badge quanto pro drawer/lista.
final avisosProvider = FutureProvider.autoDispose<List<AvisoUsuario>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final supabase = SupabaseService.client;
  if (sessao.email.isEmpty) return [];

  final agora = DateTime.now().toUtc().toIso8601String();
  final linhas = await supabase
      .from('comunicados')
      .select(
          'id, tipo, urgencia, titulo, resumo, corpo, imagem_path, segmentos_alvo, planos_alvo, empresas_alvo, fixado, data_publicacao, data_expiracao')
      .eq('ativo', true)
      .lte('data_publicacao', agora)
      .or('data_expiracao.is.null,data_expiracao.gte.$agora')
      .order('fixado', ascending: false)
      .order('data_publicacao', ascending: false) as List;

  if (linhas.isEmpty) return [];

  // Resolve segmento/plano da(s) empresa(s) do usuário — mesma ideia de
  // `empresas_do_usuario` na web (aqui já vem pronto em `sessao.empresasIds`).
  final idsEmpresa = sessao.empresasIds;
  var segmentosUsuario = <String>{};
  var planosUsuario = <String>{};
  if (idsEmpresa.isNotEmpty) {
    final empresasData =
        await supabase.from('empresas').select('id, segmento, plano').inFilter('id', idsEmpresa) as List;
    for (final e in empresasData) {
      final m = e as Map<String, dynamic>;
      final seg = m['segmento'] as String?;
      final plano = m['plano'] as String?;
      if (seg != null) segmentosUsuario.add(seg);
      if (plano != null) planosUsuario.add(plano);
    }
  }

  final visiveis = linhas.where((l) {
    final m = l as Map<String, dynamic>;
    final segmentosAlvo = ((m['segmentos_alvo'] as List?) ?? []).cast<String>();
    final planosAlvo = ((m['planos_alvo'] as List?) ?? []).cast<String>();
    final empresasAlvo = ((m['empresas_alvo'] as List?) ?? []).cast<String>();
    final segOk = segmentosAlvo.isEmpty || segmentosAlvo.any(segmentosUsuario.contains);
    final planoOk = planosAlvo.isEmpty || planosAlvo.any(planosUsuario.contains);
    final empresaOk = empresasAlvo.isEmpty || empresasAlvo.any(idsEmpresa.contains);
    return segOk && planoOk && empresaOk;
  }).toList();

  final leituras =
      await supabase.from('comunicados_leituras').select('comunicado_id').eq('usuario_email', sessao.email) as List;
  final lidosSet = leituras.map((l) => (l as Map<String, dynamic>)['comunicado_id'] as String).toSet();

  return visiveis.map((l) {
    final m = l as Map<String, dynamic>;
    final id = m['id'] as String;
    return AvisoUsuario(
      id: id,
      tipo: m['tipo'] as String,
      urgencia: m['urgencia'] as String,
      titulo: m['titulo'] as String,
      resumo: m['resumo'] as String,
      corpo: m['corpo'] as String,
      imagemPath: m['imagem_path'] as String?,
      fixado: m['fixado'] as bool,
      dataPublicacao: m['data_publicacao'] as String,
      dataExpiracao: m['data_expiracao'] as String?,
      lido: lidosSet.contains(id),
    );
  }).toList();
});

final avisosNaoLidosProvider = Provider.autoDispose<int>((ref) {
  final avisos = ref.watch(avisosProvider).valueOrNull ?? const [];
  return avisos.where((a) => !a.lido).length;
});

// Grava a leitura (upsert — mesma ideia do `marcarAvisoLidoAcao` na web) e
// invalida o provider pra badge/lista refletirem na hora. Sempre chamado a
// partir de um widget (ConsumerWidget/ConsumerStatefulWidget), por isso
// recebe `WidgetRef`.
Future<void> marcarAvisoLido(WidgetRef ref, String comunicadoId) async {
  final sessao = await ref.read(sessaoProvider.future);
  if (sessao.email.isEmpty) return;
  try {
    await SupabaseService.client.from('comunicados_leituras').upsert(
      {'comunicado_id': comunicadoId, 'usuario_email': sessao.email},
      onConflict: 'comunicado_id,usuario_email',
      ignoreDuplicates: true,
    );
  } catch (_) {
    // Best-effort — mesmo espírito das demais gravações "silenciosas" do
    // app (ex.: marcarVisto de chamados): falha aqui não deve travar a UI.
  }
  ref.invalidate(avisosProvider);
}
