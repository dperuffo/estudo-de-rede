import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/avisos_provider.dart';
import '../../../core/widgets/markdown_simples.dart';

final _data = DateFormat('dd/MM/yyyy HH:mm');

String _fmtData(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    return _data.format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

const _tipoIcone = <String, IconData>{
  'novidade': Icons.new_releases_outlined,
  'correcao': Icons.build_circle_outlined,
  'manutencao': Icons.construction_outlined,
  'aviso_geral': Icons.campaign_outlined,
};

const _urgenciaCor = <String, Color>{
  'informativo': Color(0xFF64748B),
  'atencao': Color(0xFFB45309),
  'critico': Color(0xFFDC2626),
};

// Fase Central-Avisos (28/07/2026) — "Central de Avisos" pro cliente/posto:
// port da combinação drawer+histórico da web numa tela cheia só (o app não
// usa drawer/bottom sheet pra este tipo de conteúdo — ver
// chamados_cliente_screen.dart). Marca todo aviso visível como lido ao
// abrir, igual ao comportamento do drawer web.
class AvisosScreen extends ConsumerStatefulWidget {
  const AvisosScreen({super.key});

  @override
  ConsumerState<AvisosScreen> createState() => _AvisosScreenState();
}

class _AvisosScreenState extends ConsumerState<AvisosScreen> {
  bool _jaMarcouLidos = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(avisosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Central de Avisos')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Não deu pra carregar: $e')),
        data: (avisos) {
          if (!_jaMarcouLidos) {
            _jaMarcouLidos = true;
            for (final a in avisos) {
              if (!a.lido) {
                // Best-effort, sem aguardar — a tela não deve travar
                // esperando N gravações de leitura.
                marcarAvisoLido(ref, a.id);
              }
            }
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(avisosProvider),
            child: avisos.isEmpty
                ? ListView(
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Nenhum aviso no momento.', style: TextStyle(color: Colors.grey)),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemCount: avisos.length,
                    itemBuilder: (context, i) {
                      final a = avisos[i];
                      final cor = _urgenciaCor[a.urgencia] ?? Colors.grey;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: cor.withOpacity(0.35)),
                        ),
                        child: ExpansionTile(
                          leading: Icon(_tipoIcone[a.tipo] ?? Icons.campaign_outlined, color: cor),
                          title: Text(a.titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          subtitle: Text('${_fmtData(a.dataPublicacao)}${a.fixado ? ' · 📌 Fixado' : ''}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.resumo, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                                  const SizedBox(height: 8),
                                  if (a.urlImagem != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(a.urlImagem!, fit: BoxFit.cover),
                                      ),
                                    ),
                                  ...renderMarkdownSimples(a.corpo),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
