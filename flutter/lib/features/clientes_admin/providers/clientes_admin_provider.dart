import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../clientes/providers/cliente_cadastro_provider.dart' show ClienteCadastro;

// Fase FLT-4 — Clientes (admin, consolidado — menu "Cadastros" da web),
// porta de clientes/page.tsx. Achado ao ler o Next.js: igual a
// /rede-postos e /grupo-economico, NÃO existe página admin separada —
// `/clientes` é a MESMA rota pro admin e pro cliente comum; o cliente
// comum só enxerga a própria empresa porque a RLS `empresas_select_membro`
// já restringe (ver comentário completo em cliente_cadastro_provider.dart,
// FLT-3 — versão cliente, read-only, só a própria empresa). Aqui é a
// versão que dá pro admin ver TODAS as empresas Frota do sistema, com
// busca e o toggle Ativar/Suspender (`empresas_update_admin` na RLS já
// libera UPDATE total pro admin).
//
// Fora do escopo desta rodada (documentado, igual às outras telas
// admin): painel "Últimos acessos" (tabela `acessos_clientes`, contador
// de badge no menu) e o checkbox "Ignorar limite de veículos do plano"
// (`bypass_limite_frota`) — ambos exclusivos do admin na web, ficam pra
// uma iteração futura; o valor central desta tela (ver todos os
// clientes, buscar, suspender/reativar) já está coberto.
//
// IMPORTANTE (mesmo achado real de documentos_empresas_admin_
// provider.dart): a tela importa `ClienteCadastro`/`statusEmpresaLabel`/
// `planoLabel` DIRETO de `cliente_cadastro_provider.dart`, não deste
// arquivo — `import ... show` não repassa símbolos adiante.
class KpisClientesAdmin {
  final int total;
  final int ativos;
  final int outros;
  const KpisClientesAdmin({required this.total, required this.ativos, required this.outros});
}

final clientesAdminListaProvider = FutureProvider.autoDispose.family<List<ClienteCadastro>, String>((ref, busca) async {
  var query = SupabaseService.client
      .from('empresas')
      .select(
          'id, nome, cnpj, status, plano, municipio, uf, segmento_transporte, porte, max_usuarios, max_veiculos, telefone_contato, email_contato')
      .eq('segmento', 'Frota');

  final termo = busca.trim();
  if (termo.isNotEmpty) {
    query = query.or('nome.ilike.%$termo%,cnpj.ilike.%$termo%');
  }

  final rows = await query.order('nome') as List;
  return rows.map((m) => ClienteCadastro.fromMap(m as Map<String, dynamic>)).toList();
});

final kpisClientesAdminProvider = FutureProvider.autoDispose<KpisClientesAdmin>((ref) async {
  final supabase = SupabaseService.client;
  final totalResp = await supabase.from('empresas').select('id').eq('segmento', 'Frota').count(CountOption.exact);
  final ativosResp = await supabase
      .from('empresas')
      .select('id')
      .eq('segmento', 'Frota')
      .inFilter('status', ['ativo', 'trial'])
      .count(CountOption.exact);
  return KpisClientesAdmin(
    total: totalResp.count,
    ativos: ativosResp.count,
    outros: totalResp.count - ativosResp.count,
  );
});
