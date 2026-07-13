import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-2 — Documentos (documentação societária self-service), porta de
// src/app/(dashboard)/documentos/page.tsx + actions.ts + src/lib/
// empresasDocumentos.ts (Fase 27.149). Mesma tela pra posto e cliente na
// web (só muda o grupo do menu onde o link aparece) — não há bifurcação
// de campos/fluxo por segmento, então a porta é 1:1.

const documentosBucket = 'documentos-empresas';
const documentosTamanhoMaxBytes = 5 * 1024 * 1024;

const tiposDocumentoEmpresa = <String>['contrato_social', 'comprovante_endereco_empresa'];
const tiposDocumentoSocio = <String>['socio_cpf', 'socio_identidade', 'socio_comprovante_endereco'];

const labelTipoDocumento = <String, String>{
  'contrato_social': 'Contrato Social ou Estatuto (com quadro societário)',
  'comprovante_endereco_empresa': 'Comprovante de endereço da empresa (IPTU, conta de consumo...)',
  'socio_cpf': 'CPF',
  'socio_identidade': 'RG ou CNH',
  'socio_comprovante_endereco': 'Comprovante de endereço',
};

const statusDocumentacaoLabel = <String, String>{
  'nao_iniciada': 'Documentação não iniciada',
  'pendente': 'Em análise pelo admin',
  'aprovada': 'Documentação aprovada',
  'rejeitada': 'Documentação rejeitada',
};

String formatarTamanhoArquivo(int? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

// Espelha caminhoStorage (empresasDocumentos.ts): {empresa_id}/{tipo}.{ext}
// pra doc de empresa, {empresa_id}/{tipo}-{socio_id}.{ext} pra doc de sócio.
String caminhoStorage(String empresaId, String tipo, String? socioId, String nomeOriginal) {
  final partes = nomeOriginal.split('.');
  final ext = partes.length > 1 ? partes.last.toLowerCase() : 'bin';
  final sufixo = socioId != null ? '$tipo-$socioId' : tipo;
  return '$empresaId/$sufixo.$ext';
}

class SocioEmpresa {
  final String id;
  final String nome;
  final String cpf;
  const SocioEmpresa({required this.id, required this.nome, required this.cpf});

  factory SocioEmpresa.fromMap(Map<String, dynamic> m) => SocioEmpresa(
        id: m['id'] as String,
        nome: m['nome'] as String? ?? '',
        cpf: m['cpf'] as String? ?? '',
      );
}

class DocumentoEmpresa {
  final String id;
  final String tipo;
  final String? socioId;
  final String nomeArquivo;
  final String storagePath;
  final String? enviadoEm;
  String? urlAssinada;

  DocumentoEmpresa({
    required this.id,
    required this.tipo,
    this.socioId,
    required this.nomeArquivo,
    required this.storagePath,
    this.enviadoEm,
    this.urlAssinada,
  });

  factory DocumentoEmpresa.fromMap(Map<String, dynamic> m) => DocumentoEmpresa(
        id: m['id'] as String,
        tipo: m['tipo'] as String? ?? '',
        socioId: m['socio_id'] as String?,
        nomeArquivo: m['nome_arquivo'] as String? ?? '',
        storagePath: m['storage_path'] as String? ?? '',
        enviadoEm: m['enviado_em'] as String?,
      );
}

class SituacaoDocumentacao {
  final String empresaId;
  final List<SocioEmpresa> socios;
  final List<DocumentoEmpresa> documentos;
  final String status;
  final String? motivoRejeicao;
  final String? enviadaEm;
  final String? revisadoEm;

  const SituacaoDocumentacao({
    required this.empresaId,
    required this.socios,
    required this.documentos,
    required this.status,
    this.motivoRejeicao,
    this.enviadaEm,
    this.revisadoEm,
  });

  DocumentoEmpresa? documentoDe(String tipo, {String? socioId}) {
    for (final d in documentos) {
      if (d.tipo == tipo && d.socioId == socioId) return d;
    }
    return null;
  }
}

final documentosProvider = FutureProvider.autoDispose<SituacaoDocumentacao?>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return null;
  final supabase = SupabaseService.client;

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

  // URLs assinadas (1h) pra abrir/baixar cada documento — best-effort,
  // mesmo padrão de chamados_provider.dart (anexo de ticket).
  for (final d in documentos) {
    try {
      d.urlAssinada = await supabase.storage.from(documentosBucket).createSignedUrl(d.storagePath, 3600);
    } catch (_) {
      d.urlAssinada = null;
    }
  }

  final empresa = await supabase
      .from('empresas')
      .select('documentacao_status, documentacao_motivo_rejeicao, documentacao_enviada_em, documentacao_revisado_em')
      .eq('id', empresaId)
      .maybeSingle();

  return SituacaoDocumentacao(
    empresaId: empresaId,
    socios: socios,
    documentos: documentos,
    status: (empresa?['documentacao_status'] as String?) ?? 'nao_iniciada',
    motivoRejeicao: empresa?['documentacao_motivo_rejeicao'] as String?,
    enviadaEm: empresa?['documentacao_enviada_em'] as String?,
    revisadoEm: empresa?['documentacao_revisado_em'] as String?,
  );
});
