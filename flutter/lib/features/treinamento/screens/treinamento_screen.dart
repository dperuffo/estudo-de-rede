import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/treinamento_provider.dart';
import '../services/treinamento_service.dart';

// Fase FLT-Treinamento (03/09/2026) — porta de treinamento/page.tsx +
// TreinamentoExplorer.tsx. Na web é um explorer de duas colunas
// (módulos/lições); no mobile vira lista de módulos expansível, cada
// lição abre um detalhe em tela cheia com texto/imagem/vídeo.
class TreinamentoScreen extends ConsumerWidget {
  const TreinamentoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(licoesTreinamentoProvider);
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Central de Treinamento')),
      body: async.when(
        data: (licoes) {
          if (licoes.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                        'Nenhum conteúdo de treinamento disponível no momento.',
                        style: TextStyle(color: Colors.grey.shade600)),
                  ),
                ),
              ],
            );
          }
          final modulos = <String>[];
          for (final l in licoes) {
            final m = l.modulo ?? 'Geral';
            if (!modulos.contains(m)) modulos.add(m);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: modulos
                .map((modulo) => _cardModulo(
                    context,
                    modulo,
                    licoes.where((l) => (l.modulo ?? 'Geral') == modulo).toList()))
                .toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Não deu pra carregar: $e')),
      ),
    );
  }

  Widget _cardModulo(
      BuildContext context, String modulo, List<LicaoTreinamento> licoes) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.menu_book_outlined),
        title: Text(modulo, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${licoes.length} lição(ões)',
            style: const TextStyle(fontSize: 12)),
        children: licoes
            .map((l) => ListTile(
                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                  leading: const Icon(Icons.play_lesson_outlined, size: 20),
                  title: Text(l.titulo),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => _LicaoDetalheScreen(licao: l))),
                ))
            .toList(),
      ),
    );
  }
}

class _LicaoDetalheScreen extends StatelessWidget {
  final LicaoTreinamento licao;
  const _LicaoDetalheScreen({required this.licao});

  @override
  Widget build(BuildContext context) {
    final servico = TreinamentoService();
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: Text(licao.titulo)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (licao.imagemPath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(servico.urlImagem(licao.imagemPath!),
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
            const SizedBox(height: 12),
          ],
          Text(licao.texto, style: const TextStyle(fontSize: 14, height: 1.5)),
          if (licao.videoPath != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                final url = Uri.parse(servico.urlVideo(licao.videoPath!));
                await launchUrl(url, mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Assistir vídeo'),
            ),
          ],
        ],
      ),
    );
  }
}
