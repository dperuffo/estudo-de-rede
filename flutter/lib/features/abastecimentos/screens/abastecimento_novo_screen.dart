import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../posto/services/abastecimentos_posto_service.dart' show produtosPosto;
import '../services/abastecimentos_cliente_service.dart';

// Fase FLT-3 — porta de abastecimentos/novo/page.tsx + AbastecimentoForm.tsx
// (só a parte de criação — sem edição direta, que na web só existe pra
// registros SEM contraparte identificada; aqui a edição direta de um
// abastecimento já lançado fica fora do escopo, use o fluxo de Ajuste na
// tela de detalhe). Sem o campo "Cliente" (a web mostra um seletor pra
// quem enxerga vários; aqui é sempre a empresa da sessão).
class AbastecimentoNovoScreen extends ConsumerStatefulWidget {
  const AbastecimentoNovoScreen({super.key});

  @override
  ConsumerState<AbastecimentoNovoScreen> createState() => _AbastecimentoNovoScreenState();
}

class _AbastecimentoNovoScreenState extends ConsumerState<AbastecimentoNovoScreen> {
  final _placaCtrl = TextEditingController();
  final _motoristaCtrl = TextEditingController();
  final _hodometroCtrl = TextEditingController();
  final _litrosCtrl = TextEditingController();
  final _precoCtrl = TextEditingController();
  final _valorTotalCtrl = TextEditingController();
  final _postoNomeCtrl = TextEditingController();
  final _postoMunicipioCtrl = TextEditingController();
  final _postoUfCtrl = TextEditingController();

  String? _combustivel;
  DateTime? _dataHora;
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _placaCtrl.dispose();
    _motoristaCtrl.dispose();
    _hodometroCtrl.dispose();
    _litrosCtrl.dispose();
    _precoCtrl.dispose();
    _valorTotalCtrl.dispose();
    _postoNomeCtrl.dispose();
    _postoMunicipioCtrl.dispose();
    _postoUfCtrl.dispose();
    super.dispose();
  }

  void _recalcularTotal() {
    final l = double.tryParse(_litrosCtrl.text.trim().replaceAll(',', '.'));
    final p = double.tryParse(_precoCtrl.text.trim().replaceAll(',', '.'));
    if (l != null && p != null) {
      setState(() => _valorTotalCtrl.text = (l * p).toStringAsFixed(2));
    }
  }

  Future<void> _selecionarDataHora() async {
    final atual = _dataHora ?? DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (data == null || !mounted) return;
    final hora = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(atual));
    if (hora == null) return;
    setState(() => _dataHora = DateTime(data.year, data.month, data.day, hora.hour, hora.minute));
  }

  double? _numOuNull(String texto) {
    final t = texto.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _salvar() async {
    final sessao = await ref.read(sessaoProvider.future);
    final empresaId = sessao.empresaId;
    if (empresaId == null) {
      setState(() => _erro = 'Não foi possível identificar sua empresa na sessão atual.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });

    final empresa = await SupabaseService.client.from('empresas').select('cnpj, nome').eq('id', empresaId).maybeSingle();
    final cnpj = empresa?['cnpj'] as String?;
    if (cnpj == null || cnpj.isEmpty) {
      setState(() {
        _salvando = false;
        _erro = 'Não foi possível identificar o CNPJ da sua empresa.';
      });
      return;
    }

    final erro = await AbastecimentosClienteService().criarManual(
      empresaId: empresaId,
      empresaNome: (empresa?['nome'] as String?) ?? sessao.nomeEmpresa ?? '',
      empresaCnpj: cnpj,
      dataAbastecimento: _dataHora?.toUtc().toIso8601String(),
      hodometro: _numOuNull(_hodometroCtrl.text),
      placa: _placaCtrl.text.trim().isEmpty ? null : _placaCtrl.text.trim().toUpperCase(),
      motoristaNome: _motoristaCtrl.text.trim().isEmpty ? null : _motoristaCtrl.text.trim(),
      produto: _combustivel,
      litros: _numOuNull(_litrosCtrl.text),
      precoUnitario: _numOuNull(_precoCtrl.text),
      valorTotal: _numOuNull(_valorTotalCtrl.text),
      postoNome: _postoNomeCtrl.text.trim().isEmpty ? null : _postoNomeCtrl.text.trim(),
      postoMunicipio: _postoMunicipioCtrl.text.trim().isEmpty ? null : _postoMunicipioCtrl.text.trim(),
      postoUf: _postoUfCtrl.text.trim().isEmpty ? null : _postoUfCtrl.text.trim().toUpperCase(),
    );

    if (!mounted) return;
    setState(() => _salvando = false);
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lançar Abastecimento Manual')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
            child: const Text(
              'Use este formulário só para lançamentos manuais (sem integração automática com meio de pagamento) '
              'ou pra registrar um abastecimento avulso.',
              style: TextStyle(fontSize: 12, color: Color(0xFF1D4ED8)),
            ),
          ),
          const SizedBox(height: 16),
          if (_erro != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
              child: Text(_erro!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
            ),
            const SizedBox(height: 12),
          ],
          Text('Abastecimento', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_dataHora == null
                ? 'Data e hora'
                : '${_dataHora!.day.toString().padLeft(2, '0')}/${_dataHora!.month.toString().padLeft(2, '0')}/${_dataHora!.year} '
                    '${_dataHora!.hour.toString().padLeft(2, '0')}:${_dataHora!.minute.toString().padLeft(2, '0')}'),
            trailing: const Icon(Icons.calendar_today, size: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: Colors.grey.shade400)),
            onTap: _selecionarDataHora,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _placaCtrl,
            decoration: const InputDecoration(labelText: 'Placa do veículo', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _motoristaCtrl,
            decoration: const InputDecoration(labelText: 'Motorista', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _hodometroCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Hodômetro (km)', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _combustivel,
            decoration: const InputDecoration(labelText: 'Produto', border: OutlineInputBorder(), isDense: true),
            items: [
              const DropdownMenuItem(value: null, child: Text('Selecione...')),
              for (final p in produtosPosto) DropdownMenuItem(value: p, child: Text(p)),
            ],
            onChanged: (v) => setState(() => _combustivel = v),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _litrosCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _recalcularTotal(),
            decoration: const InputDecoration(labelText: 'Litros', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _precoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _recalcularTotal(),
            decoration: const InputDecoration(labelText: 'Preço por litro (R\$)', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _valorTotalCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Valor total (R\$)', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 20),
          Text('Posto', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _postoNomeCtrl,
            decoration: const InputDecoration(labelText: 'Nome do posto', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _postoMunicipioCtrl,
                  decoration: const InputDecoration(labelText: 'Município', border: OutlineInputBorder(), isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _postoUfCtrl,
                  maxLength: 2,
                  decoration: const InputDecoration(labelText: 'UF', border: OutlineInputBorder(), isDense: true, counterText: ''),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _salvando ? null : _salvar,
            child: _salvando
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Lançar Abastecimento'),
          ),
        ],
      ),
    );
  }
}
