import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

// Bucket de evidências fotográficas do checklist de manutenção — mesmo
// bucket já criado pra web (Fase Checklist-Fotos, migration
// checklist_manutencao_fotos), políticas de storage já checam autorização
// por empresa da manutenção (pasta = id da manutenção).
const bucketEvidenciasManutencao = 'manutencao-evidencias';

// Fase FLT-3 — porta de registrarManutencaoAcao/excluirManutencaoAcao
// (manutencao-preditiva/actions.ts). Mesma tabela/formato de
// `itens_realizados` já usados pelo app Flutter de produção, mantendo os
// apps compatíveis com o mesmo histórico.
// Fase Manutencao-Fotos-PWA — pedido do Daniel: "Manutenção Preditiva -
// faltam fotos como evidências". Porta o upload que só existia na web
// (registrarManutencaoAcao, actions.ts:84-106): igual lá, o upload roda
// DEPOIS do insert (precisa do id pra montar o caminho no bucket) e é
// best-effort — falha ao enviar foto não desfaz o registro da manutenção,
// que já foi salvo.
class ManutencaoPreditivaService {
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
    final cortado = seguro.length > 150 ? seguro.substring(seguro.length - 150) : seguro;
    return cortado.isEmpty ? 'arquivo' : cortado;
  }

  // Retorna o id da manutenção inserida (bigint) — precisa dele antes de
  // montar o caminho das fotos no bucket, mesmo motivo da web.
  Future<int> registrar({
    required String empresaId,
    required String placa,
    required String dataManutencao,
    double? hodometro,
    String? tecnico,
    String? oficina,
    double? custoTotal,
    required List<String> itensRealizados,
    String? obsGerais,
    String? criadoPor,
  }) async {
    if (itensRealizados.isEmpty) {
      throw Exception('Selecione ao menos um item realizado.');
    }
    final veiculo = await _supabase.from('cadastro_veiculos').select('cnpj_frota').eq('placa', placa).maybeSingle();

    final inserida = await _supabase
        .from('manutencoes_realizadas')
        .insert({
          'empresa_id': empresaId,
          'cnpj_frota': veiculo?['cnpj_frota'] ?? '',
          'placa': placa,
          'data_manutencao': dataManutencao,
          'hodometro': hodometro,
          'tecnico': (tecnico == null || tecnico.isEmpty) ? null : tecnico,
          'oficina': (oficina == null || oficina.isEmpty) ? null : oficina,
          'custo_total': custoTotal,
          'itens_realizados': itensRealizados,
          'obs_gerais': (obsGerais == null || obsGerais.isEmpty) ? null : obsGerais,
          'criado_por': criadoPor,
        })
        .select('id')
        .single();
    return (inserida['id'] as num).toInt();
  }

  // Envia uma ou mais fotos como evidência de uma manutenção já registrada
  // (o id vem de registrar() acima, ou de uma manutenção já existente no
  // histórico). Best-effort por arquivo — se uma foto falhar, as outras
  // continuam sendo enviadas; retorna um aviso (não exceção) se alguma
  // falhou, pra tela mostrar sem quebrar o fluxo.
  Future<String?> enviarFotos({
    required int manutencaoId,
    required List<({Uint8List bytes, String nome, String? mimeType})> arquivos,
  }) async {
    if (arquivos.isEmpty) return null;
    final caminhos = <String>[];
    var falhas = 0;
    for (final arquivo in arquivos) {
      final caminho = '$manutencaoId/${DateTime.now().millisecondsSinceEpoch}_${_sanitizarNomeParaStorage(arquivo.nome)}';
      try {
        await _supabase.storage.from(bucketEvidenciasManutencao).uploadBinary(
              caminho,
              arquivo.bytes,
              fileOptions: FileOptions(contentType: arquivo.mimeType),
            );
        caminhos.add(caminho);
      } catch (_) {
        falhas++;
      }
    }
    if (caminhos.isNotEmpty) {
      final atual = await _supabase.from('manutencoes_realizadas').select('fotos').eq('id', manutencaoId).single();
      final fotosAtuais = (atual['fotos'] as List?)?.cast<String>() ?? <String>[];
      await _supabase.from('manutencoes_realizadas').update({'fotos': [...fotosAtuais, ...caminhos]}).eq('id', manutencaoId);
    }
    if (falhas > 0) {
      return caminhos.isEmpty
          ? 'Não foi possível enviar as fotos. A manutenção foi salva normalmente.'
          : '$falhas foto(s) não puderam ser enviadas.';
    }
    return null;
  }

  // URLs assinadas (bucket privado) pra exibir as fotos já salvas — mesma
  // validade de 1h da web (createSignedUrl, [placa]/page.tsx).
  Future<List<String>> urlsAssinadas(List<String> caminhos) async {
    if (caminhos.isEmpty) return [];
    final urls = <String>[];
    for (final caminho in caminhos) {
      try {
        final url = await _supabase.storage.from(bucketEvidenciasManutencao).createSignedUrl(caminho, 3600);
        urls.add(url);
      } catch (_) {
        // Best-effort — se uma URL falhar (ex.: arquivo removido), as
        // outras continuam aparecendo.
      }
    }
    return urls;
  }

  Future<void> excluir(int id) async {
    await _supabase.from('manutencoes_realizadas').delete().eq('id', id);
  }
}
