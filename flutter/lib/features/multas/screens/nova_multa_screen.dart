import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../../veiculos/providers/veiculos_provider.dart';
import '../providers/multas_provider.dart';
import '../services/multas_service.dart';

import '../../../core/theme/app_theme.dart';

// Fase Onda-2 (benchmark TicketLog, item #4) — captura manual da multa
// (primeira versão, sem integração Detran/Renainf), porta de
// multas/nova/page.tsx + NovaMultaForm.tsx.
class NovaMultaScreen extends ConsumerStatefulWidget {
  const NovaMultaScreen({super.key});

  @override
  ConsumerState<NovaMultaScreen> createState() => _NovaMultaScreenState();
}

class _NovaMultaScreenState extends ConsumerState<NovaMultaScreen> {
  String? _placa;
  final _dataInfracaoCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10));
  final _dataLimiteCtrl = TextEditingController();
  final _numeroAitCtrl = TextEditingController();
  final _orgaoCtrl = TextEditingController();
  final _localCtrl = TextEditingController();
  String? _gravidade;
  final _pontosCtrl = TextEditingController();
  final _valorOriginalCtrl = TextEditingController();
  final _valorDescontoCtrl = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  final _observacoesCtrl = TextEditingController();
  PlatformFile? _anexo;
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _dataInfracaoCtrl.dispose();
    _dataLimiteCtrl.dispose();
    _numeroAitCtrl.dispose();
    _orgaoCtrl.dispose();
    _localCtrl.dispose();
    _pontosCtrl.dispose();
    _valorOriginalCtrl.dispose();
    _valorDescontoCtrl.dispose();
    _descricaoCtrl.dispose();
    _observacoesCtrl.dispose();
    super.dispose();
  }

  Future<void> _selecionarData(TextEditingController ctrl) async {
    final atual = DateTime.tryParse(ctrl.text) ?? DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (escolhida != null) {
      ctrl.text = escolhida.toIso8601String().substring(0, 10);
    }
  }

  Future<void> _selecionarAnexo() async {
    final resultado =
        await FilePicker.pickFiles(withData: true, type: FileType.any);
    if (resultado == null || resultado.files.isEmpty) return;
    setState(() => _anexo = resultado.files.first);
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    if (_placa == null || _placa!.isEmpty) {
      setState(() => _erro = 'Placa é obrigatória.');
      return;
    }
    if (_dataInfracaoCtrl.text.trim().isEmpty) {
      setState(() => _erro = 'Data da infração é obrigatória.');
      return;
    }
    final sessao = await ref.read(sessaoProvider.future);
    final empresaId = sessao.empresaId;
    if (empresaId == null) {
      setState(() => _erro = 'Selecione uma empresa antes.');
      return;
    }

    setState(() => _salvando = true);
    try {
      await MultasService().criar(
        empresaId: empresaId,
        placa: _placa!,
        dataInfracao: _dataInfracaoCtrl.text.trim(),
        dataLimiteIndicacao: _dataLimiteCtrl.text.trim().isEmpty
            ? null
            : _dataLimiteCtrl.text.trim(),
        numeroAit: _numeroAitCtrl.text.trim().isEmpty
            ? null
            : _numeroAitCtrl.text.trim(),
        orgaoAutuador:
            _orgaoCtrl.text.trim().isEmpty ? null : _orgaoCtrl.text.trim(),
        localInfracao:
            _localCtrl.text.trim().isEmpty ? null : _localCtrl.text.trim(),
        descricao: _descricaoCtrl.text.trim().isEmpty
            ? null
            : _descricaoCtrl.text.trim(),
        gravidade: _gravidade,
        pontos: int.tryParse(_pontosCtrl.text.trim()),
        valorOriginal:
            double.tryParse(_valorOriginalCtrl.text.replaceAll(',', '.')),
        valorDesconto:
            double.tryParse(_valorDescontoCtrl.text.replaceAll(',', '.')),
        observacoes: _observacoesCtrl.text.trim().isEmpty
            ? null
            : _observacoesCtrl.text.trim(),
        criadoPor: sessao.email,
        anexo: _anexo?.bytes != null
            ? (
                bytes: _anexo!.bytes!,
                nome: _anexo!.name,
                mimeType: null as String?
              )
            : null,
      );
      if (!mounted) return;
      ref.invalidate(multasListProvider);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível registrar: $e';
        _salvando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final veiculosAsync = ref.watch(veiculosClienteProvider);

    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Nova Multa')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_erro != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_erro!,
                  style:
                      const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
            ),
          veiculosAsync.when(
            data: (lista) => DropdownButtonFormField<String>(
              value: _placa,
              decoration: const InputDecoration(
                  labelText: 'Placa *',
                  border: OutlineInputBorder(),
                  isDense: true),
              items: lista
                  .map((v) =>
                      DropdownMenuItem(value: v.placa, child: Text(v.placa)))
                  .toList(),
              onChanged: (v) => setState(() => _placa = v),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text(
                'Não foi possível carregar os veículos.',
                style: TextStyle(color: Colors.red, fontSize: 12)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dataInfracaoCtrl,
                  readOnly: true,
                  onTap: () => _selecionarData(_dataInfracaoCtrl),
                  decoration: const InputDecoration(
                    labelText: 'Data da infração *',
                    border: OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: Icon(Icons.calendar_today, size: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _dataLimiteCtrl,
                  readOnly: true,
                  onTap: () => _selecionarData(_dataLimiteCtrl),
                  decoration: const InputDecoration(
                    labelText: 'Prazo p/ indicação/desconto',
                    border: OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: Icon(Icons.calendar_today, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
              controller: _numeroAitCtrl,
              decoration: const InputDecoration(
                  labelText: 'Nº do AIT',
                  border: OutlineInputBorder(),
                  isDense: true)),
          const SizedBox(height: 10),
          TextField(
            controller: _orgaoCtrl,
            decoration: const InputDecoration(
                labelText: 'Órgão autuador',
                hintText: 'DETRAN-SP, PRF...',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
              controller: _localCtrl,
              decoration: const InputDecoration(
                  labelText: 'Local da infração',
                  border: OutlineInputBorder(),
                  isDense: true)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            value: _gravidade,
            decoration: const InputDecoration(
                labelText: 'Gravidade',
                border: OutlineInputBorder(),
                isDense: true),
            items: const [
              DropdownMenuItem(value: null, child: Text('Selecione...')),
              DropdownMenuItem(value: 'leve', child: Text('Leve')),
              DropdownMenuItem(value: 'media', child: Text('Média')),
              DropdownMenuItem(value: 'grave', child: Text('Grave')),
              DropdownMenuItem(value: 'gravissima', child: Text('Gravíssima')),
            ],
            onChanged: (v) => setState(() => _gravidade = v),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pontosCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Pontos na CNH',
                      border: OutlineInputBorder(),
                      isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _valorOriginalCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Valor original (R\$)',
                      border: OutlineInputBorder(),
                      isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _valorDescontoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Valor c/ desconto (R\$)',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descricaoCtrl,
            decoration: const InputDecoration(
                labelText: 'Descrição da infração',
                hintText: 'Ex.: Excesso de velocidade até 20%',
                border: OutlineInputBorder(),
                isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _observacoesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Observações', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          const Text('Anexo da notificação (opcional — PDF ou foto)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              if (_anexo != null)
                Chip(
                  label:
                      Text(_anexo!.name, style: const TextStyle(fontSize: 11)),
                  onDeleted: () => setState(() => _anexo = null),
                ),
              ActionChip(
                avatar: const Icon(Icons.attach_file, size: 16),
                label: const Text('Selecionar arquivo',
                    style: TextStyle(fontSize: 11)),
                onPressed: _selecionarAnexo,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _salvando ? null : _salvar,
              child: Text(_salvando ? 'Salvando...' : 'Registrar Multa'),
            ),
          ),
        ],
      ),
    );
  }
}
