import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/ajuste_abastecimento_provider.dart';
import '../providers/negociacoes_provider.dart' show produtosPosto;
import '../services/ajustes_abastecimentos_service.dart';
import '../services/abastecimentos_posto_service.dart' show nomeProvedor;
import '../../../core/services/sessao_provider.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _numero = NumberFormat.decimalPattern('pt_BR');
final _dataHoraBr = DateFormat('dd/MM/yyyy HH:mm');

const _statusAjusteLabel = <String, String>{
  'pendente_posto': 'Aguardando posto',
  'pendente_cliente': 'Aguardando cliente',
  'aceito': 'Aceito',
  'recusado': 'Recusado',
  'cancelado': 'Cancelado',
};

const _decisaoLabel = <String, String>{
  'pendente': 'Aguardando',
  'aceita': 'Aceita',
  'recusada': 'Recusada',
  'contraproposta': 'Contraproposta enviada',
};

String _fmtDataHora(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    return _dataHoraBr.format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

String _fmtCampo(String campo, dynamic valor) {
  if (valor == null) return '';
  if (campo == 'data_abastecimento') return _fmtDataHora(valor as String);
  if (campo == 'item_valor_unitario' || campo == 'item_valor_total') return _moeda.format(valor as num);
  if (campo == 'item_quantidade') return '${_numero.format(valor as num)} L';
  if (campo == 'hodometro') return '${_numero.format(valor as num)} km';
  return valor.toString();
}

// Fase FLT-2 — detalhe de UM abastecimento (PróFrotas ou externo) + painel
// de ajuste, porta (escopo reduzido — ver README) de
// abastecimentos/[id]/page.tsx + abastecimentos/externo/[id]/page.tsx +
// PainelAjusteAbastecimento.tsx + FormularioSolicitarAjuste.tsx da web.
// "chave" (rota) é "provedor:id", igual à usada na lista de Abastecimentos.
class AbastecimentoDetalheScreen extends ConsumerStatefulWidget {
  final String chave;
  const AbastecimentoDetalheScreen({super.key, required this.chave});

  @override
  ConsumerState<AbastecimentoDetalheScreen> createState() => _AbastecimentoDetalheScreenState();
}

class _AbastecimentoDetalheScreenState extends ConsumerState<AbastecimentoDetalheScreen> {
  final _service = AjustesAbastecimentosService();
  bool _formularioAberto = false;
  bool _processando = false;
  String? _erro;

  late final TextEditingController _dataHora;
  late final TextEditingController _hodometro;
  late final TextEditingController _litros;
  late final TextEditingController _precoUnitario;
  late final TextEditingController _valorTotal;
  final _motivo = TextEditingController();
  String? _combustivel;
  bool _controllersProntos = false;

  // Valores originais (formatados) — pra só enviar o que o usuário de fato
  // mudou, igual à web (Fase 27.67).
  String? _origDataHora;
  String? _origHodometro;
  String? _origCombustivel;
  String? _origLitros;
  String? _origPrecoUnitario;
  String? _origValorTotal;

  void _prepararControllers(AbastecimentoParaAjuste a) {
    if (_controllersProntos) return;
    _origDataHora = a.dataAbastecimento;
    _origHodometro = a.hodometro?.toString();
    _origCombustivel = a.produto;
    _origLitros = a.litros?.toString();
    _origPrecoUnitario = a.precoLitro?.toString();
    _origValorTotal = a.valorTotal?.toString();

    _dataHora = TextEditingController(text: a.dataAbastecimento ?? '');
    _hodometro = TextEditingController(text: a.hodometro != null ? a.hodometro!.toStringAsFixed(0) : '');
    _litros = TextEditingController(text: a.litros != null ? a.litros!.toStringAsFixed(3) : '');
    _precoUnitario = TextEditingController(text: a.precoLitro != null ? a.precoLitro!.toStringAsFixed(2) : '');
    _valorTotal = TextEditingController(text: a.valorTotal != null ? a.valorTotal!.toStringAsFixed(2) : '');
    _combustivel = produtosPosto.contains(a.produto) ? a.produto : null;
    _controllersProntos = true;
  }

  @override
  void dispose() {
    if (_controllersProntos) {
      _dataHora.dispose();
      _hodometro.dispose();
      _litros.dispose();
      _precoUnitario.dispose();
      _valorTotal.dispose();
    }
    _motivo.dispose();
    super.dispose();
  }

  void _recalcularTotal() {
    final l = double.tryParse(_litros.text.trim().replaceAll(',', '.'));
    final p = double.tryParse(_precoUnitario.text.trim().replaceAll(',', '.'));
    if (l != null && p != null) {
      setState(() => _valorTotal.text = (l * p).toStringAsFixed(2));
    }
  }

  Future<void> _selecionarDataHora() async {
    final atual = DateTime.tryParse(_dataHora.text)?.toLocal() ?? DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (data == null || !mounted) return;
    final hora = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(atual));
    if (hora == null) return;
    final combinado = DateTime(data.year, data.month, data.day, hora.hour, hora.minute);
    setState(() => _dataHora.text = combinado.toIso8601String());
  }

  CamposAjuste _montarCampos() {
    double? numeroSeMudou(String textoAtual, String? original) {
      final t = textoAtual.trim();
      if (t.isEmpty) return null;
      final n = double.tryParse(t.replaceAll(',', '.'));
      if (n == null) return null;
      final o = original != null ? double.tryParse(original) : null;
      if (o != null && (o - n).abs() < 0.0005) return null;
      return n;
    }

    return CamposAjuste(
      dataAbastecimento: _dataHora.text.trim().isNotEmpty && _dataHora.text.trim() != (_origDataHora ?? '')
          ? DateTime.parse(_dataHora.text).toUtc().toIso8601String()
          : null,
      hodometro: numeroSeMudou(_hodometro.text, _origHodometro),
      itemNome: (_combustivel != null && _combustivel != _origCombustivel) ? _combustivel : null,
      itemQuantidade: numeroSeMudou(_litros.text, _origLitros),
      itemValorUnitario: numeroSeMudou(_precoUnitario.text, _origPrecoUnitario),
      itemValorTotal: numeroSeMudou(_valorTotal.text, _origValorTotal),
    );
  }

  void _recarregar() {
    ref.invalidate(ajusteAbastecimentoProvider(widget.chave));
  }

  Future<void> _solicitar(AbastecimentoParaAjuste a) async {
    if (a.empresaClienteId == null) {
      setState(() => _erro = 'Cliente deste abastecimento não identificado.');
      return;
    }
    final empresaPostoId = _empresaPostoId;
    if (empresaPostoId == null) {
      setState(() => _erro = 'Não foi possível identificar seu posto na sessão atual.');
      return;
    }
    setState(() {
      _processando = true;
      _erro = null;
    });
    final erro = await _service.criarSolicitacaoAjuste(
      identificador: IdentificadorAbastecimento(tipo: a.identificadorTipo, id: int.parse(a.id)),
      empresaClienteId: a.empresaClienteId!,
      empresaPostoId: empresaPostoId,
      campos: _montarCampos(),
      motivo: _motivo.text.trim().isEmpty ? null : _motivo.text.trim(),
      valorOriginal: a.valorTotal,
    );
    if (!mounted) return;
    setState(() => _processando = false);
    if (erro != null) {
      setState(() => _erro = erro);
    } else {
      setState(() => _formularioAberto = false);
      _recarregar();
    }
  }

  Future<void> _contrapropor(String ajusteId) async {
    setState(() {
      _processando = true;
      _erro = null;
    });
    final erro = await _service.adicionarContraproposta(
      ajusteId: ajusteId,
      campos: _montarCampos(),
      motivo: _motivo.text.trim().isEmpty ? null : _motivo.text.trim(),
    );
    if (!mounted) return;
    setState(() => _processando = false);
    if (erro != null) {
      setState(() => _erro = erro);
    } else {
      setState(() => _formularioAberto = false);
      _recarregar();
    }
  }

  Future<void> _decidir(String ajusteId, bool aceitar) async {
    setState(() {
      _processando = true;
      _erro = null;
    });
    final erro = await _service.decidirAjuste(ajusteId: ajusteId, aceitar: aceitar);
    if (!mounted) return;
    setState(() => _processando = false);
    if (erro != null) {
      setState(() => _erro = erro);
    } else {
      _recarregar();
    }
  }

  Future<void> _cancelar(String ajusteId) async {
    setState(() {
      _processando = true;
      _erro = null;
    });
    final erro = await _service.cancelarAjuste(ajusteId);
    if (!mounted) return;
    setState(() => _processando = false);
    if (erro != null) {
      setState(() => _erro = erro);
    } else {
      _recarregar();
    }
  }

  String? get _empresaPostoId => ref.read(sessaoProvider).valueOrNull?.empresaId;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ajusteAbastecimentoProvider(widget.chave));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Abastecimento'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Não deu pra carregar: $e')),
        data: (d) {
          final a = d.abastecimento;
          if (a == null) return const Center(child: Text('Abastecimento não encontrado.'));
          if (d.minhaVezDeResponder || d.ajusteAberto != null) _prepararControllers(a);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('ID ${a.codigoAbastecimento ?? a.id} · ${nomeProvedor(a.provedor)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Valores atuais', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 12),
                      _valor('Data e hora', _fmtDataHora(a.dataAbastecimento)),
                      _valor('Placa', a.placa ?? '—'),
                      _valor('Motorista', a.motoristaNome ?? '—'),
                      if (a.hodometro != null) _valor('Hodômetro', '${_numero.format(a.hodometro)} km'),
                      _valor('Combustível', a.produto ?? '—'),
                      if (a.litros != null) _valor('Litros', '${_numero.format(a.litros)} L'),
                      if (a.precoLitro != null) _valor('Preço por litro', _moeda.format(a.precoLitro)),
                      if (a.valorTotal != null) _valor('Valor total', _moeda.format(a.valorTotal)),
                      _valor('Cliente', a.nomeCliente ?? '—'),
                    ],
                  ),
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

              _painelAjusteConteudo(d, a),
            ],
          );
        },
      ),
    );
  }

  Widget _valor(String label, String valor) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
            Expanded(child: Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          ],
        ),
      );

  Widget _painelAjusteConteudo(AjusteAbastecimentoDetalhe d, AbastecimentoParaAjuste a) {
    if (d.ajusteAberto == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ajuste de registro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text(
                'Encontrou um erro neste abastecimento? Solicite um ajuste — o cliente recebe uma notificação para aprovar ou recusar antes de qualquer mudança valer.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              // Nova regra do Daniel: abastecimento já em ciclo fechado
              // (faturado) não pode mais ser ajustado — botão desabilitado
              // em vez de escondido, mesmo padrão da web
              // (PainelAjusteAbastecimento.tsx).
              if (a.cicloFechado) ...[
                const OutlinedButton(onPressed: null, child: Text('Solicitar ajuste')),
                const SizedBox(height: 6),
                const Text(
                  'Este abastecimento já está em um ciclo fechado (faturado) e não pode mais ser ajustado.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                ),
              ] else if (!_formularioAberto)
                OutlinedButton(
                  onPressed: () {
                    _prepararControllers(a);
                    setState(() => _formularioAberto = true);
                  },
                  child: const Text('Solicitar ajuste'),
                )
              else
                _formularioCampos(
                  titulo: 'Solicitar ajuste',
                  onEnviar: () => _solicitar(a),
                  onCancelar: () => setState(() => _formularioAberto = false),
                ),
            ],
          ),
        ),
      );
    }

    final ajuste = d.ajusteAberto!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ajuste de registro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12)),
                  child: Text(_statusAjusteLabel[ajuste.status] ?? ajuste.status,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...d.rodadas.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Rodada #${r.numeroRodada} — ${r.autor == 'cliente' ? 'cliente' : 'posto'}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          Text(_fmtDataHora(r.criadoEm), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (r.dataAbastecimento != null) Text('Data/hora: ${_fmtCampo('data_abastecimento', r.dataAbastecimento)}'),
                      if (r.hodometro != null) Text('Hodômetro: ${_fmtCampo('hodometro', r.hodometro)}'),
                      if (r.itemNome != null) Text('Combustível: ${r.itemNome}'),
                      if (r.itemQuantidade != null) Text('Litros: ${_fmtCampo('item_quantidade', r.itemQuantidade)}'),
                      if (r.itemValorUnitario != null)
                        Text('Preço por litro: ${_fmtCampo('item_valor_unitario', r.itemValorUnitario)}'),
                      if (r.itemValorTotal != null) Text('Valor total: ${_fmtCampo('item_valor_total', r.itemValorTotal)}'),
                      if (r.motivo != null && r.motivo!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('"${r.motivo}"',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                        ),
                      const SizedBox(height: 2),
                      Text(_decisaoLabel[r.decisao] ?? r.decisao, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
            if (d.minhaVezDeResponder) ...[
              if (!_formularioAberto)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: _processando ? null : () => _decidir(ajuste.id, true),
                      child: const Text('Aprovar'),
                    ),
                    OutlinedButton(
                      onPressed: _processando
                          ? null
                          : () {
                              _prepararControllers(a);
                              setState(() => _formularioAberto = true);
                            },
                      child: const Text('Enviar contraproposta'),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: _processando ? null : () => _decidir(ajuste.id, false),
                      child: const Text('Recusar'),
                    ),
                  ],
                )
              else
                _formularioCampos(
                  titulo: 'Enviar contraproposta',
                  onEnviar: () => _contrapropor(ajuste.id),
                  onCancelar: () => setState(() => _formularioAberto = false),
                ),
            ] else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(8)),
                child: const Text('Aguardando resposta do cliente.', style: TextStyle(color: Color(0xFF92400E), fontSize: 13)),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _processando ? null : () => _cancelar(ajuste.id),
                child: const Text('Cancelar solicitação', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formularioCampos({required String titulo, required VoidCallback onEnviar, required VoidCallback onCancelar}) {
    if (!_controllersProntos) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 4),
        Text('Os campos já vêm com os valores atuais — edite só o que precisa corrigir.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 12),
        TextField(
          controller: _dataHora,
          readOnly: true,
          onTap: _selecionarDataHora,
          decoration: const InputDecoration(labelText: 'Data e hora', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _hodometro,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Hodômetro (km)', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _combustivel,
          decoration: const InputDecoration(labelText: 'Combustível', border: OutlineInputBorder(), isDense: true),
          items: [
            const DropdownMenuItem(value: null, child: Text('Sem alteração')),
            for (final p in produtosPosto) DropdownMenuItem(value: p, child: Text(p)),
          ],
          onChanged: (v) => setState(() => _combustivel = v),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _litros,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _recalcularTotal(),
          decoration: const InputDecoration(labelText: 'Litros', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _precoUnitario,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _recalcularTotal(),
          decoration: const InputDecoration(labelText: 'Preço por litro (R\$)', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _valorTotal,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Valor total (R\$)', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _motivo,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Motivo (opcional)',
            border: OutlineInputBorder(),
            isDense: true,
            hintText: 'Ex: litros digitados errado, deveria ser 45L',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ElevatedButton(
              onPressed: _processando ? null : onEnviar,
              child: _processando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Enviar'),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: _processando ? null : onCancelar, child: const Text('Cancelar')),
          ],
        ),
      ],
    );
  }
}
