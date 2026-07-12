import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/negociacao_detalhe_provider.dart';
import '../providers/negociacoes_provider.dart';
import '../services/negociacoes_service.dart';

// Fase FLT-2 — cria a rodada 1 de uma negociação nova, espelhando
// negociacoes/novo/page.tsx + FormularioNovaNegociacao.tsx da web (lado
// posto: informa o CNPJ do cliente-alvo, que precisa já existir na FNI).
class CriarNegociacaoScreen extends ConsumerStatefulWidget {
  const CriarNegociacaoScreen({super.key});

  @override
  ConsumerState<CriarNegociacaoScreen> createState() => _CriarNegociacaoScreenState();
}

class _CriarNegociacaoScreenState extends ConsumerState<CriarNegociacaoScreen> {
  final _service = NegociacoesService();
  final _cnpjCliente = TextEditingController();
  final _volume = TextEditingController();
  final _preco = TextEditingController();
  final _inicio = TextEditingController();
  final _fim = TextEditingController();
  String? _combustivel;
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _cnpjCliente.dispose();
    _volume.dispose();
    _preco.dispose();
    _inicio.dispose();
    _fim.dispose();
    super.dispose();
  }

  Future<void> _selecionarData(TextEditingController controller) async {
    final atual = DateTime.tryParse(controller.text) ?? DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (escolhida != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(escolhida);
      setState(() {});
    }
  }

  Future<void> _enviar() async {
    final sessao = ref.read(sessaoProvider).valueOrNull;
    final empresaPostoId = sessao?.empresaId;
    if (empresaPostoId == null) {
      setState(() => _erro = 'Não foi possível identificar seu posto nesta sessão.');
      return;
    }
    if (_cnpjCliente.text.trim().isEmpty) {
      setState(() => _erro = 'Informe o CNPJ do cliente.');
      return;
    }
    if (_combustivel == null) {
      setState(() => _erro = 'Selecione o combustível.');
      return;
    }
    final volume = double.tryParse(_volume.text.trim().replaceAll(',', '.'));
    final preco = double.tryParse(_preco.text.trim().replaceAll(',', '.'));
    if (volume == null || volume <= 0) {
      setState(() => _erro = 'Volume mínimo mensal precisa ser um número maior que zero.');
      return;
    }
    if (preco == null || preco <= 0) {
      setState(() => _erro = 'Preço por litro precisa ser um número maior que zero.');
      return;
    }
    if (_inicio.text.trim().isEmpty || _fim.text.trim().isEmpty) {
      setState(() => _erro = 'Preencha a vigência (início e fim).');
      return;
    }

    setState(() {
      _enviando = true;
      _erro = null;
    });

    final resultado = await _service.criarNegociacao(
      empresaPostoId: empresaPostoId,
      cnpjCliente: _cnpjCliente.text,
      dados: DadosRodada(
        combustivel: _combustivel!,
        vigenciaInicio: _inicio.text.trim(),
        vigenciaFim: _fim.text.trim(),
        volumeMinimoMensal: volume,
        precoUnitario: preco,
      ),
    );

    if (!mounted) return;
    setState(() => _enviando = false);

    if (resultado.erro != null) {
      setState(() => _erro = resultado.erro);
      return;
    }

    ref.invalidate(negociacoesPostoProvider);
    if (resultado.id != null) {
      ref.invalidate(negociacaoDetalheProvider(resultado.id!));
      context.pushReplacement('/posto/negociacoes/${resultado.id}');
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova negociação'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const Text(
            'Envie uma proposta de fornecimento para um cliente.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
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
          TextField(
            controller: _cnpjCliente,
            decoration: const InputDecoration(
              labelText: 'CNPJ do cliente',
              hintText: '00.000.000/0000-00',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'O cliente precisa já ser cadastrado na FNI — se o CNPJ não for encontrado, a negociação '
            'não é criada.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _combustivel,
            decoration: const InputDecoration(labelText: 'Combustível', border: OutlineInputBorder(), isDense: true),
            items: produtosPosto.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (v) => setState(() => _combustivel = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _volume,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Volume mínimo mensal (L)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _preco,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Preço por litro (R\$)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _inicio,
            readOnly: true,
            onTap: () => _selecionarData(_inicio),
            decoration: const InputDecoration(
              labelText: 'Vigência — início',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _fim,
            readOnly: true,
            onTap: () => _selecionarData(_fim),
            decoration: const InputDecoration(
              labelText: 'Vigência — fim',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ciclo de faturamento e prazo de vencimento começam em 30/30 dias e são ajustados '
            'depois pelo time FNI — não fazem parte da negociação.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _enviando ? null : _enviar,
              child: _enviando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Enviar negociação'),
            ),
          ),
        ],
      ),
    );
  }
}
