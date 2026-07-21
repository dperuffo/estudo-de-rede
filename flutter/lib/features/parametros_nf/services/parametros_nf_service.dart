import '../../../core/services/supabase_service.dart';

// Fase FLT-Parametros-NF — porta de parametros-nf/actions.ts.
class ParametrosNFService {
  final _supabase = SupabaseService.client;

  String? get _email => _supabase.auth.currentUser?.email;

  // Fase FLT-Parametros-NF-Estado — porta de ExcecaoDestinoUf/
  // lerExcecoesUf (actions.ts): quando localDestino é "Personalizado CNPJ
  // por Estado", `cnpjDestinoPersonalizado` é o CNPJ PADRÃO e `excecoesUf`
  // é a lista achatada (1 item por UF) das exceções — gravadas em
  // parametros_nota_fiscal_destino_uf após a regra ser criada.
  Future<String?> criar({
    required String empresaId,
    String? cnpjFrota,
    required String exigeNotaFiscal,
    required String separarNfCombustivel,
    required String formaEmissao,
    required String localDestino,
    String? cnpjDestinoPersonalizado,
    String? dadosAdicionais,
    String? observacao,
    List<({String uf, String cnpj})> excecoesUf = const [],
  }) async {
    final personalizado = localDestino.startsWith('Personalizado');
    if (personalizado && (cnpjDestinoPersonalizado == null || cnpjDestinoPersonalizado.trim().isEmpty)) {
      return 'Informe o CNPJ de destino para o tipo de destino personalizado escolhido.';
    }
    try {
      final inserida = await _supabase
          .from('parametros_nota_fiscal')
          .insert({
            'empresa_id': empresaId,
            'cnpj_frota': (cnpjFrota == null || cnpjFrota.trim().isEmpty) ? null : cnpjFrota.trim(),
            'exige_nota_fiscal': exigeNotaFiscal,
            'separar_nf_combustivel': separarNfCombustivel,
            'forma_emissao': formaEmissao,
            'local_destino': localDestino,
            'cnpj_destino_personalizado': personalizado ? cnpjDestinoPersonalizado?.trim() : null,
            'dados_adicionais':
                (dadosAdicionais == null || dadosAdicionais.trim().isEmpty) ? null : dadosAdicionais.trim(),
            'observacao': (observacao == null || observacao.trim().isEmpty) ? null : observacao.trim(),
            'criado_por': _email,
          })
          .select('id')
          .single();

      if (localDestino == 'Personalizado CNPJ por Estado' && excecoesUf.isNotEmpty) {
        try {
          await _supabase.from('parametros_nota_fiscal_destino_uf').insert([
            for (final e in excecoesUf) {'parametro_nf_id': inserida['id'], 'uf': e.uf, 'cnpj_destino': e.cnpj},
          ]);
        } catch (e) {
          return 'Regra salva, mas as exceções por estado falharam: $e';
        }
      }
      return null;
    } catch (e) {
      return 'Não foi possível salvar: $e';
    }
  }

  Future<void> alternarStatus({required String id, required bool ativo}) async {
    await _supabase
        .from('parametros_nota_fiscal')
        .update({'status': ativo ? 'Ativo' : 'Inativo', 'atualizado_em': DateTime.now().toIso8601String()}).eq(
            'id', id);
  }

  Future<void> excluir({required String id}) async {
    await _supabase.from('parametros_nota_fiscal').delete().eq('id', id);
  }
}
