import '../../../core/services/supabase_service.dart';

// Fase FLT-Central-Avisos (03/09/2026, pedido do Daniel: "equalizar o PWA
// Cliente com as funcionalidades construídas para a web cliente") — porta
// de central-avisos/gerenciar/page.tsx + [id]/page.tsx + actions.ts +
// AvisoEmpresaForm.tsx + ListaAvisosEmpresa.tsx.
//
// Achado da investigação: existem DUAS ferramentas de aviso na web — o
// painel admin de broadcast (/administracao/central-avisos, INSERT/UPDATE
// direto na tabela `comunicados`, restrito por RLS a perfil='admin') e
// esta aqui, "Meus Avisos" (/central-avisos/gerenciar), pensada pra
// gestor_frota/analista/colaborador do PWA Cliente. Como o admin nunca
// usa o PWA Cliente pra isso (tem o painel web dedicado), só esta segunda
// faz sentido portar aqui. Ela nunca escreve direto na tabela — passa
// inteira pelas RPCs SECURITY DEFINER abaixo, que já resolvem
// ownership/permissão/empresas do grupo econômico no servidor. Sem
// upload de imagem, sem janela de publicação/expiração, sem segmentação
// manual — tudo isso é hardcoded/calculado server-side nesta via
// simplificada (só a via admin tem esses campos).
class AvisoEmpresa {
  final String id;
  final String tipo; // novidade | correcao | manutencao | aviso_geral
  final String urgencia; // informativo | atencao | critico
  final String titulo;
  final String resumo;
  final String corpo;
  final bool ativo;
  final String criadoEm;

  const AvisoEmpresa({
    required this.id,
    required this.tipo,
    required this.urgencia,
    required this.titulo,
    required this.resumo,
    required this.corpo,
    required this.ativo,
    required this.criadoEm,
  });

  factory AvisoEmpresa.fromMap(Map<String, dynamic> m) => AvisoEmpresa(
        id: m['id'] as String,
        tipo: m['tipo'] as String? ?? 'aviso_geral',
        urgencia: m['urgencia'] as String? ?? 'informativo',
        titulo: m['titulo'] as String? ?? '',
        resumo: m['resumo'] as String? ?? '',
        corpo: m['corpo'] as String? ?? '',
        ativo: m['ativo'] as bool? ?? true,
        criadoEm: m['criado_em'] as String? ?? '',
      );
}

const tiposAviso = <String, String>{
  'novidade': 'Novidade',
  'correcao': 'Correção',
  'manutencao': 'Manutenção',
  'aviso_geral': 'Aviso geral',
};

const urgenciasAviso = <String, String>{
  'informativo': 'Informativo',
  'atencao': 'Atenção',
  'critico': 'Crítico',
};

class CentralAvisosService {
  final _supabase = SupabaseService.client;

  Future<List<AvisoEmpresa>> listarMeusAvisos() async {
    final rows =
        await _supabase.rpc('listar_avisos_da_minha_empresa') as List;
    final lista = rows
        .map((m) => AvisoEmpresa.fromMap(m as Map<String, dynamic>))
        .toList();
    lista.sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
    return lista;
  }

  Future<String?> criar({
    required String titulo,
    required String resumo,
    required String corpo,
    String tipo = 'aviso_geral',
    String urgencia = 'informativo',
  }) async {
    final erro = _validar(titulo: titulo, resumo: resumo, corpo: corpo);
    if (erro != null) return erro;
    try {
      await _supabase.rpc('criar_aviso_empresa', params: {
        'p_titulo': titulo.trim(),
        'p_resumo': resumo.trim(),
        'p_corpo': corpo.trim(),
        'p_tipo': tipo,
        'p_urgencia': urgencia,
      });
      return null;
    } catch (e) {
      return 'Não foi possível criar o aviso: $e';
    }
  }

  Future<String?> editar({
    required String id,
    required String titulo,
    required String resumo,
    required String corpo,
    required String tipo,
    required String urgencia,
  }) async {
    final erro = _validar(titulo: titulo, resumo: resumo, corpo: corpo);
    if (erro != null) return erro;
    try {
      await _supabase.rpc('editar_aviso_empresa', params: {
        'p_id': id,
        'p_titulo': titulo.trim(),
        'p_resumo': resumo.trim(),
        'p_corpo': corpo.trim(),
        'p_tipo': tipo,
        'p_urgencia': urgencia,
      });
      return null;
    } catch (e) {
      return 'Não foi possível editar o aviso: $e';
    }
  }

  Future<String?> alternarAtivo(String id, bool ativo) async {
    try {
      await _supabase.rpc('alternar_ativo_aviso_empresa',
          params: {'p_id': id, 'p_ativo': ativo});
      return null;
    } catch (e) {
      return 'Não foi possível atualizar: $e';
    }
  }

  Future<String?> excluir(String id) async {
    try {
      await _supabase.rpc('excluir_aviso_empresa', params: {'p_id': id});
      return null;
    } catch (e) {
      return 'Não foi possível excluir: $e';
    }
  }

  String? _validar(
      {required String titulo, required String resumo, required String corpo}) {
    if (titulo.trim().isEmpty) return 'Informe o título.';
    if (resumo.trim().isEmpty) return 'Informe o resumo.';
    if (corpo.trim().isEmpty) return 'Informe o corpo do aviso.';
    return null;
  }
}
