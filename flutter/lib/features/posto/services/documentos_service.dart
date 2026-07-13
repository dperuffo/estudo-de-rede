import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../providers/documentos_provider.dart';

// Fase FLT-2 — PORTA MANUAL de documentos/actions.ts + empresasDocumentos.ts
// (mesmo aviso de negociacoes_service.dart: não existe RPC pra essa lógica,
// é regra de negócio replicada à mão no Dart — inclusive
// `validarDocumentacaoCompleta`, que roda client-side aqui em vez de
// server-side, então é só uma pré-checagem de UX; a fonte da verdade
// continua sendo a RLS de `empresas` + `empresas_documentos`).
class DocumentosService {
  final _supabase = SupabaseService.client;

  Future<String?> adicionarSocio({required String empresaId, required String nome, required String cpf}) async {
    final nomeLimpo = nome.trim();
    final cpfDigitos = cpf.replaceAll(RegExp(r'\D'), '');
    if (nomeLimpo.isEmpty) return 'Informe o nome do sócio.';
    if (cpfDigitos.length != 11) return 'CPF inválido — informe os 11 dígitos.';
    final email = AuthService().emailAtual;
    try {
      await _supabase.from('empresas_socios').insert({
        'empresa_id': empresaId,
        'nome': nomeLimpo,
        'cpf': cpfDigitos,
        'criado_por': email,
      });
      return null;
    } catch (e) {
      return 'Não foi possível cadastrar o sócio: $e';
    }
  }

  Future<String?> removerSocio(String socioId) async {
    try {
      final docs = await _supabase.from('empresas_documentos').select('storage_path').eq('socio_id', socioId) as List;
      for (final d in docs) {
        final path = (d as Map<String, dynamic>)['storage_path'] as String?;
        if (path != null) {
          try {
            await _supabase.storage.from(documentosBucket).remove([path]);
          } catch (_) {
            // best-effort, mesmo padrão da web
          }
        }
      }
      await _supabase.from('empresas_socios').delete().eq('id', socioId);
      return null;
    } catch (e) {
      return 'Não foi possível remover o sócio: $e';
    }
  }

  Future<String?> enviarDocumento({
    required String empresaId,
    required String tipo,
    String? socioId,
    required Uint8List bytes,
    required String nomeArquivo,
    String? mimeType,
  }) async {
    if (bytes.length > documentosTamanhoMaxBytes) {
      return 'Arquivo grande demais (máximo ${formatarTamanhoArquivo(documentosTamanhoMaxBytes)}).';
    }
    final ehDocSocio = tiposDocumentoSocio.contains(tipo);
    final ehDocEmpresa = tiposDocumentoEmpresa.contains(tipo);
    if (ehDocSocio && socioId == null) return 'Documento de sócio precisa de um sócio selecionado.';
    if (ehDocEmpresa && socioId != null) return 'Tipo de documento inválido para sócio.';

    final path = caminhoStorage(empresaId, tipo, socioId, nomeArquivo);
    final email = AuthService().emailAtual;

    try {
      await _supabase.storage.from(documentosBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: true),
          );

      var query = _supabase.from('empresas_documentos').select('id').eq('empresa_id', empresaId).eq('tipo', tipo);
      query = socioId == null ? query.isFilter('socio_id', null) : query.eq('socio_id', socioId);
      final existente = await query.maybeSingle();

      final dados = {
        'empresa_id': empresaId,
        'tipo': tipo,
        'socio_id': socioId,
        'storage_path': path,
        'nome_arquivo': nomeArquivo,
        'tamanho_bytes': bytes.length,
        'enviado_por': email,
        'enviado_em': DateTime.now().toIso8601String(),
      };

      if (existente != null) {
        await _supabase.from('empresas_documentos').update(dados).eq('id', existente['id']);
      } else {
        await _supabase.from('empresas_documentos').insert(dados);
      }
      return null;
    } catch (e) {
      return 'Não foi possível enviar o documento: $e';
    }
  }

  Future<String?> removerDocumento(String documentoId, String storagePath) async {
    try {
      try {
        await _supabase.storage.from(documentosBucket).remove([storagePath]);
      } catch (_) {
        // best-effort
      }
      await _supabase.from('empresas_documentos').delete().eq('id', documentoId);
      return null;
    } catch (e) {
      return 'Não foi possível remover o documento: $e';
    }
  }

  // Espelha validarDocumentacaoCompleta (empresasDocumentos.ts) 1:1.
  String? _validarCompleto(SituacaoDocumentacao dados) {
    if (dados.documentoDe('contrato_social') == null) {
      return 'Envie o Contrato Social ou Estatuto.';
    }
    if (dados.documentoDe('comprovante_endereco_empresa') == null) {
      return 'Envie o comprovante de endereço da empresa.';
    }
    if (dados.socios.isEmpty) {
      return 'Cadastre pelo menos um sócio.';
    }
    for (final s in dados.socios) {
      if (dados.documentoDe('socio_cpf', socioId: s.id) == null) return 'Envie o CPF de ${s.nome}.';
      if (dados.documentoDe('socio_identidade', socioId: s.id) == null) return 'Envie o RG ou CNH de ${s.nome}.';
      if (dados.documentoDe('socio_comprovante_endereco', socioId: s.id) == null) {
        return 'Envie o comprovante de endereço de ${s.nome}.';
      }
    }
    return null;
  }

  Future<String?> enviarParaAnalise(SituacaoDocumentacao dados) async {
    final erroValidacao = _validarCompleto(dados);
    if (erroValidacao != null) return erroValidacao;
    try {
      await _supabase.from('empresas').update({
        'documentacao_status': 'pendente',
        'documentacao_enviada_em': DateTime.now().toIso8601String(),
        'documentacao_motivo_rejeicao': null,
      }).eq('id', dados.empresaId);
      return null;
    } catch (e) {
      return 'Não foi possível enviar para análise: $e';
    }
  }
}
