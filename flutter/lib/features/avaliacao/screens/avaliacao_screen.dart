import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/menu_button.dart';

class AvaliacaoScreen extends StatefulWidget {
  const AvaliacaoScreen({super.key});
  @override State<AvaliacaoScreen> createState() => _State();
}

class _State extends State<AvaliacaoScreen> {
  bool _loading = true;
  bool _jaAvaliou = false;
  int _estrelas = 0;
  double _media = 0;
  int _total = 0;
  final _comentarioCtrl = TextEditingController();
  bool _enviando = false;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _comentarioCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService().get('/avaliacoes/minha');
      setState(() {
        _jaAvaliou = r['ja_avaliou'] ?? false;
        _media = (r['media'] as num? ?? 0).toDouble();
        _total = r['total'] as int? ?? 0;
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enviar() async {
    if (_estrelas == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione pelo menos 1 estrela')));
      return;
    }
    setState(() => _enviando = true);
    try {
      await ApiService().post('/avaliacoes', data: {
        'estrelas': _estrelas,
        'comentario': _comentarioCtrl.text.trim(),
      });
      setState(() => _jaAvaliou = true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Obrigado pela avaliacao!')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: const Text('Avaliar o App'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(children: [

                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D2D6B), Color(0xFF1565C0)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    const Icon(Icons.star, color: Colors.amber, size: 48),
                    const SizedBox(height: 12),
                    const Text('FNI Gestao de Frotas',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Sua opiniao nos ajuda a melhorar',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    if (_total > 0) ...[
                      const SizedBox(height: 16),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        ...List.generate(5, (i) => Icon(
                          i < _media.round() ? Icons.star : Icons.star_border,
                          color: Colors.amber, size: 20,
                        )),
                        const SizedBox(width: 8),
                        Text('$_media/5 ($_total avaliacoes)',
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ]),
                    ],
                  ]),
                ),
                const SizedBox(height: 32),

                if (_jaAvaliou) ...[
                  // Já avaliou hoje
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Column(children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 48),
                      const SizedBox(height: 12),
                      const Text('Obrigado pelo feedback!',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 8),
                      const Text('Voce ja avaliou hoje. Volte amanha para avaliar novamente.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey)),
                    ]),
                  ),
                ] else ...[
                  // Formulário de avaliação
                  const Text('Como voce avalia o app?',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),

                  // Estrelas
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) {
                    final n = i + 1;
                    return GestureDetector(
                      onTap: () => setState(() => _estrelas = n),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          n <= _estrelas ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 48,
                        ),
                      ),
                    );
                  })),
                  const SizedBox(height: 8),
                  Text(
                    _estrelas == 0 ? 'Toque nas estrelas para avaliar'
                        : _estrelas == 1 ? 'Muito ruim'
                        : _estrelas == 2 ? 'Ruim'
                        : _estrelas == 3 ? 'Regular'
                        : _estrelas == 4 ? 'Bom'
                        : 'Excelente!',
                    style: TextStyle(
                      fontSize: 16,
                      color: _estrelas == 0 ? Colors.grey
                          : _estrelas <= 2 ? Colors.red
                          : _estrelas == 3 ? Colors.orange
                          : Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Comentário
                  TextField(
                    controller: _comentarioCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Comentario (opcional)',
                      hintText: 'Conte o que voce achou, sugestoes de melhoria...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botão enviar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _enviando ? null : _enviar,
                      icon: _enviando
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send),
                      label: Text(_enviando ? 'Enviando...' : 'Enviar avaliacao'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D2D6B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
    );
  }
}
