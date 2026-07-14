import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../posto/providers/documentos_provider.dart'
    show
        SocioEmpresa,
        DocumentoEmpresa,
        SituacaoDocumentacao,
        tiposDocumentoEmpresa,
        tiposDocumentoSocio,
        labelTipoDocumento,
        statusDocumentacaoLabel,
        documentosBucket;
// Achado real (erro de build do Daniel): `import ... show` só torna os
// símbolos visíveis DENTRO deste arquivo — não os repassa pra quem
// importa este provider. As telas (documentos_empresas_lista_screen.dart,
// documentos_empresa_detalhe_screen.dart) usam DocumentoEmpresa/
// statusDocumentacaoLabel/tiposDocumentoEmpresa/tiposDocumentoSocio/
// labelTipoDocumento só importando ESTE arquivo — por isso precisam
// também de um `export` explícito repassando os mesmos símbolos adiante.
export '../../posto/providers/documentos_provider.dart'
    show
        SocioEmpresa,
        DocumentoEmpresa,
        SituacaoDocumentacao,
        tiposDocumentoEmpresa,
        tiposDocumentoSocio,
        labelTipoDocumento,
        statusDocumentacaoLabel;

// Fase FLT-4 — Aprovação de Documentos (admin), porta de
// documentos-empresas/page.tsx + [id]/page.tsx +
// _components/PainelRevisao.tsx + revisarDocumentacao
// (src/lib/empresasDocumentos.ts). RLS conferida antes de portar:
// `empresas_documentos`/`empresas_socios` já liberam SELECT total pro
// admin (mesma policy do resto do FLT-4), e o bucket de Storage
// `documentos-empresas` também libera signed URL pro admin em qualquer
// path. Reaproveita as classes/constantes já portadas na Fase FLT-2 pra
// tela self-service (`SocioEmpresa`, `DocumentoEmpresa`,
// `SituacaoDocumentacao`, tipos de documento, bucket) via `show` de
// `posto/providers/documentos_provider.dart` — só a QUERY muda (aqui é
// por `empresaId` arbitrário escolhido pelo admin, lá é sempre
// `sessao.empresaId`).
const statusDocumentacao = ['nao_iniciada', 'pendente', 'aprovada', 'rejeitada'];

class EmpresaDocumentacaoResumo {
  final String id;
  final String nome;
  final String? cnpj;
  final String? segmento;
  final String documentacaoStatus;
  final String? documentacaoEnviadaEm;
  final String? documentacaoRevisadoEm;

  const EmpresaDocumentacaoResumo({
    required this.id,
    required this.nome,
    this.cnpj,
    this.segmento,
    required this.documentacaoStatus,
    this.documentacaoEnviadaEm,
    this.documentacaoRevisadoEm,
  });

  factory EmpresaDocumentacaoResumo.fromMap(Map<String, dynamic> m) => EmpresaDocumentacaoResumo(
        id: m['id'] as String,
        nome: m['nome'] as String? ?? '—',
        cnpj: m['cnpj'] as String?,
        segmento: m['segmento'] as String?,
        documentacaoStatus: m['documentacao_status'] as String? ?? 'nao_iniciada',
        documentacaoEnviadaEm: m['documentacao_enviada_em'] as String?,
        documentacaoRevisadoEm: m['documentacao_revisado_em'] as String?,
      );
}

final documentosEmpresasListaProvider =
    FutureProvider.autoDispose.family<List<EmpresaDocumentacaoResumo>, String>((ref, status) async {
  final rows = await SupabaseService.client
      .from('empresas')
      .select('id, nome, cnpj, segmento, documentacao_status, documentacao_enviada_em, documentacao_revisado_em')
      .eq('documentacao_status', status)
      .order('documentacao_enviada_em', ascending: true, nullsFirst: true) as List;
  return rows.map((r) => EmpresaDocumentacaoResumo.fromMap(r as Map<String, dynamic>)).toList();
});

final documentosEmpresasContagemProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final supabase = SupabaseService.client;
  final contagens = <String, int>{};
  for (final s in statusDocumentacao) {
    final resp = await supabase.from('empresas').select('id').eq('documentacao_status', s).count(CountOption.exact);
    contagens[s] = resp.count;
  }
  return contagens;
});

class EmpresaDocumentacaoDetalhe {
  final String id;
  final String nome;
  final String? cnpj;
  final String? segmento;
  final SituacaoDocumentacao situacao;
  const EmpresaDocumentacaoDetalhe({required this.id, required this.nome, this.cnpj, this.segmento, required this.situacao});
}

final documentacaoEmpresaDetalheProvider =
    FutureProvider.autoDispose.family<EmpresaDocumentacaoDetalhe?, String>((ref, empresaId) async {
  final supabase = SupabaseService.client;

  final empresa = await supabase.from('empresas').select('id, nome, cnpj, segmento').eq('id', empresaId).maybeSingle();
  if (empresa == null) return null;

  final sociosRaw = await supabase
      .from('empresas_socios')
      .select('id, nome, cpf')
      .eq('empresa_id', empresaId)
      .order('criado_em') as List;
  final socios = sociosRaw.map((m) => SocioEmpresa.fromMap(m as Map<String, dynamic>)).toList();

  final documentosRaw = await supabase
      .from('empresas_documentos')
      .select('id, tipo, socio_id, nome_arquivo, storage_path, enviado_em')
      .eq('empresa_id', empresaId) as List;
  final documentos = documentosRaw.map((m) => DocumentoEmpresa.fromMap(m as Map<String, dynamic>)).toList();

  for (final d in documentos) {
    try {
      d.urlAssinada = await supabase.storage.from(documentosBucket).createSignedUrl(d.storagePath, 3600);
    } catch (_) {
      d.urlAssinada = null;
    }
  }

  final empresaDoc = await supabase
      .from('empresas')
      .select('documentacao_status, documentacao_motivo_rejeicao, documentacao_enviada_em, documentacao_revisado_em')
      .eq('id', empresaId)
      .maybeSingle();

  final situacao = SituacaoDocumentacao(
    empresaId: empresaId,
    socios: socios,
    documentos: documentos,
    status: (empresaDoc?['documentacao_status'] as String?) ?? 'nao_iniciada',
    motivoRejeicao: empresaDoc?['documentacao_motivo_rejeicao'] as String?,
    enviadaEm: empresaDoc?['documentacao_enviada_em'] as String?,
    revisadoEm: empresaDoc?['documentacao_revisado_em'] as String?,
  );

  return EmpresaDocumentacaoDetalhe(
    id: empresa['id'] as String,
    nome: empresa['nome'] as String? ?? '—',
    cnpj: empresa['cnpj'] as String?,
    segmento: empresa['segmento'] as String?,
    situacao: situacao,
  );
});
