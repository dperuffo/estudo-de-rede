import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/auth_service.dart';
import '../providers/chamados_provider.dart';
import '../services/chamados_service.dart';

final _data = DateFormat('dd/MM/yyyy HH:mm');

String _fmtData(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    return _data.format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

const _corStatus = <String, Color>{
  'aberto': Color(0xFFB45309),
  'em_analise': Color(0xFF1D4ED8),
  'resolvido': Color(0xFF15803D),
  'fechado': Color(0xFF64748B),
};

// Fase FLT-2 — detalhe do chamado + thread de mensagens/anexos, porta de
// chamados/[id]/page.tsx + ThreadChamado.tsx (com escopo reduzido — ver
// README): posto nunca vê ControlesAdminChamado (status/prioridade
// manuais são decisão da equipe FNI), só o botão "Marcar como resolvido"
// (mesmo caminho de um cliente comum na web).
class ChamadoDetalheScreen extends ConsumerStatefulWidget {
  final String id;
  const ChamadoDetalheScreen({super.key, required this.id});

  @override
  ConsumerState<ChamadoDetalheScreen> createState() => _ChamadoDetalheScreenState();
}

class _ChamadoDetalheScreenState extends ConsumerState<ChamadoDetalheScreen> {
  final _mensagemCtrl = TextEditingController();
  bool _enviandoMensagem = false;
  bool _enviandoAnexo = false;
  bool _resolvendo = false;
  String? _erro;
  bool _jaMarcouVisto = false;

  @override
  void dispose() {
    _mensagemCtrl.dispose();
    super.dispose();
  }

  Future<void> _marcarVistoSeNecessario() async {
    if (_jaMarcouVisto) return;
    _jaMarcouVisto = true;
    try {
      await ChamadosService().marcarVisto(widget.id);
      ref.invalidate(chamadosPostoProvider);
    } catch (_) {
      // Notificação visual, best-effort — não pode travar a tela.
    }
  }

  Future<void> _enviarMensagem() async {
    final texto = _mensagemCtrl.text.trim();
    if (texto.isEmpty) return;
    setState(() {
      _enviandoMensagem = true;
      _erro = null;
    });
    try {
      await ChamadosService().comentar(widget.id, texto);
      _mensagemCtrl.clear();
      ref.invalidate(chamadoDetalheProvider(widget.id));
      ref.invalidate(chamadosPostoProvider);
    } catch (e) {
      setState(() => _erro = 'Não foi possível enviar a mensagem: $e');
    } finally {
      if (mounted) setState(() => _enviandoMensagem = false);
    }
  }

  Future<void> _enviarAnexo() async {
    final resultado = await FilePicker.platform.pickFiles(withData: true);
    if (resultado == null || resultado.files.isEmpty) return;
    final arquivo = resultado.files.first;
    if (arquivo.bytes == null) return;
    if (arquivo.size > ticketTamanhoMaxAnexoBytes) {
      setState(() => _erro =
          'O anexo (${formatarTamanhoAnexo(arquivo.size)}) passa do limite de ${formatarTamanhoAnexo(ticketTamanhoMaxAnexoBytes)}.');
      return;
    }
    setState(() {
      _enviandoAnexo = true;
      _erro = null;
    });
    try {
      await ChamadosService().enviarAnexoNoChamado(
        ticketId: widget.id,
        bytes: arquivo.bytes!,
        nome: arquivo.name,
      );
      ref.invalidate(chamadoDetalheProvider(widget.id));
      ref.invalidate(chamadosPostoProvider);
    } catch (e) {
      setState(() => _erro = 'Não foi possível enviar o anexo: $e');
    } finally {
      if (mounted) setState(() => _enviandoAnexo = false);
    }
  }

  Future<void> _marcarResolvido() async {
    setState(() => _resolvendo = true);
    try {
      await ChamadosService().marcarResolvido(widget.id);
      ref.invalidate(chamadoDetalheProvider(widget.id));
      ref.invalidate(chamadosPostoProvider);
    } catch (e) {
      setState(() => _erro = 'Não foi possível marcar como resolvido: $e');
    } finally {
      if (mounted) setState(() => _resolvendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(chamadoDetalheProvider(widget.id));
    final meuEmail = AuthService().emailAtual;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chamado'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Não deu pra carregar: $e')),
        data: (d) {
          if (d == null) return const Center(child: Text('Chamado não encontrado.'));
          WidgetsBinding.instance.addPostFrameCallback((_) => _marcarVistoSeNecessario());
          final t = d.ticket;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_erro != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                  child: Text(_erro!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text('#${t.numero} — ${t.titulo}',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${tiposTicket[t.tipo] ?? t.tipo} · aberto em ${_fmtData(t.criadoEm)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _badge(statusTicket[t.status] ?? t.status, _corStatus[t.status] ?? Colors.grey),
                  _badge(prioridadesTicket[t.prioridade] ?? t.prioridade, Colors.grey.shade700),
                ],
              ),
              const SizedBox(height: 16),
              if (t.status != 'resolvido' && t.status != 'fechado')
                OutlinedButton.icon(
                  onPressed: _resolvendo ? null : _marcarResolvido,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(_resolvendo ? 'Salvando...' : 'Marcar como resolvido'),
                ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Descrição', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      const SizedBox(height: 4),
                      Text(t.descricao, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
              if (t.respostaAdmin != null && t.respostaAdmin!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Resposta oficial (histórico)',
                          style: TextStyle(fontSize: 11, color: Color(0xFF6366F1), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(t.respostaAdmin!, style: const TextStyle(fontSize: 13, color: Color(0xFF3730A3))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Text('Mensagens', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (d.comentarios.isEmpty)
                Text('Nenhuma mensagem ainda.', style: TextStyle(fontSize: 13, color: Colors.grey.shade500))
              else
                ...d.comentarios.map((c) {
                  final proprio = c.autorEmail == meuEmail;
                  return Align(
                    alignment: proprio ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: proprio ? const Color(0xFF0D2D6B) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.autorTipo == 'admin' ? 'Equipe FNI' : c.autorEmail,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: proprio ? Colors.white70 : Colors.grey.shade600)),
                          const SizedBox(height: 2),
                          Text(c.texto,
                              style: TextStyle(fontSize: 13, color: proprio ? Colors.white : Colors.black87)),
                          const SizedBox(height: 4),
                          Text(_fmtData(c.criadoEm),
                              style: TextStyle(fontSize: 10, color: proprio ? Colors.white60 : Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _mensagemCtrl,
                      decoration: const InputDecoration(hintText: 'Escreva uma mensagem…', border: OutlineInputBorder()),
                      enabled: !_enviandoMensagem,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _enviandoMensagem ? null : _enviarMensagem,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Anexos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (d.anexos.isEmpty)
                Text('Nenhum anexo.', style: TextStyle(fontSize: 13, color: Colors.grey.shade500))
              else
                ...d.anexos.map((a) => Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.attach_file),
                        title: Text(a.nome, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                            '${formatarTamanhoAnexo(a.tamanho)}${a.autorEmail != null ? ' · enviado por ${a.autorEmail}' : ''}',
                            style: const TextStyle(fontSize: 11)),
                        trailing: a.urlAssinada != null
                            ? IconButton(
                                icon: const Icon(Icons.open_in_new, size: 18),
                                onPressed: () => launchUrl(Uri.parse(a.urlAssinada!)),
                              )
                            : null,
                      ),
                    )),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _enviandoAnexo ? null : _enviarAnexo,
                icon: const Icon(Icons.attach_file, size: 18),
                label: Text(_enviandoAnexo ? 'Enviando...' : 'Enviar anexo'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _badge(String texto, Color cor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Text(texto, style: TextStyle(fontSize: 12, color: cor, fontWeight: FontWeight.w600)),
      );
}
