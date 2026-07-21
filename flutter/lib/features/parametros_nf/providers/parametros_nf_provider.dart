import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-Parametros-NF — porta de parametros-nf/page.tsx + actions.ts.
// Pedido do Daniel: "estes dois últimos desenvolvimentos precisam estar no
// PWA Cliente" (Base de Pedágios e Parâmetros de NF). RLS conferida antes
// de portar: `parametros_nota_fiscal_membro` é self-service COMPLETO (ALL)
// via `empresas_do_usuario` — mesmo padrão de `parametros_uso`, CRUD direto
// sem RPC.
const opcoesSimNaoNF = ['Sem preferência', 'Sim', 'Não'];
const opcoesFormaEmissaoNF = [
  'Nota no ato do abastecimento',
  'Nota única por abastecimento',
  'Nota aglomerada com mais de um abastecimento',
];
const opcoesLocalDestinoNF = [
  'Empresa em que o veículo está cadastrado',
  'Matriz',
  'Personalizado CNPJ por Posto',
  'Personalizado CNPJ por Estado',
  'Personalizado CNPJ por Abastecimento',
];

// Fase FLT-Parametros-NF-Estado — porta de ModalDestinoEstado.tsx: exceção
// de destino de NF por UF, dentro de uma regra "Personalizado CNPJ por
// Estado" (parametros_nota_fiscal_destino_uf).
class DestinoUf {
  final String uf;
  final String cnpjDestino;
  const DestinoUf({required this.uf, required this.cnpjDestino});

  factory DestinoUf.fromMap(Map<String, dynamic> m) =>
      DestinoUf(uf: m['uf'] as String, cnpjDestino: m['cnpj_destino'] as String);
}

class ParametroNF {
  final String id;
  final String? cnpjFrota;
  final String exigeNotaFiscal;
  final String separarNfCombustivel;
  final String formaEmissao;
  final String localDestino;
  final String? cnpjDestinoPersonalizado;
  final String? dadosAdicionais;
  final String status;
  final String? observacao;
  final List<DestinoUf> destinoPorUf;

  const ParametroNF({
    required this.id,
    this.cnpjFrota,
    required this.exigeNotaFiscal,
    required this.separarNfCombustivel,
    required this.formaEmissao,
    required this.localDestino,
    this.cnpjDestinoPersonalizado,
    this.dadosAdicionais,
    required this.status,
    this.observacao,
    this.destinoPorUf = const [],
  });

  bool get ativo => status == 'Ativo';

  factory ParametroNF.fromMap(Map<String, dynamic> m) => ParametroNF(
        id: m['id'] as String,
        cnpjFrota: m['cnpj_frota'] as String?,
        exigeNotaFiscal: m['exige_nota_fiscal'] as String? ?? 'Sem preferência',
        separarNfCombustivel: m['separar_nf_combustivel'] as String? ?? 'Sem preferência',
        formaEmissao: m['forma_emissao'] as String? ?? 'Nota no ato do abastecimento',
        localDestino: m['local_destino'] as String? ?? 'Empresa em que o veículo está cadastrado',
        cnpjDestinoPersonalizado: m['cnpj_destino_personalizado'] as String?,
        dadosAdicionais: m['dados_adicionais'] as String?,
        status: m['status'] as String? ?? 'Ativo',
        observacao: m['observacao'] as String?,
        destinoPorUf: ((m['parametros_nota_fiscal_destino_uf'] as List?) ?? [])
            .map((e) => DestinoUf.fromMap(e as Map<String, dynamic>))
            .toList(),
      );
}

// Fase FLT-Parametros-NF-Estado — plano em construção no form (antes de
// salvar): CNPJ padrão + grupos de UFs cada um apontando pra um CNPJ.
class GrupoUf {
  final List<String> ufs;
  final String cnpj;
  const GrupoUf({required this.ufs, required this.cnpj});
}

class PlanoDestinoEstado {
  final String cnpjPadrao;
  final List<GrupoUf> grupos;
  const PlanoDestinoEstado({required this.cnpjPadrao, required this.grupos});
}

final parametrosNFProvider = FutureProvider.autoDispose<List<ParametroNF>>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  if (empresaId == null) return [];
  final rows = await SupabaseService.client
      .from('parametros_nota_fiscal')
      .select(
          'id, cnpj_frota, exige_nota_fiscal, separar_nf_combustivel, forma_emissao, local_destino, cnpj_destino_personalizado, dados_adicionais, status, observacao, parametros_nota_fiscal_destino_uf(uf, cnpj_destino)')
      .eq('empresa_id', empresaId)
      .order('criado_em', ascending: false) as List;
  return rows.map((m) => ParametroNF.fromMap(m as Map<String, dynamic>)).toList();
});

// Lista de CNPJs distintos da frota do cliente (mesma fonte que a web usa
// pra montar o autocomplete — veiculos_da_empresa via veiculosClienteProvider,
// consumido na tela).
