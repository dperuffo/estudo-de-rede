import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/menu_button.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});
  @override State<TicketsScreen> createState() => _State();
}

class _State extends State<TicketsScreen> {
  List<dynamic> _tickets = [];
  bool _loading = true;

  Map<String, int> get _resumo {
    final abertos   = _tickets.where((t) => t['status'] == 'aberto').length;
    final analise   = _tickets.where((t) => t['status'] == 'em_analise').length;
    final resolvidos = _tickets.where((t) => t['status'] == 'resolvido').length;
    return {'abertos': abertos, 'analise': analise, 'resolvidos': resolvidos};
  }

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService().get('/tickets');
      setState(() => _tickets = r['data'] ?? []);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _corStatus(String? s) {
    switch (s) {
      case 'aberto': return Colors.blue;
      case 'em_analise': return Colors.orange;
      case 'resolvido': return Colors.green;
      case 'fechado': return Colors.grey;
      default: return Colors.grey;
    }
  }

  IconData _iconStatus(String? s) {
    switch (s) {
      case 'aberto': return Icons.fiber_new;
      case 'em_analise': return Icons.hourglass_empty;
      case 'resolvido': return Icons.check_circle;
      case 'fechado': return Icons.lock;
      default: return Icons.help;
    }
  }

  Widget _kpiTicket(String label, int count, Color color, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
        ]),
      ]),
    ),
  );

  Future<void> _novoTicket() async {
    final titulo = TextEditingController();
    final descricao = TextEditingController();
    String tipo = 'incidente';
    String prioridade = 'media';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Novo Ticket', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D2D6B))),
          ),
          const Divider(height: 16),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
            TextField(controller: titulo,
                decoration: const InputDecoration(labelText: 'Titulo *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: descricao, maxLines: 4,
                decoration: const InputDecoration(labelText: 'Descricao', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: tipo,
              decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'incidente', child: Text('Incidente / Erro')),
                DropdownMenuItem(value: 'melhoria', child: Text('Melhoria')),
              ],
              onChanged: (v) => setLocal(() => tipo = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: prioridade,
              decoration: const InputDecoration(labelText: 'Prioridade', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'baixa', child: Text('Baixa')),
                DropdownMenuItem(value: 'media', child: Text('Media')),
                DropdownMenuItem(value: 'alta', child: Text('Alta')),
                DropdownMenuItem(value: 'urgente', child: Text('Urgente')),
              ],
              onChanged: (v) => setLocal(() => prioridade = v!),
            ),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () async {
                if (titulo.text.trim().isEmpty) return;
                try {
                  await ApiService().post('/tickets', data: {
                    'titulo': titulo.text.trim(),
                    'descricao': descricao.text.trim(),
                    'tipo': tipo,
                    'prioridade': prioridade,
                  });
                  if (ctx.mounted) { Navigator.pop(ctx); _load(); }
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Erro: $e')));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D2D6B), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Enviar Ticket', style: TextStyle(fontSize: 16)),
            )),
          ]))),
        ]),
      )),
    );
  }

  void _abrirDetalhe(Map t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetalheTicket(ticket: t, onAtualizar: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: const Text('Suporte'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _novoTicket,
        backgroundColor: const Color(0xFF0D2D6B),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(children: [
                // KPIs
                if (_tickets.isNotEmpty) Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Row(children: [
                    _kpiTicket('Abertos', _resumo['abertos']!, Colors.blue, Icons.fiber_new),
                    const SizedBox(width: 8),
                    _kpiTicket('Em Analise', _resumo['analise']!, Colors.orange, Icons.hourglass_empty),
                    const SizedBox(width: 8),
                    _kpiTicket('Resolvidos', _resumo['resolvidos']!, Colors.green, Icons.check_circle),
                  ]),
                ),
                Expanded(child: _tickets.isEmpty
                  ? const Center(child: Text('Nenhum ticket aberto'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _tickets.length,
                      itemBuilder: (_, i) {
                        final t = _tickets[i];
                        final status = t['status'] as String?;
                        final cor = _corStatus(status);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: cor.withOpacity(0.1),
                              child: Icon(_iconStatus(status), color: cor, size: 20),
                            ),
                            title: Text(t['titulo'] ?? '-',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(t['descricao'] ?? '-',
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              const SizedBox(height: 4),
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(status ?? '-',
                                      style: TextStyle(fontSize: 10, color: cor, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 6),
                                Text(t['tipo'] ?? '-',
                                    style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                              ]),
                            ]),
                            trailing: t['resposta_admin'] != null
                                ? const Icon(Icons.mark_chat_read, color: Colors.green, size: 18)
                                : null,
                            onTap: () => _abrirDetalhe(t),
                          ),
                        );
                      })),
              ]),
            ),
    );
  }
}

class _DetalheTicket extends StatefulWidget {
  final Map ticket;
  final VoidCallback onAtualizar;
  const _DetalheTicket({required this.ticket, required this.onAtualizar});
  @override State<_DetalheTicket> createState() => _DetalheState();
}

