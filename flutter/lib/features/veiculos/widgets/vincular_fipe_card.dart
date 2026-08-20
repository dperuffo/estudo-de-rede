import 'package:flutter/material.dart';
import '../providers/veiculos_provider.dart';
import '../services/fipe_service.dart';

// Fase TCO 2 (29/07/2026) — porta de VincularFipe.tsx. Cascata
// tipo→marca→modelo→ano pra vincular o veículo a um código FIPE, usada só
// na tela de edição (precisa do id do veículo já existente).
class VincularFipeCard extends StatefulWidget {
  final Veiculo veiculo;
  final VoidCallback onAtualizado;
  const VincularFipeCard(
      {super.key, required this.veiculo, required this.onAtualizado});

  @override
  State<VincularFipeCard> createState() => _VincularFipeCardState();
}

class _VincularFipeCardState extends State<VincularFipeCard> {
  final _servico = FipeVinculoService();

  late bool _editando;
  String? _erro;
  bool _carregandoOpcoes = false;
  bool _salvando = false;

  TipoVeiculoFipe _tipo = 'cars';
  List<FipeOpcao> _marcas = [];
  String? _marcaCode;
  List<FipeOpcao> _modelos = [];
  String? _modeloCode;
  List<FipeOpcao> _anos = [];
  String? _anoCode;

  bool get _jaVinculado =>
      widget.veiculo.codigoFipe != null &&
      widget.veiculo.fipeTipoVeiculo != null &&
      widget.veiculo.fipeAnoCodigo != null;

  @override
  void initState() {
    super.initState();
    _editando = !_jaVinculado;
    if (_editando) _carregarMarcas();
  }

  Future<void> _carregarMarcas() async {
    setState(() {
      _carregandoOpcoes = true;
      _marcas = [];
      _marcaCode = null;
      _modelos = [];
      _modeloCode = null;
      _anos = [];
      _anoCode = null;
    });
    try {
      final marcas = await listarMarcasFipe(_tipo);
      if (!mounted) return;
      setState(() => _marcas = marcas);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = 'Não foi possível buscar as marcas: $e');
    } finally {
      if (mounted) setState(() => _carregandoOpcoes = false);
    }
  }

  Future<void> _carregarModelos(String marcaCode) async {
    setState(() {
      _carregandoOpcoes = true;
      _modelos = [];
      _modeloCode = null;
      _anos = [];
      _anoCode = null;
    });
    try {
      final modelos = await listarModelosFipe(_tipo, marcaCode);
      if (!mounted) return;
      setState(() => _modelos = modelos);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = 'Não foi possível buscar os modelos: $e');
    } finally {
      if (mounted) setState(() => _carregandoOpcoes = false);
    }
  }

  Future<void> _carregarAnos(String marcaCode, String modeloCode) async {
    setState(() {
      _carregandoOpcoes = true;
      _anos = [];
      _anoCode = null;
    });
    try {
      final anos = await listarAnosFipe(_tipo, marcaCode, modeloCode);
      if (!mounted) return;
      setState(() => _anos = anos);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = 'Não foi possível buscar os anos: $e');
    } finally {
      if (mounted) setState(() => _carregandoOpcoes = false);
    }
  }

  Future<void> _vincular() async {
    if (_marcaCode == null || _modeloCode == null || _anoCode == null) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final erro = await _servico.vincular(
      veiculoId: widget.veiculo.id,
      tipo: _tipo,
      marcaCode: _marcaCode!,
      modeloCode: _modeloCode!,
      anoCode: _anoCode!,
    );
    if (!mounted) return;
    setState(() => _salvando = false);
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    setState(() => _editando = false);
    widget.onAtualizado();
  }

  Future<void> _atualizarAgora() async {
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final erro = await _servico.atualizarAgora(widget.veiculo.id);
    if (!mounted) return;
    setState(() => _salvando = false);
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    widget.onAtualizado();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vínculo FIPE', style: Theme.of(context).textTheme.titleSmall),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              'Opcional — vincula o veículo à tabela FIPE pra usar a curva de depreciação real (mês a mês) no TCO, '
              'em vez da estimativa linear.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          if (_erro != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(_erro!,
                  style:
                      const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
            ),
            const SizedBox(height: 8),
          ],
          if (_jaVinculado && !_editando) ...[
            Text('Código FIPE: ${widget.veiculo.codigoFipe}',
                style: const TextStyle(fontSize: 13)),
            Text(
              'Valor atual: ${widget.veiculo.valorFipe != null ? "R\$ ${widget.veiculo.valorFipe!.toStringAsFixed(2)}" : "—"}',
              style: const TextStyle(fontSize: 13),
            ),
            Text('Referência: ${widget.veiculo.mesReferencia ?? "—"}',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton(
                  onPressed: _salvando ? null : _atualizarAgora,
                  child: _salvando
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Atualizar agora'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _salvando
                      ? null
                      : () {
                          setState(() => _editando = true);
                          _carregarMarcas();
                        },
                  child: const Text('Trocar vínculo'),
                ),
              ],
            ),
          ] else ...[
            DropdownButtonFormField<TipoVeiculoFipe>(
              value: _tipo,
              decoration: const InputDecoration(
                  labelText: 'Tipo',
                  border: OutlineInputBorder(),
                  isDense: true),
              items: [
                for (final t in tiposVeiculoFipe)
                  DropdownMenuItem(value: t.$1, child: Text(t.$2))
              ],
              onChanged: _salvando
                  ? null
                  : (val) {
                      if (val == null) return;
                      setState(() => _tipo = val);
                      _carregarMarcas();
                    },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _marcaCode,
              decoration: InputDecoration(
                labelText: _carregandoOpcoes && _marcas.isEmpty
                    ? 'Carregando marcas...'
                    : 'Marca',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final m in _marcas)
                  DropdownMenuItem(
                      value: m.code,
                      child: Text(m.name, overflow: TextOverflow.ellipsis))
              ],
              onChanged: (_salvando || _carregandoOpcoes)
                  ? null
                  : (val) {
                      if (val == null) return;
                      setState(() => _marcaCode = val);
                      _carregarModelos(val);
                    },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _modeloCode,
              decoration: const InputDecoration(
                  labelText: 'Modelo',
                  border: OutlineInputBorder(),
                  isDense: true),
              items: [
                for (final m in _modelos)
                  DropdownMenuItem(
                      value: m.code,
                      child: Text(m.name, overflow: TextOverflow.ellipsis))
              ],
              onChanged: (_salvando || _carregandoOpcoes || _marcaCode == null)
                  ? null
                  : (val) {
                      if (val == null) return;
                      setState(() => _modeloCode = val);
                      _carregarAnos(_marcaCode!, val);
                    },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _anoCode,
              decoration: const InputDecoration(
                  labelText: 'Ano/combustível',
                  border: OutlineInputBorder(),
                  isDense: true),
              items: [
                for (final a in _anos)
                  DropdownMenuItem(
                      value: a.code,
                      child: Text(a.name, overflow: TextOverflow.ellipsis))
              ],
              onChanged: (_salvando || _carregandoOpcoes || _modeloCode == null)
                  ? null
                  : (val) => setState(() => _anoCode = val),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton(
                  onPressed: (_salvando || _anoCode == null) ? null : _vincular,
                  child: _salvando
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Vincular'),
                ),
                if (_jaVinculado) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _salvando
                        ? null
                        : () => setState(() => _editando = false),
                    child: const Text('Cancelar'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
