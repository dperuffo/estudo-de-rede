import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../../posto/providers/negociacoes_provider.dart' show produtosPosto;
import '../../posto/services/negociacoes_service.dart' show DadosRodada;
import '../providers/negociacao_detalhe_cliente_provider.dart';
import '../providers/negociacoes_cliente_provider.dart';
import '../services/negociacoes_cliente_service.dart';

// Fase FLT-3 — cria a rodada 1 de uma negociação nova (cliente), espelhando
// negociacoes/novo/page.tsx + FormularioNovaNegociacao.tsx da web (lado
// cliente: informa o CNPJ do posto-alvo). Diferente do lado posto (onde o
// cliente-alvo PRECISA já existir na FNI), aqui a negociação é criada mesmo
// que o posto ainda não tenha cadastro — ver comentário de escopo em
// negociacoes_cliente_service.dart (provisionamento automático com convite
// por e-mail fica de fora do v1, exige Service Role Key).
class CriarNegociacaoClienteScreen extends ConsumerStatefulWidget {
  const CriarNegociacaoClienteScreen({super.key});

  @override
  ConsumerState<CriarNegociacaoClienteScreen> createState() => _CriarNegociacaoClienteScreenState();
}

class _CriarNegociacaoClienteScreenState extends ConsumerState<CriarNegociacaoClienteScreen> {
  final _service = NegociacoesClienteService();
  final _cnpjPosto = TextEditingController();
  final _volume = TextEditingController();
  final _preco = TextEditingController();
  final _inicio = TextEditingController();
  final _fim = TextEditingController();
  String? _combustivel;
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _cnpjPosto.dispose();
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
    final empresaClienteId = sessao?.empresaId;
    if (empresaClienteId == null) {
      setState(() => _erro = 'Não foi possível identificar sua empresa nesta sessão.');
      return;
    }
    if (_cnpjPosto.text.trim().isEmpty) {
      setState(() => _erro = 'Informe o CNPJ do posto.');
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
      empresaClienteId: empresaClienteId,
      cnpjPosto: _cnpjPosto.text,
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

    ref.invalidate(negociacoesClienteProvider);
    if (resultado.id != null) {
      ref.invalidate(negociacaoDetalheClienteProvider(resultado.id!));
      context.pushReplacement('/negociacoes/${resultado.id}');
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova negociação')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const Text(
            'Envie uma proposta de fornecimento para um posto.',
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
            controller: _cnpjPosto,
            decoration: const InputDecoration(
              labelText: 'CNPJ do posto',
              hintText: '00.000.000/0000-00',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Se o posto ainda não tiver cadastro na FNI, a negociação fica registrada mesmo assim e passa '
            'a valer pro lado dele assim que se cadastrar com o mesmo CNPJ.',
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
