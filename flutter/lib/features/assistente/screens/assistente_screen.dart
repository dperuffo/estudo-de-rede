import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/menu_button.dart';

class AssistenteScreen extends StatefulWidget {
  const AssistenteScreen({super.key});
  @override State<AssistenteScreen> createState() => _State();
}

class _State extends State<AssistenteScreen> {
  final List<Map<String, String>> _msgs = [];
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _loading = false;

  Future<void> _enviar() async {
    final texto = _ctrl.text.trim();
    if (texto.isEmpty) return;
    _ctrl.clear();
    setState(() {
      _msgs.add({'role': 'user', 'text': texto});
      _loading = true;
    });
    _scrollDown();
    try {
      final r = await ApiService().post('/assistente/chat', data: {'pergunta': texto});
      setState(() => _msgs.add({'role': 'assistant', 'text': r['resposta'] ?? '-'}));
    } catch (e) {
      setState(() => _msgs.add({'role': 'assistant', 'text': 'Erro: $e'}));
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollDown();
    }
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: const Text('Assistente IA')),
      body: Column(children: [
        Expanded(child: _msgs.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.smart_toy, size: 64, color: Color(0xFF0D2D6B)),
                const SizedBox(height: 16),
                const Text('Assistente FNI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Pergunte sobre sua frota, custos,\nabastecimentos e manutencao.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600])),
              ]))
            : ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount: _msgs.length + (_loading ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _msgs.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        CircleAvatar(backgroundColor: Color(0xFF0D2D6B),
                            child: Icon(Icons.smart_toy, color: Colors.white, size: 16)),
                        SizedBox(width: 8),
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      ]),
                    );
                  }
                  final msg = _msgs[i];
                  final isUser = msg['role'] == 'user';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isUser) ...[
                          const CircleAvatar(
                            backgroundColor: Color(0xFF0D2D6B),
                            child: Icon(Icons.smart_toy, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isUser ? const Color(0xFF0D2D6B) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(msg['text'] ?? '',
                              style: TextStyle(color: isUser ? Colors.white : Colors.black87)),
                        )),
                        if (isUser) ...[
                          const SizedBox(width: 8),
                          const CircleAvatar(
                            backgroundColor: Colors.grey,
                            child: Icon(Icons.person, color: Colors.white, size: 16),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              )),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                hintText: 'Pergunte sobre sua frota...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _enviar(),
              maxLines: null,
            )),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _loading ? null : _enviar,
              icon: const Icon(Icons.send),
              color: const Color(0xFF0D2D6B),
            ),
          ]),
        ),
      ]),
    );
  }
}
