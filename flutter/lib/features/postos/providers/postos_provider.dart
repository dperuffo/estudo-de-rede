import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — Postos Revendedores (cliente), porta de
// src/app/(dashboard)/postos/page.tsx + [cnpj]/page.tsx + actions.ts.
// Escopo reduzido: mantém as 2 abas que importam no dia a dia — "Rede do
// cliente" (postos_gf da empresa, com toggle bloqueado/liberado e preços) e
// "Explorar universo ANP" (buscar por nome/CNPJ/município e ativar um posto
// novo na rede). Fora do escopo: aba "Inteligência da Minha Frota" (dado
// já coberto, de forma reduzida, pela tela Inteligência de Rede que existe
// no Flutter desde a Fase FLT-3), importação por planilha
// (`/postos/importar`, `/postos/importar-precos`) e "Atualizar universo
// ANP" (admin only). A edição dos campos operacionais do posto (perfil de
// venda, horário, ARLA etc. — `PostoForm` na web) também fica de fora do
// v1; o detalhe aqui é leitura dos dados de origem + ações (bloquear,
// remover, preços).
const ufsBrasil = [
  'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', 'MG',
  'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO',
];

const produtosPostoRevendedor = [
  'Gasolina Comum',
  'Gasolina Aditivada',
  'Gasolina Alta Octanagem',
  'Etanol Comum',
  'Etanol Aditivado',
  'Diesel S-10 Comum',
  'Diesel S-10 Aditivado',
  'Diesel S-500 Comum',
  'Diesel S-500 Aditivado',
  'GNV',
  'GLP',
];

class PostoRede {
  final String cnpj;
  final String? razaoSocial;
  final String? municipio;
  final String? uf;
  final String? bandeira;
  final bool ativo;
  final String? distribuidora;
  final String? bairro;
  final String? logradouro;
  final String? numero;
  final String? complemento;
  final String? cep;
  final String? nomeContato;
  final String? telefoneContato;
  final String? nomeResponsavel;
  final String? telefoneResponsavel;
  final String? grupoEconomico;
  final String? rede;
  final String? statusPdv;
  final String? situacaoPdv;
  final String? dataHabilitacao;
  final String? outrosServicos;
  final bool possuiRestaurante;
  final bool possuiBanheiro;
  final bool possuiEstacionamento;
  final bool possuiTrocaOleo;
  final bool possuiInternet;
  final bool arla;
  final String? tipoArla;

  const PostoRede({
    required this.cnpj,
    this.razaoSocial,
    this.municipio,
    this.uf,
    this.bandeira,
    required this.ativo,
    this.distribuidora,
    this.bairro,
    this.logradouro,
    this.numero,
    this.complemento,
    this.cep,
    this.nomeContato,
    this.telefoneContato,
    this.nomeResponsavel,
    this.telefoneResponsavel,
    this.grupoEconomico,
    this.rede,
    this.statusPdv,
    this.situacaoPdv,
    this.dataHabilitacao,
    this.outrosServicos,
    required this.possuiRestaurante,
    required this.possuiBanheiro,
    required this.possuiEstacionamento,
    required this.possuiTrocaOleo,
    required this.possuiInternet,
    required this.arla,
    this.tipoArla,
  });

  factory PostoRede.fromMap(Map<String, dynamic> m) {
    return PostoRede(
      cnpj: m['cnpj'] as String,
      razaoSocial: m['razao_social'] as String?,
      municipio: m['municipio'] as String?,
      uf: m['uf'] as String?,
      bandeira: m['bandeira'] as String?,
      ativo: m['ativo'] as bool? ?? true,
      distribuidora: m['distribuidora'] as String?,
      bairro: m['bairro'] as String?,
      logradouro: m['logradouro'] as String?,
      numero: m['numero'] as String?,
      complemento: m['complemento'] as String?,
      cep: m['cep'] as String?,
      nomeContato: m['nome_contato'] as String?,
      telefoneContato: m['telefone_contato'] as String?,
      nomeResponsavel: m['nome_responsavel'] as String?,
      telefoneResponsavel: m['telefone_responsavel'] as String?,
      grupoEconomico: m['grupo_economico'] as String?,
      rede: m['rede'] as String?,
      statusPdv: m['status_pdv'] as String?,
      situacaoPdv: m['situacao_pdv'] as String?,
      dataHabilitacao: m['data_habilitacao'] as String?,
      outrosServicos: m['outros_servicos'] as String?,
      possuiRestaurante: m['possui_restaurante'] as bool? ?? false,
      possuiBanheiro: m['possui_banheiro'] as bool? ?? false,
      possuiEstacionamento: m['possui_estacionamento'] as bool? ?? false,
      possuiTrocaOleo: m['possui_troca_oleo'] as bool? ?? false,
      possuiInternet: m['possui_internet'] as bool? ?? false,
      arla: m['arla'] as bool? ?? false,
      tipoArla: m['tipo_arla'] as String?,
    );
  }

