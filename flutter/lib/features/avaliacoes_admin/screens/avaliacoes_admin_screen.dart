import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/avaliacoes_admin_provider.dart';
import '../services/avaliacoes_admin_service.dart';

final _dataHora = DateFormat('dd/MM/yyyy HH:mm');

// Fase FLT-4 — Avaliações dos Clientes (admin): painel de feedback dos
// clientes com resposta inline, porta de avaliacoes/page.tsx. Ver escopo
// em avaliacoes_admin_provider.dart.
class AvaliacoesAdminScreen extends ConsumerStatefulWidget {
  const AvaliacoesAdminScreen({super.key});

  @override
  ConsumerState<AvaliacoesAdminScreen> createState() => _AvaliacoesAdminScreenState();
}

class _AvaliacoesAdminScreenState extends ConsumerState<AvaliacoesAdminScreen> {
  final _editando = <String>{};
  final _controllers = <String, TextEditingController>{};
  final _enviando = <String>{};
  final _erros = <String, String>{};

  TextEditingController _controllerDe(String id, String? respostaAtual) {
    return _controllers.putIfAbsent(id, () => TextEditingController(text: respostaAtual ?? ''));
  }

  Future<void> _enviar(String avaliacaoId) async {
    final sessao = await ref.read(sessaoProvider.future);
    final texto = _controllers[avaliacaoId]?.text ?? '';
    setState(() {
      _erros.remove(avaliacaoId);
      _enviando.add(avaliacaoId);
    });
    try {
      await AvaliacoesAdminService().responder(avaliacaoId: avaliacaoId, resposta: texto, respondidoPor: sessao.email);
      ref.invalidate(avaliacoesAdminProvider);
      if (mounted) setState(() => _editando.remove(avaliacaoId));
    } catch (e) {
      if (mounted) setState(() => _erros[avaliacaoId] = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _enviando.remove(avaliacaoId));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessaoProvider).valueOrNull;
    final ehAdmin = sessao?.ehAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Avaliações dos Clientes')),
      body: !ehAdmin ? _acessoRestrito() : _conteudo(),
    );
  }

  Widget _acessoRestrito() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Acesso restrito', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              SizedBox(height: 8),
              Text(
                'Esta tela é exclusiva do time interno (perfil administrador). Fale com um '
                'administrador se você precisa desses dados.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conteudo() {
    final listaAsync = ref.watch(avaliacoesAdminProvider);
    return listaAsync.when(
      data: (lista) {
        final kpis = calcularKpisAvaliacoes(lista);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Feedback enviado pelos clientes sobre a plataforma, com espaço pra responder direto.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _indicador('Nota média', '${kpis.notaMedia.toStringAsFixed(1)} ★'),
                const SizedBox(width: 8),
                _indicador('Total', '${kpis.total}'),
                const SizedBox(width: 8),
                _indicador('Pendentes', '${kpis.pendentes}', destaque: kpis.pendentes > 0),
              ],
            ),
            const SizedBox(height: 16),
            if (lista.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Nenhuma avaliação recebida ainda.', style: TextStyle(color: Colors.grey.shade500))),
              )
            else
              ...lista.map(_cardAvaliacao),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
    );
  }

  Widget _indicador(String label, String valor, {bool destaque = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: destaque ? const Color(0xFFFEF3C7) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: destaque ? const Color(0xFFFDE68A) : Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(valor, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: destaque ? const Color(0xFF92400E) : Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _cardAvaliacao(Avaliacao a) {
    final pendente = a.respostaAdmin == null || a.respostaAdmin!.isEmpty;
    final editando = _editando.contains(a.id);
    final enviando = _enviando.contains(a.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.empresaNome ?? 'Sem cliente vinculado', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(a.userEmail, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 1; i <= 5; i++)
                          Icon(Icons.star, size: 14, color: i <= a.estrelas ? const Color(0xFFFBBF24) : Colors.grey.shade300),
                      ],
                    ),
                    Text(rotuloNota(a.estrelas), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                    if (pendente)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
                        child: const Text('Pendente', style: TextStyle(fontSize: 9, color: Color(0xFF92400E), fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ],
            ),
            if (a.comentario != null && a.comentario!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(a.comentario!, style: const TextStyle(fontSize: 13)),
            ],
            if (a.criadoEm != null) ...[
              const SizedBox(height: 4),
              Text(_dataHora.format(DateTime.parse(a.criadoEm!).toLocal()), style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            ],
            const SizedBox(height: 10),
            if (!editando)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (a.respostaAdmin != null && a.respostaAdmin!.isNotEmpty) ...[
                      const Text('Sua resposta', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8))),
                      const SizedBox(height: 2),
                      Text(a.respostaAdmin!, style: const TextStyle(fontSize: 13)),
                    ] else
                      Text('Ainda sem resposta.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => setState(() {
                        _controllerDe(a.id, a.respostaAdmin);
                        _editando.add(a.id);
                      }),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: Text(pendente ? 'Responder' : 'Editar resposta', style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _controllerDe(a.id, a.respostaAdmin),
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Escreva a resposta para o cliente...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  if (_erros[a.id] != null) ...[
                    const SizedBox(height: 4),
                    Text(_erros[a.id]!, style: const TextStyle(fontSize: 11, color: Colors.red)),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: enviando ? null : () => _enviar(a.id),
                        child: Text(enviando ? 'Enviando...' : 'Enviar resposta', style: const TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => setState(() => _editando.remove(a.id)),
                        child: const Text('Cancelar', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
