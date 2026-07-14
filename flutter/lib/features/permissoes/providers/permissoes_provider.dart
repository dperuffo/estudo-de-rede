import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-3 — Permissões por Perfil (cliente), porta de
// permissoes/page.tsx + _components/TogglePermissao.tsx + actions.ts. RLS
// conferida antes de portar (`permissoes_perfil`): SELECT/INSERT/UPDATE/
// DELETE já bloqueiam, no banco, tudo que a visão cliente não deveria
// alcançar — perfil "posto" nunca visível/editável por quem não é posto,
// nível do perfil editado sempre <= nível do próprio usuário, e
// empresa_id sempre a própria empresa do usuário (nunca o padrão global
// `empresaIdGlobal`, reservado ao admin). Ou seja: dá pra montar a
// matriz e chamar upsert direto do app, sem RPC — a segunda camada de
// checagem que a página web faz em JS (perfisVisiveis) é só UX aqui
// também, a garantia de verdade já está no banco.
//
// Fase FLT-4 — modo admin adicionado: em vez de customizar UMA empresa
// (como um gestor_frota faz), o admin sempre lê/grava o padrão GLOBAL do
// sistema (`empresa_id = empresaIdGlobal`), igual à web (`souAdmin ?
// EMPRESA_ID_GLOBAL : empresaSelecionada`) — por isso ignora
// `sessao.empresaId` (o cliente escolhido via `/selecionar-empresa` não
// importa aqui) e mostra os 4 perfis (`perfis`, não só
// `hierarquiaFrota`), já que é o único lugar que também define a
// permissão do próprio perfil "admin" e do perfil "posto".
//
// Fora do escopo: coluna "Posto" na matriz pra quem NÃO é admin (RLS já
// garante que quem é do lado Frota nunca a vê, nem precisa tentar
// buscar); seletor de cliente pra grupo econômico com 2+ empresas
// (sempre usa `sessao.empresaId`, mesmo padrão do resto do app).

const hierarquiaFrota = ['gestor_frota', 'analista'];
const perfis = ['admin', 'gestor_frota', 'analista', 'posto'];
const empresaIdGlobal = '00000000-0000-0000-0000-000000000000';

const perfilLabel = {
  'admin': 'Administrador',
  'gestor_frota': 'Gestor de Frota',
  'analista': 'Analista',
  'posto': 'Posto',
};

// "aba_dashboard" -> "Aba: Dashboard", "func_exportar" -> "Função: Exportar".
// Só formatação pra tela, não muda nada no banco — mesma função da web.
String formatarFuncionalidade(String nome) {
  if (nome.startsWith('aba_')) return 'Aba: ${_humanizar(nome.substring(4))}';
  if (nome.startsWith('func_')) return 'Função: ${_humanizar(nome.substring(5))}';
  return _humanizar(nome);
}

String _humanizar(String texto) {
  return texto.split('_').map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}').join(' ');
}

class PermissaoCelula {
  final bool permitido;
  final bool customizado;
  const PermissaoCelula({required this.permitido, required this.customizado});
}

class MatrizPermissoes {
  final List<String> funcionalidades;
  final List<String> perfisVisiveis;
  final Map<String, Map<String, PermissaoCelula>> matriz;
  // empresa_id usado pro upsert do toggle — a própria empresa escolhida
  // (cliente) ou `empresaIdGlobal` (admin, editando o padrão do sistema).
  final String empresaEdicao;
  final bool modoGlobal;
  const MatrizPermissoes({
    required this.funcionalidades,
    required this.perfisVisiveis,
    required this.matriz,
    required this.empresaEdicao,
    required this.modoGlobal,
  });

  PermissaoCelula? celula(String funcionalidade, String perfil) => matriz[funcionalidade]?[perfil];
}

final permissoesMatrizProvider = FutureProvider.autoDispose<MatrizPermissoes>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final ehAdmin = sessao.ehAdmin;
  final meuPerfil = sessao.perfil ?? 'analista';

  if (!ehAdmin && sessao.empresaId == null) {
    return const MatrizPermissoes(funcionalidades: [], perfisVisiveis: [], matriz: {}, empresaEdicao: '', modoGlobal: false);
  }

  // "posto" é uma trilha separada da hierarquia Frota (gestor_frota >
  // analista) — quem não é admin nunca vê a coluna Posto (achado real
  // documentado na Fase 27.39 da web); admin vê e edita as 4.
  List<String> perfisVisiveis;
  if (ehAdmin) {
    perfisVisiveis = perfis;
  } else {
    final indice = hierarquiaFrota.indexOf(meuPerfil);
    perfisVisiveis = hierarquiaFrota.sublist(indice < 0 ? 0 : indice);
  }

  final empresaEdicao = ehAdmin ? empresaIdGlobal : sessao.empresaId!;

  final linhasGlobaisFuturo = SupabaseService.client
      .from('permissoes_perfil')
      .select('funcionalidade, perfil, permitido')
      .eq('empresa_id', empresaIdGlobal)
      .order('funcionalidade');

  final matriz = <String, Map<String, PermissaoCelula>>{};

  if (ehAdmin) {
    // Admin só lê/edita o padrão global — não existe "customização" pra
    // sobrepor aqui (isso é coisa da visão cliente).
    final linhasGlobais = await linhasGlobaisFuturo;
    for (final l in linhasGlobais) {
      final m = l as Map<String, dynamic>;
      final porPerfil = matriz.putIfAbsent(m['funcionalidade'] as String, () => {});
      porPerfil[m['perfil'] as String] = PermissaoCelula(permitido: m['permitido'] as bool? ?? false, customizado: false);
    }
  } else {
    final resultados = await Future.wait([
      linhasGlobaisFuturo,
      SupabaseService.client
          .from('permissoes_perfil')
          .select('funcionalidade, perfil, permitido')
          .eq('empresa_id', empresaEdicao),
    ]);
    final linhasGlobais = resultados[0] as List;
    final linhasEmpresa = resultados[1] as List;
    for (final l in linhasGlobais) {
      final m = l as Map<String, dynamic>;
      final porPerfil = matriz.putIfAbsent(m['funcionalidade'] as String, () => {});
      porPerfil[m['perfil'] as String] = PermissaoCelula(permitido: m['permitido'] as bool? ?? false, customizado: false);
    }
    for (final l in linhasEmpresa) {
      final m = l as Map<String, dynamic>;
      final porPerfil = matriz.putIfAbsent(m['funcionalidade'] as String, () => {});
      porPerfil[m['perfil'] as String] = PermissaoCelula(permitido: m['permitido'] as bool? ?? false, customizado: true);
    }
  }

  final funcionalidades = matriz.keys.toList()..sort();

  return MatrizPermissoes(
    funcionalidades: funcionalidades,
    perfisVisiveis: perfisVisiveis,
    matriz: matriz,
    empresaEdicao: empresaEdicao,
    modoGlobal: ehAdmin,
  );
});
