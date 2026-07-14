import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';

// Fase FLT-4 — Possíveis Duplicados (Postos), porta de
// postos-duplicados/page.tsx + actions.ts. Fila de revisão (admin) dos
// possíveis duplicados sinalizados pela RPC verificar_e_registrar_posto_anp
// (aba "Meu Posto" do posto): endereço/coordenadas muito próximos de outro
// posto já cadastrado (ANP ou postos_gf de outro dono), mas CNPJ
// diferente. O cadastro nunca é bloqueado nesse momento — só entra numa
// fila pra um admin decidir depois. RLS conferida via pg_policies:
// `postos_gf_possiveis_duplicados_admin` dá ALL (SELECT/INSERT/UPDATE/
// DELETE) só pra perfil_usuario_atual() = 'admin' — sem policy de leitura
// pra mais ninguém, então esta tela é raiz e fim de linha, sem
// alternativa de escopo reduzido.
class CandidatoDuplicata {
  final String fonte; // "Base ANP" ou "Postos Revendedores"
  final String? razaoSocial;
  final String? cnpj;
  final String? municipio;
  final String? uf;
  const CandidatoDuplicata({required this.fonte, this.razaoSocial, this.cnpj, this.municipio, this.uf});
}

class PossivelDuplicata {
  final String id;
  final String? empresaNome;
  final String? cnpjInformado;
  final int? distanciaMetros;
  final String? criadoEm;
  final CandidatoDuplicata? candidato;

  const PossivelDuplicata({
    required this.id,
    this.empresaNome,
    this.cnpjInformado,
    this.distanciaMetros,
    this.criadoEm,
    this.candidato,
  });
}

final postosDuplicadosProvider = FutureProvider.autoDispose<List<PossivelDuplicata>>((ref) async {
  final supabase = SupabaseService.client;

  final pendentes = await supabase
      .from('postos_gf_possiveis_duplicados')
      .select(
          'id, empresa_id, cnpj_informado, anp_postos_id, postos_gf_cnpj_candidato, distancia_metros, criado_em, empresas(nome, cnpj)')
      .eq('status', 'pendente')
      .order('criado_em', ascending: false) as List;

  final idsAnp = <int>[];
  final cnpjsGf = <String>[];
  for (final l in pendentes) {
    final m = l as Map<String, dynamic>;
    final idAnp = m['anp_postos_id'] as int?;
    if (idAnp != null) idsAnp.add(idAnp);
    final cnpjGf = m['postos_gf_cnpj_candidato'] as String?;
    if (cnpjGf != null) cnpjsGf.add(cnpjGf);
  }

  final Map<int, Map<String, dynamic>> mapaAnp = {};
  if (idsAnp.isNotEmpty) {
    final rows = await supabase
        .from('anp_postos')
        .select('id, razao_social, cnpj, endereco, municipio, uf')
        .inFilter('id', idsAnp) as List;
    for (final r in rows) {
      final m = r as Map<String, dynamic>;
      mapaAnp[m['id'] as int] = m;
    }
  }

  final Map<String, Map<String, dynamic>> mapaGf = {};
  if (cnpjsGf.isNotEmpty) {
    final rows = await supabase
        .from('postos_gf')
        .select('cnpj, razao_social, municipio, uf, empresa_id')
        .inFilter('cnpj', cnpjsGf) as List;
    for (final r in rows) {
      final m = r as Map<String, dynamic>;
      mapaGf[m['cnpj'] as String] = m;
    }
  }

  return pendentes.map((l) {
    final m = l as Map<String, dynamic>;
    final idAnp = m['anp_postos_id'] as int?;
    final cnpjGf = m['postos_gf_cnpj_candidato'] as String?;
    final candidatoAnp = idAnp != null ? mapaAnp[idAnp] : null;
    final candidatoGf = cnpjGf != null ? mapaGf[cnpjGf] : null;

    CandidatoDuplicata? candidato;
    if (candidatoAnp != null) {
      candidato = CandidatoDuplicata(
        fonte: 'Base ANP',
        razaoSocial: candidatoAnp['razao_social'] as String?,
        cnpj: candidatoAnp['cnpj'] as String?,
        municipio: candidatoAnp['municipio'] as String?,
        uf: candidatoAnp['uf'] as String?,
      );
    } else if (candidatoGf != null) {
      candidato = CandidatoDuplicata(
        fonte: 'Postos Revendedores',
        razaoSocial: candidatoGf['razao_social'] as String?,
        cnpj: candidatoGf['cnpj'] as String?,
        municipio: candidatoGf['municipio'] as String?,
        uf: candidatoGf['uf'] as String?,
      );
    }

    final empresa = m['empresas'] as Map<String, dynamic>?;
    return PossivelDuplicata(
      id: m['id'] as String,
      empresaNome: empresa?['nome'] as String?,
      cnpjInformado: m['cnpj_informado'] as String?,
      distanciaMetros: (m['distancia_metros'] as num?)?.toInt(),
      criadoEm: m['criado_em'] as String?,
      candidato: candidato,
    );
  }).toList();
});
