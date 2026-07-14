import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/roteirizacao_provider.dart';

// Fase FLT-3 — Roteirização (cliente): 2 modos ("Por UF/Município" e
// "Consulta por Posto") num só toggle, em vez de abas separadas — ver
// escopo completo em roteirizacao_provider.dart.
class RoteirizacaoScreen extends ConsumerStatefulWidget {
  const RoteirizacaoScreen({super.key});

  @override
  ConsumerState<RoteirizacaoScreen> createState() => _RoteirizacaoScreenState();
}

class _RoteirizacaoScreenState extends ConsumerState<RoteirizacaoScreen> {
  String _modo = 'uf';
  String? _uf;
  final _municipioCtrl = TextEditingController();
  final _termoCtrl = TextEditingController();

  bool _buscando = false;
  String? _erro;
  List<PostoComScore>? _resultado;

  @override
  void dispose() {
    _municipioCtrl.dispose();
    _termoCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final sessao = await ref.read(sessaoProvider.future);
    final empresaId = sessao.empresaId;
    if (empresaId == null) {
      setState(() => _erro = 'Selecione uma empresa antes.');
      return;
    }
    if (_modo == 'uf' && (_uf == null || _uf!.isEmpty)) {
      setState(() => _erro = 'Escolha uma UF para começar.');
      return;
    }
    if (_modo == 'posto' && _termoCtrl.text.trim().isEmpty) {
      setState(() => _erro = 'Digite um CNPJ ou parte do nome do posto.');
      return;
    }

    setState(() {
      _buscando = true;
      _erro = null;
    });

    try {
      final lista = _modo == 'uf'
          ? await RoteirizacaoService().buscarPostosPorUf(
              empresaId: empresaId,
              uf: _uf,
              municipio: _municipioCtrl.text.trim().isEmpty ? null : _municipioCtrl.text.trim(),
            )
          : await RoteirizacaoService().buscarPostoPorTermo(empresaId: empresaId, termo: _termoCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _resultado = lista;
        _buscando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível buscar: $e';
        _buscando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Roteirização')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Consulte a rede de postos por UF/Município ou busque um posto específico — mistura os postos '
            'próprios cadastrados com a base pública de preços ANP.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'uf', label: Text('Por UF/Município')),
              ButtonSegment(value: 'posto', label: Text('Consulta por Posto')),
            ],
            selected: {_modo},
            onSelectionChanged: (s) => setState(() {
              _modo = s.first;
              _resultado = null;
              _erro = null;
            }),
          ),
          const SizedBox(height: 12),
          if (_modo == 'uf') ..._formUf() else ..._formPosto(),
          if (_erro != null) ...[
            const SizedBox(height: 8),
            Text(_erro!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
          ],
          const SizedBox(height: 16),
          if (_buscando) const Center(child: CircularProgressIndicator()),
          if (!_buscando && _resultado != null) ..._resultados(),
        ],
      ),
    );
  }

  List<Widget> _formUf() {
    return [
      Row(
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: _uf,
              decoration: const InputDecoration(labelText: 'UF', border: OutlineInputBorder(), isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('Selecione...')),
                for (final uf in ufsRoteirizacao) DropdownMenuItem(value: uf, child: Text(uf)),
              ],
              onChanged: (v) => setState(() => _uf = v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextField(
              controller: _municipioCtrl,
              decoration:
                  const InputDecoration(labelText: 'Município (opcional)', border: OutlineInputBorder(), isDense: true),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: FilledButton(onPressed: _buscando ? null : _buscar, child: const Text('Buscar')),
      ),
    ];
  }

  List<Widget> _formPosto() {
    return [
      TextField(
        controller: _termoCtrl,
        decoration: const InputDecoration(
          labelText: 'CNPJ ou nome do posto',
          hintText: 'Ex.: 12.345.678/0001-99 ou Posto Ipiranga',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onSubmitted: (_) => _buscar(),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: FilledButton(onPressed: _buscando ? null : _buscar, child: const Text('Buscar')),
      ),
    ];
  }

  List<Widget> _resultados() {
    final lista = _resultado!;
    if (lista.isEmpty) {
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Nenhum posto encontrado.', style: TextStyle(color: Colors.grey.shade600)),
          ),
        ),
      ];
    }
    return [
      Text('Postos (${lista.length})', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      ...lista.map(_cardPosto),
    ];
  }

  Widget _cardPosto(PostoComScore p) {
    final coresGrade = {
      'A': const Color(0xFF10B981),
      'B': const Color(0xFF0EA5E9),
      'C': const Color(0xFFD97706),
      'D': const Color(0xFFDC2626),
    };
    final cor = coresGrade[p.score.grade] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: cor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: Text('${p.score.grade} ${p.score.score.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 11, color: cor, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(p.razaoSocial ?? p.cnpj,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (p.origem == 'anp' ? const Color(0xFF0284C7) : Colors.grey).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(p.origem == 'anp' ? 'Base ANP' : 'Próprio',
                      style: TextStyle(
                          fontSize: 10,
                          color: p.origem == 'anp' ? const Color(0xFF0284C7) : Colors.grey.shade700,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${p.municipio ?? '—'} - ${p.uf ?? '—'}${p.bandeira != null ? ' · ${p.bandeira}' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            if (p.precos.isEmpty)
              Text('Sem preço registrado', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: p.precos
                    .map((preco) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                          child: Text('${preco.combustivel} R\$ ${preco.preco.toStringAsFixed(3)}',
                              style: const TextStyle(fontSize: 11)),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}
