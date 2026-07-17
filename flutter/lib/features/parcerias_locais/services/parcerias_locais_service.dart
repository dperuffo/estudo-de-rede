import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

// Fase PWA-Parcerias-Locais — porta de actions.ts (criarItemParceria,
// atualizarItemParceria, alternarAtivoItemParceria, excluirItemParceria,
// atualizarStatusResgateProprio, queimarVoucher). RLS
// (fidelidade_catalogo_itens_dono_gerencia) já garante que só dá pra
// mexer em item cujo criador_empresa_id seja uma empresa do usuário —
// não precisamos duplicar a checagem de permissão aqui, só deixar o erro
// do Postgrest borbulhar com mensagem amigável.

const bucketFidelidadeImagens = 'fidelidade-imagens';

class ParceriasLocaisService {
  final _supabase = SupabaseService.client;

  String _caminhoImagem(String empresaId, String nomeOriginal) {
    final ponto = nomeOriginal.lastIndexOf('.');
    final ext = ponto >= 0 ? nomeOriginal.substring(ponto) : '';
    var base = (ponto >= 0 ? nomeOriginal.substring(0, ponto) : nomeOriginal).toLowerCase();
    base = base.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    if (base.length > 40) base = base.substring(0, 40);
    final agora = DateTime.now().millisecondsSinceEpoch;
    return '$empresaId/$agora-${base.isEmpty ? 'imagem' : base}$ext';
  }

  Future<String> enviarImagem({
    required String empresaId,
    required Uint8List bytes,
    required String nomeArquivo,
  }) async {
    if (bytes.lengthInBytes > 3 * 1024 * 1024) {
      throw Exception('Imagem grande demais (máximo 3 MB).');
    }
    final caminho = _caminhoImagem(empresaId, nomeArquivo);
    await _supabase.storage
        .from(bucketFidelidadeImagens)
        .uploadBinary(caminho, bytes, fileOptions: const FileOptions(upsert: true));
    return _supabase.storage.from(bucketFidelidadeImagens).getPublicUrl(caminho);
  }

  Future<void> criar({
    required String empresaId,
    required String categoria,
    required String titulo,
    String? descricao,
    String? parceiroNome,
    required int pontosNecessarios,
    int? validadeDias,
    String? imagemUrl,
  }) async {
    if (titulo.trim().isEmpty) throw Exception('O título é obrigatório.');
    if (pontosNecessarios <= 0) throw Exception('Pontos necessários precisa ser maior que zero.');

    await _supabase.from('fidelidade_catalogo_itens').insert({
      'categoria': categoria,
      'titulo': titulo.trim(),
      'descricao': descricao?.trim().isEmpty == true ? null : descricao?.trim(),
      'parceiro_nome': parceiroNome?.trim().isEmpty == true ? null : parceiroNome?.trim(),
      'pontos_necessarios': pontosNecessarios,
      'criador_empresa_id': empresaId,
      'imagem_url': imagemUrl,
      'validade_dias': validadeDias,
    });
  }

  Future<void> atualizar({
    required String id,
    required String categoria,
    required String titulo,
    String? descricao,
    String? parceiroNome,
    required int pontosNecessarios,
    int? validadeDias,
    required bool ativo,
    String? imagemUrl,
  }) async {
    if (titulo.trim().isEmpty) throw Exception('O título é obrigatório.');
    if (pontosNecessarios <= 0) throw Exception('Pontos necessários precisa ser maior que zero.');

    final linha = <String, dynamic>{
      'categoria': categoria,
      'titulo': titulo.trim(),
      'descricao': descricao?.trim().isEmpty == true ? null : descricao?.trim(),
      'parceiro_nome': parceiroNome?.trim().isEmpty == true ? null : parceiroNome?.trim(),
      'pontos_necessarios': pontosNecessarios,
      'validade_dias': validadeDias,
      'ativo': ativo,
      'atualizado_em': DateTime.now().toIso8601String(),
    };
    if (imagemUrl != null) linha['imagem_url'] = imagemUrl;

    await _supabase.from('fidelidade_catalogo_itens').update(linha).eq('id', id);
  }

  Future<void> alternarAtivo(String id, bool ativo) async {
    await _supabase
        .from('fidelidade_catalogo_itens')
        .update({'ativo': ativo, 'atualizado_em': DateTime.now().toIso8601String()}).eq('id', id);
  }

  Future<void> excluir(String id) async {
    await _supabase.from('fidelidade_catalogo_itens').delete().eq('id', id);
  }

  static const statusResgateProprio = ['em_andamento', 'cancelado'];

  Future<void> atualizarStatusResgate(String id, String status) async {
    if (!statusResgateProprio.contains(status)) return;
    await _supabase
        .from('fidelidade_resgates')
        .update({'status': status, 'atualizado_em': DateTime.now().toIso8601String()}).eq('id', id);
  }

  // Queima do voucher — exige o código exibido no app do motorista, mesma
  // validação da web: existe, pertence a um benefício DESTA empresa, ainda
  // não foi usado/cancelado, e não venceu.
  Future<({String titulo, String motorista})> queimarVoucher({
    required String empresaId,
    required String codigo,
  }) async {
    final codigoNormalizado = codigo.trim().toUpperCase();
    if (codigoNormalizado.isEmpty) throw Exception('Digite o código do voucher.');

    final resgate = await _supabase
        .from('fidelidade_resgates')
        .select('id, titulo, status, valido_ate, item_id, motoristas(nome_completo)')
        .eq('numero_voucher', codigoNormalizado)
        .maybeSingle();

    if (resgate == null) {
      throw Exception('Voucher não encontrado. Confira o código com o motorista.');
    }

    final item = await _supabase
        .from('fidelidade_catalogo_itens')
        .select('criador_empresa_id')
        .eq('id', resgate['item_id'] as String)
        .maybeSingle();

    if (item == null || item['criador_empresa_id'] != empresaId) {
      throw Exception('Esse voucher não pertence a um benefício desta empresa.');
    }
    if (resgate['status'] == 'concluido') throw Exception('Esse voucher já foi queimado antes.');
    if (resgate['status'] == 'cancelado') {
      throw Exception('Esse voucher foi cancelado — não pode ser queimado.');
    }
    final validoAte = resgate['valido_ate'] as String?;
    if (validoAte != null && DateTime.parse(validoAte).isBefore(DateTime.now())) {
      throw Exception('Esse voucher venceu em ${_formatarData(validoAte)}.');
    }

    await _supabase
        .from('fidelidade_resgates')
        .update({'status': 'concluido', 'atualizado_em': DateTime.now().toIso8601String()}).eq(
            'id', resgate['id'] as String);

    final motoristaMap = resgate['motoristas'] as Map<String, dynamic>?;
    return (
      titulo: resgate['titulo'] as String? ?? '',
      motorista: motoristaMap?['nome_completo'] as String? ?? 'motorista',
    );
  }

  String _formatarData(String iso) {
    final d = DateTime.parse(iso);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
