import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../providers/chamados_provider.dart';

// Fase FLT-2 — PORTA MANUAL de chamados/actions.ts (mesmo aviso já dado em
// negociacoes_service.dart/ajustes_abastecimentos_service.dart: não existe
// RPC pra essa lógica, é regra de negócio replicada à mão no Dart).
class ChamadosService {
  final _supabase = SupabaseService.client;

  // Fase FLT-2 — mesma regra de resolverPapelAtual (chamados/actions.ts):
  // "admin" é o time interno FNI (perfil admin OU o e-mail superusuário
  // fixo), qualquer outro (inclusive posto) é "usuario" pro fim de rotular
  // autor de comentário/anexo e decidir qual coluna de "visto" atualizar.
  Future<String> _resolverPapel() async {
    final email = AuthService().emailAtual;
    if (email == 'd.peruffo@gmail.com') return 'admin';
    final perfil = await _supabase.rpc('perfil_usuario_atual') as String?;
    return perfil == 'admin' ? 'admin' : 'usuario';
  }

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

  Future<void> _enviarAnexo({
    required String ticketId,
    required Uint8List bytes,
    required String nome,
    String? mimeType,
  }) async {
    final autorEmail = AuthService().emailAtual ?? '';
    final caminho = '$ticketId/${DateTime.now().millisecondsSinceEpoch}_${_sanitizarNomeParaStorage(nome)}';
    await _supabase.storage.from(ticketBucketAnexos).uploadBinary(
          caminho,
          bytes,
          fileOptions: FileOptions(contentType: mimeType),
        );
    await _supabase.from('ticket_anexos').insert({
      'ticket_id': ticketId,
      'nome': nome,
      'tipo_mime': mimeType,
      'tamanho': bytes.length,
      'url': caminho,
      'autor_email': autorEmail,
    });
    // Anexo também conta como atualização do chamado pra fins de
    // notificação visual (mesmo comentário da web em enviarAnexo()).
    await _supabase.from('tickets').update({'atualizado_em': DateTime.now().toIso8601String()}).eq('id', ticketId);
  }

  Future<String> criarChamado({
    required String empresaId,
    required String tipo,
    required String titulo,
    required String descricao,
    required String prioridade,
    Uint8List? anexoBytes,
    String? anexoNome,
    String? anexoMime,
  }) async {
    final email = AuthService().emailAtual;
    if (email == null) throw Exception('Sessão expirada, faça login novamente.');

    final inserido = await _supabase
        .from('tickets')
        .insert({
          'empresa_id': empresaId,
          'user_email': email,
          'tipo': tipo,
          'titulo': titulo,
          'descricao': descricao,
          'prioridade': prioridade,
          'status': 'aberto',
          'usuario_visto_em': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();
    final ticketId = inserido['id'].toString();

    // Fase FLT-2 — mesmo tratamento best-effort da web (criarChamadoAcao):
    // falha no anexo não pode derrubar a abertura do chamado, que já
    // comitou.
    if (anexoBytes != null && anexoNome != null) {
      try {
        await _enviarAnexo(ticketId: ticketId, bytes: anexoBytes, nome: anexoNome, mimeType: anexoMime);
      } catch (_) {
        // Ignorado de propósito — chamado foi criado, anexo pode ser
        // reenviado depois pela tela de detalhe.
      }
    }

    return ticketId;
  }

  Future<void> enviarAnexoNoChamado({
    required String ticketId,
    required Uint8List bytes,
    required String nome,
    String? mimeType,
  }) async {
    await _enviarAnexo(ticketId: ticketId, bytes: bytes, nome: nome, mimeType: mimeType);
  }

  Future<void> comentar(String ticketId, String texto) async {
    final textoLimpo = texto.trim();
    if (textoLimpo.isEmpty) throw Exception('Escreva uma mensagem.');
    final email = AuthService().emailAtual;
    if (email == null) throw Exception('Sessão expirada, faça login novamente.');
    final papel = await _resolverPapel();

    await _supabase.from('ticket_comentarios').insert({
      'ticket_id': ticketId,
      'autor_email': email,
      'autor_tipo': papel,
      'texto': textoLimpo,
    });

    await marcarVisto(ticketId);
  }

  Future<void> marcarVisto(String ticketId) async {
    final papel = await _resolverPapel();
    final agora = DateTime.now().toIso8601String();
    if (papel == 'admin') {
      await _supabase.from('tickets').update({'admin_visto_em': agora}).eq('id', ticketId);
    } else {
      await _supabase.from('tickets').update({'usuario_visto_em': agora}).eq('id', ticketId);
    }
  }

  Future<void> marcarResolvido(String ticketId) async {
    await _supabase
        .from('tickets')
        .update({'status': 'resolvido', 'atualizado_em': DateTime.now().toIso8601String()}).eq('id', ticketId);
  }
}
