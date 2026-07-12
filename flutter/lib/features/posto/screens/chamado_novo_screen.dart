import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/chamados_provider.dart';
import '../services/chamados_service.dart';

// Fase FLT-2 — abrir novo chamado, porta de ChamadoForm.tsx (com escopo
// reduzido — ver README): sem o seletor de "Cliente" (a visão posto já é
// uma única empresa, resolvida pela sessão).
class ChamadoNovoScreen extends ConsumerStatefulWidget {
  const ChamadoNovoScreen({super.key});

  @override
  ConsumerState<ChamadoNovoScreen> createState() => _ChamadoNovoScreenState();
}

class _ChamadoNovoScreenState extends ConsumerState<ChamadoNovoScreen> {
  final _tituloCtrl = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  String _tipo = 'incidente';
  String _prioridade = 'media';
  PlatformFile? _anexo;
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descricaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _selecionarAnexo() async {
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
      _anexo = arquivo;
      _erro = null;
    });
  }

  Future<void> _enviar() async {
    final titulo = _tituloCtrl.text.trim();
    final descricao = _descricaoCtrl.text.trim();
    if (titulo.isEmpty) {
      setState(() => _erro = 'Título é obrigatório.');
      return;
    }
    if (descricao.isEmpty) {
      setState(() => _erro = 'Descrição é obrigatória.');
      return;
    }
    final sessao = await ref.read(sessaoProvider.future);
    final empresaId = sessao.empresaId;
    if (empresaId == null) {
      setState(() => _erro = 'Não foi possível identificar sua empresa.');
      return;
    }

    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final id = await ChamadosService().criarChamado(
        empresaId: empresaId,
        tipo: _tipo,
        titulo: titulo,
        descricao: descricao,
        prioridade: _prioridade,
        anexoBytes: _anexo?.bytes,
        anexoNome: _anexo?.name,
        anexoMime: null,
      );
      ref.invalidate(chamadosPostoProvider);
      if (mounted) {
        context.pushReplacement('/posto/chamados/$id');
      }
    } catch (e) {
      setState(() => _erro = 'Não foi possível abrir o chamado: $e');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo chamado')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_erro != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
              child: Text(_erro!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
            ),
          const Text('Tipo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: tiposTicket.entries
                .map((e) => ChoiceChip(
                      label: Text(e.value),
                      selected: _tipo == e.key,
                      onSelected: (_) => setState(() => _tipo = e.key),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tituloCtrl,
            maxLength: 150,
            decoration: const InputDecoration(
              labelText: 'Título *',
              hintText: 'Resuma o problema/sugestão em poucas palavras',
              border: OutlineInputBorder(),
            ),
          ),
          TextField(
            controller: _descricaoCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Descrição *',
              hintText: 'Descreva com o máximo de detalhes possível',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _prioridade,
            decoration: const InputDecoration(labelText: 'Prioridade', border: OutlineInputBorder()),
            items: prioridadesTicket.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _prioridade = v ?? 'media'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _selecionarAnexo,
                icon: const Icon(Icons.attach_file, size: 18),
                label: const Text('Anexar arquivo (opcional)'),
              ),
              const SizedBox(width: 8),
              if (_anexo != null)
                Expanded(
                  child: Text(_anexo!.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _enviando ? null : _enviar,
              child: Text(_enviando ? 'Enviando...' : 'Abrir chamado'),
            ),
          ),
        ],
      ),
    );
  }
}
