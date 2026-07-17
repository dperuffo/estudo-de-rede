import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../providers/parcerias_locais_provider.dart';
import '../services/parcerias_locais_service.dart';

// Fase PWA-Parcerias-Locais — porta de ItemParceriaForm.tsx, compartilhado
// entre novo/editar (mesmo espírito de plano_viagem_form.dart).
class ItemParceriaForm extends StatefulWidget {
  final String empresaId;
  final ItemParceria? item; // null = criação
  final VoidCallback onSalvo;
  const ItemParceriaForm({super.key, required this.empresaId, this.item, required this.onSalvo});

  @override
  State<ItemParceriaForm> createState() => _ItemParceriaFormState();
}

class _ItemParceriaFormState extends State<ItemParceriaForm> {
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _descricaoCtrl;
  late final TextEditingController _parceiroCtrl;
  late final TextEditingController _pontosCtrl;
  late final TextEditingController _validadeCtrl;
  late String _categoria;
  late bool _ativo;
  PlatformFile? _imagemSelecionada;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _tituloCtrl = TextEditingController(text: item?.titulo ?? '');
    _descricaoCtrl = TextEditingController(text: item?.descricao ?? '');
    _parceiroCtrl = TextEditingController(text: item?.parceiroNome ?? '');
    _pontosCtrl = TextEditingController(text: item != null ? '${item.pontosNecessarios}' : '');
    _validadeCtrl = TextEditingController(text: item?.validadeDias != null ? '${item!.validadeDias}' : '');
    _categoria = item?.categoria ?? categoriasFidelidade.first.$1;
    _ativo = item?.ativo ?? true;
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descricaoCtrl.dispose();
    _parceiroCtrl.dispose();
    _pontosCtrl.dispose();
    _validadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _selecionarImagem() async {
    final resultado = await FilePicker.pickFiles(type: FileType.image, withData: true);
    if (resultado == null || resultado.files.isEmpty) return;
    setState(() => _imagemSelecionada = resultado.files.first);
  }

  Future<void> _salvar() async {
    setState(() {
      _erro = null;
    });
    final pontos = int.tryParse(_pontosCtrl.text.trim());
    if (_tituloCtrl.text.trim().isEmpty) {
      setState(() => _erro = 'Título é obrigatório.');
      return;
    }
    if (pontos == null || pontos <= 0) {
      setState(() => _erro = 'Pontos necessários precisa ser um número maior que zero.');
      return;
    }
    int? validade;
    if (_validadeCtrl.text.trim().isNotEmpty) {
      validade = int.tryParse(_validadeCtrl.text.trim());
      if (validade == null || validade <= 0) {
        setState(() => _erro = 'Validade em dias precisa ser maior que zero (ou deixe em branco pra sem validade).');
        return;
      }
    }

    setState(() => _salvando = true);
    try {
      String? imagemUrl;
      final selecionada = _imagemSelecionada;
      if (selecionada != null && selecionada.bytes != null) {
        imagemUrl = await ParceriasLocaisService().enviarImagem(
          empresaId: widget.empresaId,
          bytes: selecionada.bytes as Uint8List,
          nomeArquivo: selecionada.name,
        );
      }

      final servico = ParceriasLocaisService();
      if (widget.item == null) {
        await servico.criar(
          empresaId: widget.empresaId,
          categoria: _categoria,
          titulo: _tituloCtrl.text,
          descricao: _descricaoCtrl.text,
          parceiroNome: _parceiroCtrl.text,
          pontosNecessarios: pontos,
          validadeDias: validade,
          imagemUrl: imagemUrl,
        );
      } else {
        await servico.atualizar(
          id: widget.item!.id,
          categoria: _categoria,
          titulo: _tituloCtrl.text,
          descricao: _descricaoCtrl.text,
          parceiroNome: _parceiroCtrl.text,
          pontosNecessarios: pontos,
          validadeDias: validade,
          ativo: _ativo,
          imagemUrl: imagemUrl,
        );
      }
      widget.onSalvo();
    } catch (e) {
      setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _categoria,
          decoration: const InputDecoration(labelText: 'Categoria'),
          items: categoriasFidelidade
              .map((c) => DropdownMenuItem(value: c.$1, child: Text(c.$2)))
              .toList(),
          onChanged: (v) => setState(() => _categoria = v ?? _categoria),
        ),
        const SizedBox(height: 12),
        TextField(controller: _tituloCtrl, decoration: const InputDecoration(labelText: 'Título')),
        const SizedBox(height: 12),
        TextField(
          controller: _descricaoCtrl,
          decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        TextField(controller: _parceiroCtrl, decoration: const InputDecoration(labelText: 'Nome do parceiro (opcional)')),
        const SizedBox(height: 12),
        TextField(
          controller: _pontosCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Pontos necessários'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _validadeCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Validade em dias (opcional)'),
        ),
        if (widget.item != null) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ativo'),
            value: _ativo,
            onChanged: (v) => setState(() => _ativo = v),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _selecionarImagem,
          icon: const Icon(Icons.image_outlined),
          label: Text(_imagemSelecionada != null
              ? _imagemSelecionada!.name
              : (widget.item?.imagemUrl != null ? 'Trocar imagem' : 'Selecionar imagem (opcional, máx. 3 MB)')),
        ),
        if (_erro != null) ...[
          const SizedBox(height: 12),
          Text(_erro!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _salvando ? null : _salvar,
          child: Text(_salvando ? 'Salvando...' : 'Salvar'),
        ),
      ],
    );
  }
}