  String get enderecoCompleto =>
      [logradouro, numero, complemento, bairro, cep].where((v) => v != null && v.isNotEmpty).join(', ');
}

const _colunasPostoGf = 'cnpj, razao_social, municipio, uf, bandeira, ativo, distribuidora, bairro, '
    'logradouro, numero, complemento, cep, nome_contato, telefone_contato, nome_responsavel, '
    'telefone_responsavel, grupo_economico, rede, status_pdv, situacao_pdv, data_habilitacao, '
    'outros_servicos, possui_restaurante, possui_banheiro, possui_estacionamento, possui_troca_oleo, '
    'possui_internet, arla, tipo_arla';

final postosClienteProvider = FutureProvider.autoDispose<List<PostoRede>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client
      .from('postos_gf')
      .select(_colunasPostoGf)
      .eq('empresa_id', empresaId)
      .order('razao_social')
      .limit(500) as List;
  return rows.map((m) => PostoRede.fromMap(m as Map<String, dynamic>)).toList();
});

final postoDetalheProvider = FutureProvider.autoDispose.family<PostoRede?, String>((ref, cnpj) async {
  final lista = await ref.watch(postosClienteProvider.future);
  for (final p in lista) {
    if (p.cnpj == cnpj) return p;
  }
  return null;
});

class PrecoHistorico {
  final int id;
  final String combustivel;
  final double preco;
  final String dataRef;
  final String? fonte;
  const PrecoHistorico({required this.id, required this.combustivel, required this.preco, required this.dataRef, this.fonte});

  factory PrecoHistorico.fromMap(Map<String, dynamic> m) {
    return PrecoHistorico(
      id: m['id'] as int,
      combustivel: m['combustivel'] as String? ?? '—',
      preco: (m['preco'] as num).toDouble(),
      dataRef: m['data_ref'] as String,
      fonte: m['fonte'] as String?,
    );
  }
}

final precosPostoProvider = FutureProvider.autoDispose.family<List<PrecoHistorico>, String>((ref, cnpj) async {
  final rows = await SupabaseService.client
      .from('historico_precos')
      .select('id, combustivel, preco, data_ref, fonte')
      .eq('cnpj', cnpj)
      .order('combustivel')
      .order('data_ref', ascending: false) as List;
  return rows.map((m) => PrecoHistorico.fromMap(m as Map<String, dynamic>)).toList();
});

class AnpPosto {
  final String cnpj;
  final String? razaoSocial;
  final String? municipio;
  final String? uf;
  final String? bandeira;
  const AnpPosto({required this.cnpj, this.razaoSocial, this.municipio, this.uf, this.bandeira});

  factory AnpPosto.fromMap(Map<String, dynamic> m) {
    return AnpPosto(
      cnpj: m['cnpj'] as String,
      razaoSocial: m['razao_social'] as String?,
      municipio: m['municipio'] as String?,
      uf: m['uf'] as String?,
      bandeira: m['bandeira'] as String?,
    );
  }
}

// Busca no universo ANP (35 mil+ postos) só quando o usuário digita algo —
// sem isso seria pesado demais carregar/paginar no celular. Capado em 30
// resultados, sem paginação (busca mais específica se precisar restringir).
class BuscaAnpParams {
  final String texto;
  final String? uf;
  const BuscaAnpParams(this.texto, this.uf);

  @override
  bool operator ==(Object other) => other is BuscaAnpParams && other.texto == texto && other.uf == uf;
  @override
  int get hashCode => Object.hash(texto, uf);
}

final buscaAnpProvider = FutureProvider.autoDispose.family<List<AnpPosto>, BuscaAnpParams>((ref, params) async {
  if (params.texto.trim().length < 3) return [];
  var query = SupabaseService.client
      .from('anp_postos')
      .select('cnpj, razao_social, municipio, uf, bandeira')
      .or('razao_social.ilike.%${params.texto}%,municipio.ilike.%${params.texto}%,cnpj.ilike.%${params.texto}%');
  if (params.uf != null && params.uf!.isNotEmpty) {
    query = query.eq('uf', params.uf!);
  }
  final rows = await query.order('razao_social').limit(30) as List;
  return rows.map((m) => AnpPosto.fromMap(m as Map<String, dynamic>)).toList();
});
