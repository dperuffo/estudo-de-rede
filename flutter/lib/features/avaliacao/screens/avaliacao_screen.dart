import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../posto/providers/avaliacoes_provider.dart';
import '../../posto/services/avaliacoes_service.dart';

// Fase FLT-3 — porta de FormularioAvaliacao.tsx pro shell Cliente. Cópia
// quase 1:1 de avaliar_screen.dart do Posto — reaproveita direto
// `avaliacoesProvider`/`AvaliacoesService` (já eram genéricos por perfil,
// filtrados só por e-mail do usuário logado + RLS). Nome de classe
// `AvaliacaoScreen` reaproveitado do arquivo antigo (que era legado/
// quebrado — ver README FLT-3), agora com o mesmo import direto do Posto.
class AvaliacaoScreen extends ConsumerStatefulWidget {
  const AvaliacaoScreen({super.key});

  @override
  ConsumerState<AvaliacaoScreen> createState() => _AvaliacaoScreenState();
}

class _AvaliacaoScreenState extends ConsumerState<AvaliacaoScreen> {
  int _estrelas = 0;
  final _comentarioCtrl = TextEditingController();
  bool _enviando = false;
  String? _erro;
  bool _sucesso = false;

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_estrelas == 0) return;
    setState(() {
      _enviando = true;
      _erro = null;
      _sucesso = false;
    });

    final sessao = await ref.read(sessaoProvider.future);
    final erro = await AvaliacoesService().enviarAvaliacao(
      estrelas: _estrelas,
      comentario: _comentarioCtrl.text,
      empresaId: sessao.empresaId,
    );

    if (!mounted) return;
    setState(() => _enviando = false);
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    setState(() {
      _sucesso = true;
      _estrelas = 0;
      _comentarioCtrl.clear();
    });
    ref.invalidate(avaliacoesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final historicoAsync = ref.watch(avaliacoesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Avaliar Plataforma')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Column(
            children: [
              Image.asset('assets/logo_fni.png', height: 56),
              const SizedBox(height: 12),
              const Text('Avalie a plataforma', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 4),
              const Text(
                'Sua opinião ajuda a FNI a melhorar a experiência de todos os clientes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sua nota', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ...List.generate(5, (i) {
                        final n = i + 1;
                        return IconButton(
                          onPressed: () => setState(() => _estrelas = n),
                          icon: Icon(
                            n <= _estrelas ? Icons.star : Icons.star_border,
                            color: n <= _estrelas ? const Color(0xFFFBBF24) : Colors.grey,
                            size: 30,
                          ),
                        );
                      }),
                      if (_estrelas > 0)
                        Text(rotuloNota(_estrelas),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Observações (opcional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _comentarioCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Conte pra gente o que está funcionando bem ou o que podemos melhorar.',
                    ),
                  ),
                  if (_erro != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                      child: Text(_erro!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
                    ),
                  ],
                  if (_sucesso) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
                      child: const Text('Avaliação enviada. Obrigado pelo retorno!',
                          style: TextStyle(color: Color(0xFF15803D), fontSize: 13)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (_enviando || _estrelas == 0) ? null : _enviar,
                      child: Text(_enviando ? 'Enviando...' : 'Enviar avaliação'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          historicoAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            error: (e, _) => Text('Erro ao carregar histórico: $e'),
            data: (historico) {
              if (historico.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Suas avaliações anteriores',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  ...historico.map((a) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      ...List.generate(
                                        5,
                                        (i) => Icon(
                                          i < a.estrelas ? Icons.star : Icons.star_border,
                                          size: 16,
                                          color: i < a.estrelas ? const Color(0xFFFBBF24) : Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(rotuloNota(a.estrelas),
                                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                  Text(_dataFormatada(a.criadoEm),
                                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                              if (a.comentario != null && a.comentario!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(a.comentario!, style: const TextStyle(fontSize: 13)),
                              ],
                              if (a.respostaAdmin != null && a.respostaAdmin!.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Resposta da equipe FNI',
                                          style: TextStyle(
                                              fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                                      const SizedBox(height: 4),
                                      Text(a.respostaAdmin!, style: const TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _dataFormatada(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
