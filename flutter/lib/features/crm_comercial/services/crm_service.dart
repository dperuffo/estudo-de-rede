import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

// Fase Grupo 2 (Rodopar/Datapar, item 5, 03/08/2026) — porta de
// crm-comercial/actions.ts.
class CrmService {
  final _supabase = SupabaseService.client;

  Future<String> criarCliente({
    required String empresaId,
    required String cnpjCpf,
    required String razaoSocial,
    String? ie,
    String? enderecoLogradouro,
    String? enderecoNumero,
    String? enderecoBairro,
    String? enderecoMunicipio,
    String? enderecoUf,
    String? enderecoCep,
    String? telefone,
    String? email,
    String? criadoPor,
  }) async {
    try {
      final cliente = await _supabase
          .from('cadastros_parceiros')
          .insert({
            'empresa_id': empresaId,
            'papel': 'tomador',
            'cnpj_cpf': cnpjCpf,
            'razao_social': razaoSocial,
            'ie': ie,
            'endereco_logradouro': enderecoLogradouro,
            'endereco_numero': enderecoNumero,
            'endereco_bairro': enderecoBairro,
            'endereco_municipio': enderecoMunicipio,
            'endereco_uf': enderecoUf,
            'endereco_cep': enderecoCep,
            'telefone': telefone,
            'email': email,
            'criado_por': criadoPor,
          })
          .select('id')
          .single();
      return cliente['id'] as String;
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw Exception('Já existe um cliente cadastrado com esse CNPJ/CPF.');
      }
      throw Exception(e.message);
    }
  }

  Future<void> editarCliente({
    required String clienteId,
    required String razaoSocial,
    String? ie,
    String? enderecoLogradouro,
    String? enderecoNumero,
    String? enderecoBairro,
    String? enderecoMunicipio,
    String? enderecoUf,
    String? enderecoCep,
    String? telefone,
    String? email,
  }) async {
    await _supabase.from('cadastros_parceiros').update({
      'razao_social': razaoSocial,
      'ie': ie,
      'endereco_logradouro': enderecoLogradouro,
      'endereco_numero': enderecoNumero,
      'endereco_bairro': enderecoBairro,
      'endereco_municipio': enderecoMunicipio,
      'endereco_uf': enderecoUf,
      'endereco_cep': enderecoCep,
      'telefone': telefone,
      'email': email,
      'atualizado_em': DateTime.now().toIso8601String(),
    }).eq('id', clienteId);
  }

  Future<void> criarInteracao({
    required String empresaId,
    required String clienteId,
    required String tipo,
    required String descricao,
    String? proximaAcaoData,
    String? criadoPor,
  }) async {
    await _supabase.from('clientes_interacoes').insert({
      'empresa_id': empresaId,
      'cliente_id': clienteId,
      'tipo': tipo,
      'descricao': descricao,
      'proxima_acao_data': proximaAcaoData,
      'criado_por': criadoPor,
    });
  }

  Future<void> excluirInteracao(String interacaoId) async {
    await _supabase.from('clientes_interacoes').delete().eq('id', interacaoId);
  }
}
