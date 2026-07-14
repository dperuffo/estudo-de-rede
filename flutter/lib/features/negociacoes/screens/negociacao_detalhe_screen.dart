import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../posto/providers/negociacao_detalhe_provider.dart' show RodadaNegociacao;
import '../../posto/providers/negociacoes_provider.dart' show statusNegociacaoLabel, produtosPosto;
import '../../posto/services/negociacoes_service.dart' show DadosRodada;
import '../providers/negociacao_detalhe_cliente_provider.dart';
import '../providers/negociacoes_cliente_provider.dart';
import '../services/negociacoes_cliente_service.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _numero = NumberFormat.decimalPattern('pt_BR');
final _dataBr = DateFormat('dd/MM/yyyy');
final _dataHoraBr = DateFormat('dd/MM/yyyy HH:mm');

String _fmtData(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    return _dataBr.format(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
}

String _fmtDataHora(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    return _dataHoraBr.format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

const _decisaoLabel = {
  'pendente': 'Aguardando',
  'aceita': 'Aceita',
  'recusada': 'Recusada',
  'contraproposta': 'Contraproposta enviada',
};

// Fase FLT-3 — detalhe de uma negociação + ações (cliente), espelho de
// negociacao_detalhe_screen.dart (lado posto, FLT-2). Lógica de negócio
// real mora em negociacoes_cliente_service.dart.
class NegociacaoDetalheClienteScreen extends ConsumerStatefulWidget {
  final String id;
  const NegociacaoDetalheClienteScreen({super.key, required this.id});

  @override
  ConsumerState<NegociacaoDetalheClienteScreen> createState() => _NegociacaoDetalheClienteScreenState();
}

class _NegociacaoDetalheClienteScreenState extends ConsumerState<NegociacaoDetalheClienteScreen> {
  final _service = NegociacoesClienteService();
  bool _mostrarContraproposta = false;
  bool _processando = false;
  String? _erro;

  late final TextEditingController _volume;
  late final TextEditingController _preco;
  late final TextEditingController _inicio;
  late final TextEditingController _fim;
  String? _combustivel;
  bool _controllersProntos = false;

  void _prepararControllers(RodadaNegociacao ultimaRodada) {
    if (_controllersProntos) return;
    _combustivel = produtosPosto.contains(ultimaRodada.combustivel) ? ultimaRodada.combustivel : produtosPosto.first;
    _volume = TextEditingController(text: ultimaRodada.volumeMinimoMensal.toStringAsFixed(0));
    _preco = TextEditingController(text: ultimaRodada.precoUnitario.toStringAsFixed(2));
    _inicio = TextEditingController(text: ultimaRodada.vigenciaInicio);
    _fim = TextEditingController(text: ultimaRodada.vigenciaFim);
    _controllersProntos = true;
  }

  @override
  void dispose() {
    if (_controllersProntos) {
      _volume.dispose();
      _preco.dispose();
      _inicio.dispose();
      _fim.dispose();
    }
    super.dispose();
  }

  void _recarregar() {
    ref.invalidate(negociacaoDetalheClienteProvider(widget.id));
    ref.invalidate(negociacoesClienteProvider);
  }

  Future<void> _decidir(bool aceitar) async {
    setState(() {
      _processando = true;
      _erro = null;
    });
    final erro = await _service.decidirNegociacao(widget.id, aceitar: aceitar);
    if (!mounted) return;
    setState(() => _processando = false);
    if (erro != null) {
      setState(() => _erro = erro);
    } else {
      _recarregar();
    }
  }

  Future<void> _enviarContraproposta() async {
    final volume = double.tryParse(_volume.text.trim().replaceAll(',', '.'));
    final preco = double.tryParse(_preco.text.trim().replaceAll(',', '.'));
    if (volume == null || preco == null || _combustivel == null) {
      setState(() => _erro = 'Preencha todos os campos corretamente.');
      return;
    }
    setState(() {
      _processando = true;
      _erro = null;
    });
    final erro = await _service.adicionarContraproposta(
      widget.id,
      DadosRodada(
        combustivel: _combustivel!,
        vigenciaInicio: _inicio.text.trim(),
        vigenciaFim: _fim.text.trim(),
        volumeMinimoMensal: volume,
        precoUnitario: preco,
      ),
    );
    if (!mounted) return;
    setState(() => _processando = false);
    if (erro != null) {
      setState(() => _erro = erro);
    } else {
      setState(() => _mostrarContraproposta = false);
      _recarregar();
    }
  }

  Future<void> _cancelar() async {
    setState(() {
      _processando = true;
      _erro = null;
    });
    final erro = await _service.cancelarNegociacao(widget.id);
    if (!mounted) return;
    setState(() => _processando = false);
    if (erro != null) {
      setState(() => _erro = erro);
    } else {
      _recarregar();
    }
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

  @override
  Widget build(BuildContext context) {
    final detalheAsync = ref.watch(negociacaoDetalheClienteProvider(widget.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Negociação')),
      body: detalheAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Não deu pra carregar: $e')),
        data: (negociacao) {
          if (negociacao.minhaVezDeResponder && negociacao.ultimaRodada != null) {
            _prepararControllers(negociacao.ultimaRodada!);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                'Negociação com ${negociacao.postoNome ?? 'posto'}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Status: ${statusNegociacaoLabel[negociacao.status] ?? negociacao.status} · '
                'Rodada #${negociacao.rodadaAtual}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              Text(
                'Atualizado em ${_fmtDataHora(negociacao.atualizadoEm)}'
                '${negociacao.nomeAtualizadoPor != null ? ' por ${negociacao.nomeAtualizadoPor}' : ''}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (negociacao.empresaPostoId == null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                  child: const Text(
                    'Este posto ainda não tem cadastro próprio na plataforma — a negociação fica registrada, '
                    'mas só aparece pro lado do posto quando ele se cadastrar com o mesmo CNPJ.',
                    style: TextStyle(color: Color(0xFF1E40AF), fontSize: 12),
                  ),
                ),
              ],
              if (negociacao.emAndamento) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _processando ? null : _cancelar,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Cancelar negociação'),
                  ),
                ),
              ],
              if (_erro != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                  child: Text(_erro!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
                ),
              ],
              const SizedBox(height: 16),
              if (negociacao.minhaVezDeResponder && negociacao.ultimaRodada != null)
                _cardAcoes()
              else if (negociacao.emAndamento)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(8)),
                  child: const Text('Aguardando resposta do posto.',
                      style: TextStyle(color: Color(0xFF92400E), fontSize: 13)),
                ),
              const SizedBox(height: 20),
              const Text('Histórico de rodadas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...negociacao.rodadas.map((r) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Rodada #${r.numeroRodada} — ${r.autor == 'posto' ? 'posto' : 'cliente'}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(_decisaoLabel[r.decisao] ?? r.decisao, style: const TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(r.combustivel),
                          Text('${_numero.format(r.volumeMinimoMensal)} L/mês · ${_moeda.format(r.precoUnitario)}/L'),
                          Text('${_fmtData(r.vigenciaInicio)} – ${_fmtData(r.vigenciaFim)}'),
                        ],
                      ),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }

  Widget _cardAcoes() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('É a sua vez de responder esta negociação.', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              if (!_mostrarContraproposta) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: _processando ? null : () => _decidir(true),
                      child: const Text('Aceitar'),
                    ),
                    OutlinedButton(
                      onPressed: _processando ? null : () => setState(() => _mostrarContraproposta = true),
                      child: const Text('Contrapropor'),
                    ),
                    OutlinedButton(
                      onPressed: _processando ? null : () => _decidir(false),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Recusar'),
                    ),
                  ],
                ),
              ] else if (_controllersProntos) ...[
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _processando ? null : _enviarContraproposta,
                      child: _processando
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Enviar contraproposta'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _processando ? null : () => setState(() => _mostrarContraproposta = false),
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
}
