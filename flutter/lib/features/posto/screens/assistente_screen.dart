import 'package:flutter/material.dart';
import '../services/assistente_service.dart';

// Fase FLT-2 — porta de ChatAssistente.tsx pro Flutter. Histórico só em
// memória (mesmo comportamento da web: fecha a tela, perde a conversa —
// não persiste no banco). Fora do escopo desta versão: exportar PDF da
// conversa (BotaoBaixarPdfAssistente*.tsx na web) — o usuário sempre pode
// copiar o texto da tela se precisar.
class _MensagemExibida {
  final String role;
  final String content;
  final List<ConsultaExecutada>? consultas;
  final bool erro;
  const _MensagemExibida({required this.role, required this.content, this.consultas, this.erro = false});
}

const _perguntasSugeridas = [
  'Quanto gastamos com combustível nos últimos 30 dias?',
  'Quais os 5 veículos com maior custo de manutenção este ano?',
  'Quantos motoristas ativos temos por centro de custo?',
  'Qual veículo está sem manutenção registrada há mais tempo?',
];

// Nome diferente de AssistenteScreen (lib/features/assistente/screens/) de
// propósito — aquela é a tela do shell genérico (cliente/admin), essa é a
// versão do shell /posto; mesmo nome nas duas causava ambiguous_import em
// app_router.dart (achado real ao rodar `flutter analyze`).
class AssistentePostoScreen extends StatefulWidget {
  const AssistentePostoScreen({super.key});

  @override
  State<AssistentePostoScreen> createState() => _AssistentePostoScreenState();
}

class _AssistentePostoScreenState extends State<AssistentePostoScreen> {
  final _mensagens = <_MensagemExibida>[];
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _enviando = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _rolarParaFim() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _enviar(String texto) async {
    final perguntaLimpa = texto.trim();
    if (perguntaLimpa.isEmpty || _enviando) return;

    final historico = _mensagens.map((m) => MensagemChat(role: m.role, content: m.content)).toList();

    setState(() {
      _mensagens.add(_MensagemExibida(role: 'user', content: perguntaLimpa));
      _controller.clear();
      _enviando = true;
    });
    _rolarParaFim();

    final resultado = await AssistenteService().perguntar(perguntaLimpa, historico);

    if (!mounted) return;
    setState(() {
      _enviando = false;
      if (resultado.erro != null) {
        _mensagens.add(_MensagemExibida(role: 'assistant', content: resultado.erro!, erro: true));
      } else {
        _mensagens.add(_MensagemExibida(
          role: 'assistant',
          content: resultado.resposta ?? 'Não consegui gerar uma resposta para essa pergunta.',
          consultas: resultado.consultas,
        ));
      }
    });
    _rolarParaFim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assistente FNI')),
      body: Column(
        children: [
          Expanded(
            child: _mensagens.isEmpty
                ? _buildVazio()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _mensagens.length + (_enviando ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _mensagens.length) return _buildBalaoCarregando();
                      return _buildBalao(_mensagens[i]);
                    },
                  ),
          ),
          _buildEntrada(),
        ],
      ),
    );
  }

  Widget _buildVazio() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pergunte sobre abastecimentos, custos, veículos, motoristas, manutenção ou '
            'centros de custo da sua operação. Exemplos:',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _perguntasSugeridas
                .map((s) => ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 12)),
                      backgroundColor: const Color(0xFFF8FAFC),
                      onPressed: () => _enviar(s),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBalao(_MensagemExibida m) {
    final ehUsuario = m.role == 'user';
    final cor = ehUsuario ? const Color(0xFF0D2D6B) : (m.erro ? const Color(0xFFFEF2F2) : const Color(0xFFF1F5F9));
    final corTexto = ehUsuario ? Colors.white : (m.erro ? const Color(0xFFB91C1C) : const Color(0xFF1E293B));

    return Align(
      alignment: ehUsuario ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.content, style: TextStyle(color: corTexto, fontSize: 14)),
            if (m.consultas != null && m.consultas!.isNotEmpty)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    '${m.consultas!.length} consulta${m.consultas!.length > 1 ? 's' : ''} ao banco',
                    style: TextStyle(fontSize: 11, color: corTexto.withOpacity(0.7)),
                  ),
                  children: m.consultas!
                      .map((c) => Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${c.erro != null ? "Erro: ${c.erro}" : "${c.linhas} linha(s)"} — ${c.sql}',
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                            ),
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalaoCarregando() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
        child: const Text('Consultando os dados da sua operação…',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
      ),
    );
  }

  Widget _buildEntrada() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_enviando,
                decoration: const InputDecoration(
                  hintText: 'Pergunte algo sobre sua frota…',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: _enviar,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _enviando ? null : () => _enviar(_controller.text),
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
