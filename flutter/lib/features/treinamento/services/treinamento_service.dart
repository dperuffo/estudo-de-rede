import '../../../core/services/supabase_service.dart';

// Fase FLT-Treinamento (03/09/2026, pedido do Daniel: "equalizar o PWA
// Cliente com as funcionalidades construídas para a web cliente") — porta
// de treinamento/page.tsx + TreinamentoExplorer.tsx. Biblioteca de
// referência estática (módulo → lições com texto/imagem/vídeo),
// filtrada por perfil — SEM progresso/conclusão (a web também não tem
// isso, confirmado na investigação: nenhuma tabela ou RPC de "visto" /
// "concluído" existe pra este conteúdo). Só leitura — a criação/edição
// de conteúdo é exclusiva do painel admin (/administracao/central-conteudo,
// upload em dois buckets), que não faz sentido replicar no PWA Cliente.
class LicaoTreinamento {
  final int id;
  final String? modulo;
  final int ordem;
  final String titulo;
  final String texto;
  final String? imagemPath;
  final String? videoPath;
  final List<String>? perfis;

  const LicaoTreinamento({
    required this.id,
    required this.modulo,
    required this.ordem,
    required this.titulo,
    required this.texto,
    required this.imagemPath,
    required this.videoPath,
    required this.perfis,
  });

  factory LicaoTreinamento.fromMap(Map<String, dynamic> m) =>
      LicaoTreinamento(
        id: (m['id'] as num).toInt(),
        modulo: m['modulo'] as String?,
        ordem: (m['ordem'] as num?)?.toInt() ?? 0,
        titulo: m['titulo'] as String? ?? '',
        texto: m['texto'] as String? ?? '',
        imagemPath: m['imagem_path'] as String?,
        videoPath: m['video_path'] as String?,
        perfis: (m['perfis'] as List?)?.map((e) => e as String).toList(),
      );
}

const bucketTreinamentoImagens = 'treinamento-imagens';
const bucketTreinamentoVideos = 'treinamento-videos';

class TreinamentoService {
  final _supabase = SupabaseService.client;

  Future<List<LicaoTreinamento>> buscarLicoes(String? perfil) async {
    final rows = await _supabase
        .from('conteudo_ajuda')
        .select()
        .eq('tipo', 'licao')
        .eq('ativo', true)
        .order('modulo')
        .order('ordem');
    final lista = rows.map((m) => LicaoTreinamento.fromMap(m)).toList();
    if (perfil == null) return lista;
    return lista
        .where((l) =>
            l.perfis == null || l.perfis!.isEmpty || l.perfis!.contains(perfil))
        .toList();
  }

  String urlImagem(String path) =>
      _supabase.storage.from(bucketTreinamentoImagens).getPublicUrl(path);

  String urlVideo(String path) =>
      _supabase.storage.from(bucketTreinamentoVideos).getPublicUrl(path);
}
