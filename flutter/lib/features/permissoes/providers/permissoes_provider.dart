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
// `EMPRESA_ID_GLOBAL`, reservado ao admin). Ou seja: dá pra montar a
// matriz e chamar upsert direto do app, sem RPC — a segunda camada de
// checagem que a página web faz em JS (perfisVisiveis) é só UX aqui
// também, a garantia de verdade já está no banco.
//
// Fora do escopo: visão do admin (gerencia o padrão global do sistema,
// `EMPRESA_ID_GLOBAL` — não existe "cliente admin" nessa árvore de telas,
// mesmo padrão de exclusão já aplicado a todo o resto do FLT-3); coluna
// "Posto" na matriz (RLS já garante que quem é do lado Frota nunca a vê,
// nem precisa tentar buscar); seletor de cliente pra grupo econômico com
// 2+ empresas (sempre usa `sessao.empresaId`, mesmo padrão do resto do
// app).

const hierarquiaFrota = ['gestor_frota', 'analista'];

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
  const MatrizPermissoes({required this.funcionalidades, required this.perfisVisiveis, required this.matriz});

  PermissaoCelula? celula(String funcionalidade, String perfil) => matriz[funcionalidade]?[perfil];
}

final permissoesMatrizProvider = FutureProvider.autoDispose<MatrizPermissoes>((ref) async {
  final sessao = await ref.watch(sessaoProvider.future);
  final empresaId = sessao.empresaId;
  final meuPerfil = sessao.perfil ?? 'analista';
  if (empresaId == null) {
    return const MatrizPermissoes(funcionalidades: [], perfisVisiveis: [], matriz: {});
  }

  // "posto" é uma trilha separada da hierarquia Frota (gestor_frota >
  // analista) — quem está nesta tela (visão cliente) nunca vê a coluna
  // Posto, mesmo achado real documentado na Fase 27.39 da web.
  final indice = hierarquiaFrota.indexOf(meuPerfil);
  final perfisVisiveis = hierarquiaFrota.sublist(indice < 0 ? 0 : indice);

  const global = '00000000-0000-0000-0000-000000000000';
  final resultados = await Future.wait([
    SupabaseService.client
        .from('permissoes_perfil')
        .select('funcionalidade, perfil, permitido')
        .eq('empresa_id', global)
        .order('funcionalidade'),
    SupabaseService.client
        .from('permissoes_perfil')
        .select('funcionalidade, perfil, permitido')
        .eq('empresa_id', empresaId),
  ]);
  final linhasGlobais = resultados[0] as List;
  final linhasEmpresa = resultados[1] as List;

  final matriz = <String, Map<String, PermissaoCelula>>{};
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
  final funcionalidades = matriz.keys.toList()..sort();

  return MatrizPermissoes(funcionalidades: funcionalidades, perfisVisiveis: perfisVisiveis, matriz: matriz);
});
