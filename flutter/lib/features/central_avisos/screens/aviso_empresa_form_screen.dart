import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/central_avisos_provider.dart';
import '../services/central_avisos_service.dart';

// Fase FLT-Central-Avisos (03/09/2026) — porta de
// central-avisos/gerenciar/novo + [id]/page.tsx + AvisoEmpresaForm.tsx.
// Sem upload de imagem, sem janela de publicação/segmentação — a via
// "gestor" é deliberadamente mais simples que o painel admin (RPCs já
// calculam empresas_alvo = própria empresa + grupo econômico).
class AvisoEmpresaFormScreen extends ConsumerStatefulWidget {
  final String? id;
  const AvisoEmpresaFormScreen({super.key, this.id});

  @override
  ConsumerState<AvisoEmpresaFormScreen> createState() =>
      _AvisoEmpresaFormScreenState();
}

class _AvisoEmpresaFormScreenState
    extends ConsumerState<AvisoEmpresaFormScreen> {
  final _tituloCtrl = TextEditingController();
  final _resumoCtrl = TextEditingController();
  final _corpoCtrl = TextEditingController();
  String _tipo = 'aviso_geral';
  String _urgencia = 'informativo';
  bool _preenchido = false;
  bool _salvando = false;
  String? _erro;

  bool get _editando => widget.id != null;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _resumoCtrl.dispose();
    _corpoCtrl.dispose();
    super.dispose();
  }

  void _preencher(AvisoEmpresa a) {
    _tituloCtrl.text = a.titulo;
    _resumoCtrl.text = a.resumo;
    _corpoCtrl.text = a.corpo;
    _tipo = a.tipo;
    _urgencia = a.urgencia;
  }

  Future<void> _salvar() async {
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final servico = CentralAvisosService();
    final erro = _editando
        ? await servico.editar(
            id: widget.id!,
            titulo: _tituloCtrl.text,
            resumo: _resumoCtrl.text,
            corpo: _corpoCtrl.text,
            tipo: _tipo,
            urgencia: _urgencia,
          )
        : await servico.criar(
            titulo: _tituloCtrl.text,
            resumo: _resumoCtrl.text,
            corpo: _corpoCtrl.text,
            tipo: _tipo,
            urgencia: _urgencia,
          );
    if (!mounted) return;
    if (erro != null) {
      setState(() {
        _salvando = false;
        _erro = erro;
      });
      return;
    }
    ref.invalidate(meusAvisosProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_editando) {
      final async = ref.watch(meusAvisosProvider);
      return async.when(
        data: (lista) {
          if (!_preenchido) {
            final encontrados = lista.where((a) => a.id == widget.id);
            if (encontrados.isNotEmpty) {
              _preencher(encontrados.first);
            }
            _preenchido = true;
          }
          return _buildForm(context);
        },
        loading: () => Scaffold(
            appBar: AppBar(title: const Text('Editar aviso')),
            body: const Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(
            appBar: AppBar(title: const Text('Editar aviso')),
            body: Center(child: Text('Não deu pra carregar: $e'))),
      );
    }
    return _buildForm(context);
  }

  Widget _buildForm(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: Text(_editando ? 'Editar aviso' : 'Novo aviso')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_erro != null) ...[
            Text(_erro!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
          ],
          DropdownButtonFormField<String>(
            value: _tipo,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: tiposAviso.entries
                .map((e) =>
                    DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _tipo = v ?? 'aviso_geral'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _urgencia,
            decoration: const InputDecoration(labelText: 'Urgência'),
            items: urgenciasAviso.entries
                .map((e) =>
                    DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _urgencia = v ?? 'informativo'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tituloCtrl,
            decoration: const InputDecoration(labelText: 'Título *'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _resumoCtrl,
            decoration: const InputDecoration(
                labelText: 'Resumo *',
                hintText: 'Aparece na lista e na notificação'),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _corpoCtrl,
            decoration: const InputDecoration(labelText: 'Corpo *'),
            maxLines: 8,
          ),
          const SizedBox(height: 8),
          Text(
              'Visível para sua empresa e, se houver, para as demais empresas do mesmo grupo econômico.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _salvando ? null : _salvar,
            child: _salvando
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_editando ? 'Salvar alterações' : 'Publicar aviso'),
          ),
        ],
      ),
    );
  }
}
