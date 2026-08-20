import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase Grupo 2 (Rodopar/Datapar, item 5, 03/08/2026) — CRM Comercial
// (cliente), porta de crm-comercial/page.tsx + clientes/[id]/page.tsx +
// actions.ts + src/lib/crm.ts. Não duplica nada: "cliente" continua sendo
// cadastros_parceiros (papel='tomador') e "proposta" continua sendo
// cotacoes — só lê os dois aqui (não existe ainda simulador de cotação no
// Flutter, então o funil é read-only). O único dado novo é
// clientes_interacoes (histórico de relacionamento).

const tipoInteracaoLabel = {
  'ligacao': 'Ligação',
  'email': 'E-mail',
  'whatsapp': 'WhatsApp',
  'reuniao': 'Reunião',
  'visita': 'Visita',
  'outro': 'Outro',
};

const statusPropostaLabel = {
  'simulada': 'Em aberto',
  'convertida': 'Ganha',
  'descartada': 'Perdida',
};

class ClienteCrm {
  final String id;
  final String empresaId;
  final String cnpjCpf;
  final String razaoSocial;
  final String? ie;
  final String? enderecoLogradouro;
  final String? enderecoNumero;
  final String? enderecoBairro;
  final String? enderecoMunicipio;
  final String? enderecoUf;
  final String? enderecoCep;
  final String? telefone;
  final String? email;

  const ClienteCrm({
    required this.id,
    required this.empresaId,
    required this.cnpjCpf,
    required this.razaoSocial,
    this.ie,
    this.enderecoLogradouro,
    this.enderecoNumero,
    this.enderecoBairro,
    this.enderecoMunicipio,
    this.enderecoUf,
    this.enderecoCep,
    this.telefone,
    this.email,
  });

  factory ClienteCrm.fromMap(Map<String, dynamic> m) => ClienteCrm(
        id: m['id'] as String,
        empresaId: m['empresa_id'] as String,
        cnpjCpf: m['cnpj_cpf'] as String,
        razaoSocial: m['razao_social'] as String,
        ie: m['ie'] as String?,
        enderecoLogradouro: m['endereco_logradouro'] as String?,
        enderecoNumero: m['endereco_numero'] as String?,
        enderecoBairro: m['endereco_bairro'] as String?,
        enderecoMunicipio: m['endereco_municipio'] as String?,
        enderecoUf: m['endereco_uf'] as String?,
        enderecoCep: m['endereco_cep'] as String?,
        telefone: m['telefone'] as String?,
        email: m['email'] as String?,
      );
}

const _colunasCliente =
    'id, empresa_id, cnpj_cpf, razao_social, ie, endereco_logradouro, endereco_numero, endereco_bairro, endereco_municipio, endereco_uf, endereco_cep, telefone, email';

final clientesCrmListProvider =
    FutureProvider.autoDispose<List<ClienteCrm>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client
      .from('cadastros_parceiros')
      .select(_colunasCliente)
      .eq('empresa_id', empresaId)
      .eq('papel', 'tomador')
      .order('razao_social') as List;
  return rows
      .map((r) => ClienteCrm.fromMap(r as Map<String, dynamic>))
      .toList();
});

final clienteCrmDetalheProvider =
    FutureProvider.autoDispose.family<ClienteCrm?, String>((ref, id) async {
  final row = await SupabaseService.client
      .from('cadastros_parceiros')
      .select(_colunasCliente)
      .eq('id', id)
      .maybeSingle();
  if (row == null) return null;
  return ClienteCrm.fromMap(row);
});

class CotacaoResumo {
  final String id;
  final String origemLabel;
  final String destinoLabel;
  final double valorTotal;
  final String status;
  final String criadoEm;

  const CotacaoResumo({
    required this.id,
    required this.origemLabel,
    required this.destinoLabel,
    required this.valorTotal,
    required this.status,
    required this.criadoEm,
  });

  factory CotacaoResumo.fromMap(Map<String, dynamic> m) => CotacaoResumo(
        id: m['id'] as String,
        origemLabel: m['origem_label'] as String,
        destinoLabel: m['destino_label'] as String,
        valorTotal: (m['valor_total'] as num?)?.toDouble() ?? 0,
        status: m['status'] as String,
        criadoEm: m['criado_em'] as String,
      );
}

final cotacoesClienteProvider = FutureProvider.autoDispose
    .family<List<CotacaoResumo>, String>((ref, clienteId) async {
  final rows = await SupabaseService.client
      .from('cotacoes')
      .select('id, origem_label, destino_label, valor_total, status, criado_em')
      .eq('cliente_tomador_id', clienteId)
      .order('criado_em', ascending: false) as List;
  return rows
      .map((r) => CotacaoResumo.fromMap(r as Map<String, dynamic>))
      .toList();
});

class InteracaoCrm {
  final String id;
  final String tipo;
  final String descricao;
  final String? proximaAcaoData;
  final String? criadoPor;
  final String criadoEm;

  const InteracaoCrm({
    required this.id,
    required this.tipo,
    required this.descricao,
    this.proximaAcaoData,
    this.criadoPor,
    required this.criadoEm,
  });

  factory InteracaoCrm.fromMap(Map<String, dynamic> m) => InteracaoCrm(
        id: m['id'] as String,
        tipo: m['tipo'] as String,
        descricao: m['descricao'] as String,
        proximaAcaoData: m['proxima_acao_data'] as String?,
        criadoPor: m['criado_por'] as String?,
        criadoEm: m['criado_em'] as String,
      );
}

final interacoesClienteProvider = FutureProvider.autoDispose
    .family<List<InteracaoCrm>, String>((ref, clienteId) async {
  final rows = await SupabaseService.client
      .from('clientes_interacoes')
      .select('id, tipo, descricao, proxima_acao_data, criado_por, criado_em')
      .eq('cliente_id', clienteId)
      .order('criado_em', ascending: false) as List;
  return rows
      .map((r) => InteracaoCrm.fromMap(r as Map<String, dynamic>))
      .toList();
});