class _DetalheState extends State<_DetalheTicket> {
  final _comentCtrl = TextEditingController();
  List<dynamic> _comentarios = [];
  bool _enviando = false;
  String? _anexoNome;
  String? _anexoBase64;

  @override void initState() {
    super.initState();
    try {
      final raw = widget.ticket['comentarios'];
      if (raw != null && raw.toString().isNotEmpty && raw.toString() != '[]') {
        _comentarios = jsonDecode(raw.toString());
      }
    } catch (_) {}
  }

  @override void dispose() { _comentCtrl.dispose(); super.dispose(); }

  Future<void> _selecionarAnexo() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;
      setState(() {
        _anexoNome = file.name;
        _anexoBase64 = base64Encode(file.bytes!);
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: \$e')));
    }
  }

  Future<void> _enviarComentario() async {
    if (_comentCtrl.text.trim().isEmpty) return;
    setState(() => _enviando = true);
    try {
      final r = await ApiService().post(
        '/tickets/comentario/${widget.ticket["id"]}',
        data: {'texto': _comentCtrl.text.trim()},
      );
      setState(() {
        _comentarios = r['comentarios'] ?? [];
        _comentCtrl.clear();
        _anexoNome = null;
        _anexoBase64 = null;
      });
      widget.onAtualizar();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  List<Map> _parseAnexos(dynamic raw) {
    if (raw == null) return [];
    try {
      if (raw is List) return raw.cast<Map>();
      final parsed = jsonDecode(raw.toString());
      if (parsed is List) return parsed.cast<Map>();
    } catch (_) {}
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    final status = t['status'] as String?;
    final corStatus = status == 'resolvido' ? Colors.green
        : status == 'em_analise' ? Colors.orange
        : status == 'fechado' ? Colors.grey
        : Colors.blue;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(t['titulo'] ?? '-',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D2D6B)))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: corStatus, borderRadius: BorderRadius.circular(12)),
                child: Text(status ?? '-',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 4),
            Text('${t["tipo"] ?? "-"} · ${t["prioridade"] ?? "-"} · #${t["numero"] ?? "-"}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ]),
        ),
        const Divider(height: 16),

        Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          // Descrição
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
            child: Text(t['descricao'] ?? '-', style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(height: 16),

          // Resposta admin
          if (t['resposta_admin'] != null && t['resposta_admin'].toString().isNotEmpty) ...[
            const Text('Resposta do Suporte',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D2D6B), fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.support_agent, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(t['resposta_admin'].toString(),
                    style: const TextStyle(fontSize: 14))),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          // Comentários
          if (_comentarios.isNotEmpty) ...[
            const Text('Historico',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D2D6B), fontSize: 13)),
            const SizedBox(height: 8),
            ..._comentarios.map((c) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['texto'] ?? '-', style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  '${c["autor"] ?? ""} · ${(c["data"] ?? "").toString().substring(0, 10)}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ]),
            )),
            const SizedBox(height: 16),
          ],

          // Anexos
          if ((t['anexos'] != null) && _parseAnexos(t['anexos']).isNotEmpty) ...[
            const Text('Anexos',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D2D6B), fontSize: 13)),
            const SizedBox(height: 8),
            ..._parseAnexos(t['anexos']).map((a) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.attach_file, color: Colors.blue, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(a['nome']?.toString() ?? '-',
                    style: const TextStyle(fontSize: 13))),
                if (a['conteudo'] != null) TextButton(
                  onPressed: () async {
                    final url = 'data:${a["tipo_mime"] ?? "application/octet-stream"};base64,${a["conteudo"]}';
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  },
                  child: const Text('Ver', style: TextStyle(fontSize: 12)),
                ),
              ]),
            )),
            const SizedBox(height: 16),
          ],

          // Adicionar comentário
          if (status != 'fechado') ...[
            const Text('Adicionar observacao',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D2D6B), fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _comentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Descreva sua observacao...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            // Anexo
            Row(children: [
              OutlinedButton.icon(
                onPressed: _selecionarAnexo,
                icon: const Icon(Icons.attach_file, size: 18),
                label: const Text('Anexar arquivo'),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF0D2D6B)),
              ),
              const SizedBox(width: 8),
              if (_anexoNome != null) Expanded(child: Row(children: [
                const Icon(Icons.insert_drive_file, color: Colors.green, size: 16),
                const SizedBox(width: 4),
                Expanded(child: Text(_anexoNome!, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                IconButton(icon: const Icon(Icons.close, size: 16), padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() { _anexoNome = null; _anexoBase64 = null; })),
              ])),
            ]),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: _enviando ? null : _enviarComentario,
              icon: _enviando
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, size: 18),
              label: Text(_enviando ? 'Enviando...' : 'Enviar observacao'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D2D6B), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            )),
            const SizedBox(height: 32),
          ],
        ])),
      ]),
    );
  }
}
