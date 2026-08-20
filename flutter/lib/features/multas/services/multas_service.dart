import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

// Fase Onda-2 (benchmark TicketLog, item #4) — bucket privado do anexo da
// notificação (foto/PDF), mesmas políticas de storage da web (migração
// gestao_multas).
const bucketAnexosMultas = 'multas-anexos';

// Porta de multas/actions.ts. Ciclo: captura manual -> indicação de
// condutor (sugestão via parametros_vinculo_motorista_veiculo, resolvida
// no provider) -> acompanhamento até pagar/recorrer. Ao criar, lança
// automaticamente em contas_pagar (origem = "multa"), mesma regra da web
// (pedido do Daniel: multas/oficinas entram no financeiro do cliente).
class MultasService {
  final _supabase = SupabaseService.client;

  String _sanitizarNomeParaStorage(String nomeOriginal) {
    final semAcentos = nomeOriginal
        .replaceAll(RegExp('[áàâãä]'), 'a')
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[íìîï]'), 'i')
        .replaceAll(RegExp('[óòôõö]'), 'o')
        .replaceAll(RegExp('[úùûü]'), 'u')
        .replaceAll(RegExp('[ç]'), 'c')
        .replaceAll(RegExp('[ÁÀÂÃÄ]'), 'A')
        .replaceAll(RegExp('[ÉÈÊË]'), 'E')
        .replaceAll(RegExp('[ÍÌÎÏ]'), 'I')
        .replaceAll(RegExp('[ÓÒÔÕÖ]'), 'O')
        .replaceAll(RegExp('[ÚÙÛÜ]'), 'U')
        .replaceAll(RegExp('[Ç]'), 'C');
    final seguro = semAcentos.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
    final cortado =
        seguro.length > 150 ? seguro.substring(seguro.length - 150) : seguro;
    return cortado.isEmpty ? 'arquivo' : cortado;
  }

  Future<String> criar({
    required String empresaId,
    required String placa,
    required String dataInfracao,
    String? dataLimiteIndicacao,
    String? numeroAit,
    String? orgaoAutuador,
    String? localInfracao,
    String? descricao,
    String? gravidade,
    int? pontos,
    double? valorOriginal,
    double? valorDesconto,
    String? observacoes,
    String? criadoPor,
    ({Uint8List bytes, String nome, String? mimeType})? anexo,
  }) async {
    final inserida = await _supabase
        .from('multas')
        .insert({
          'empresa_id': empresaId,
          'placa': placa,
          'data_infracao': dataInfracao,
          'data_limite_indicacao': dataLimiteIndicacao,
          'numero_ait': numeroAit,
          'orgao_autuador': orgaoAutuador,
          'local_infracao': localInfracao,
          'descricao': descricao,
          'gravidade': gravidade,
          'pontos': pontos,
          'valor_original': valorOriginal,
          'valor_desconto': valorDesconto,
          'observacoes': observacoes,
          'criado_por': criadoPor,
        })
        .select('id')
        .single();
    final multaId = inserida['id'] as String;

    // Best-effort — mesma blindagem da web: falha no financeiro não desfaz
    // a multa já registrada.
    final valorParaFinanceiro = valorDesconto ?? valorOriginal;
    if (valorParaFinanceiro != null && valorParaFinanceiro > 0) {
      try {
        await _supabase.from('contas_pagar').insert({
          'empresa_id': empresaId,
          'origem': 'multa',
          'referencia_id': multaId,
          'credor_nome': orgaoAutuador ?? 'Multa de trânsito',
          'descricao':
              'Multa ${numeroAit != null ? 'AIT $numeroAit — ' : ''}$placa${descricao != null ? ' — $descricao' : ''}',
          'valor_original': valorParaFinanceiro,
          'vencimento': dataLimiteIndicacao ?? dataInfracao,
          'criado_por': criadoPor,
        });
      } catch (_) {
        // best-effort, não bloqueia o registro da multa
      }
    }

    if (anexo != null) {
      try {
        final caminho =
            '$multaId/${DateTime.now().millisecondsSinceEpoch}_${_sanitizarNomeParaStorage(anexo.nome)}';
        await _supabase.storage.from(bucketAnexosMultas).uploadBinary(
              caminho,
              anexo.bytes,
              fileOptions: FileOptions(contentType: anexo.mimeType),
            );
        await _supabase
            .from('multas')
            .update({'anexo_path': caminho}).eq('id', multaId);
      } catch (_) {
        // best-effort — multa já salva, só o anexo não subiu
      }
    }

    return multaId;
  }

  Future<String?> urlAssinadaAnexo(String? caminho) async {
    if (caminho == null) return null;
    try {
      return await _supabase.storage
          .from(bucketAnexosMultas)
          .createSignedUrl(caminho, 3600);
    } catch (_) {
      return null;
    }
  }

  Future<void> indicarCondutor(
      String multaId, String motoristaId, String? indicadoPor) async {
    await _supabase.from('multas').update({
      'motorista_id': motoristaId,
      'status': 'indicada',
      'indicado_em': DateTime.now().toIso8601String(),
      'indicado_por': indicadoPor,
      'atualizado_em': DateTime.now().toIso8601String(),
    }).eq('id', multaId);
  }

  Future<void> atualizarStatus(String multaId, String novoStatus) async {
    final patch = <String, dynamic>{
      'status': novoStatus,
      'atualizado_em': DateTime.now().toIso8601String()
    };
    if (novoStatus == 'paga')
      patch['pago_em'] = DateTime.now().toIso8601String();
    await _supabase.from('multas').update(patch).eq('id', multaId);

    if (novoStatus == 'paga' || novoStatus == 'cancelada') {
      try {
        final contaVinculada = await _supabase
            .from('contas_pagar')
            .select('id, valor_original')
            .eq('origem', 'multa')
            .eq('referencia_id', multaId)
            .maybeSingle();
        if (contaVinculada != null) {
          final patchConta = novoStatus == 'paga'
              ? {
                  'status': 'pago',
                  'valor_pago': contaVinculada['valor_original'],
                  'pago_em': DateTime.now().toIso8601String()
                }
              : {'status': 'cancelado'};
          await _supabase
              .from('contas_pagar')
              .update(patchConta)
              .eq('id', contaVinculada['id']);
        }
      } catch (_) {
        // best-effort
      }
    }
  }

  Future<void> excluir(String id) async {
    try {
      final registro = await _supabase
          .from('multas')
          .select('anexo_path')
          .eq('id', id)
          .maybeSingle();
      final anexoPath = registro?['anexo_path'] as String?;
      if (anexoPath != null) {
        await _supabase.storage.from(bucketAnexosMultas).remove([anexoPath]);
      }
    } catch (_) {
      // best-effort
    }
    try {
      await _supabase
          .from('contas_pagar')
          .delete()
          .eq('origem', 'multa')
          .eq('referencia_id', id);
    } catch (_) {
      // best-effort
    }
    await _supabase.from('multas').delete().eq('id', id);
  }
}
