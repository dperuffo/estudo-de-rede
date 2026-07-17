import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sessao_provider.dart';
import '../../roteirizacao/services/geo_service.dart';
import '../providers/fretes_provider.dart';
import '../services/fretes_service.dart';

// Fase PWA-Fretes — porta de fretes/novo/page.tsx + FreteForm.tsx +
// CampoLocalFrete.tsx. Busca de local reaproveita geocodificar() (mesmo
// Nominatim já usado na Roteirização).
class FreteNovoScreen extends ConsumerStatefulWidget {
  const FreteNovoScreen({super.key});

  @override
  ConsumerState<FreteNovoScreen> createState() => _FreteNovoScreenState();
}

class _FreteNovoScreenState extends ConsumerState<FreteNovoScreen> {
  final _tituloCtrl = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  final _tipoCargaCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();

  SugestaoGeocoding? _origem;
  SugestaoGeocoding? _destino;
  DateTime? _dataSaida;
  DateTime? _prazoEntrega;

  String _modo = 'mercado'; // 'mercado' | 'direto'
  String? _motoristaId;

  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descricaoCtrl.dispose();
    _tipoCargaCtrl.dispose();
    _pesoCtrl.dispose();
    _kmCtrl.dispose();
    _valorCtrl.dispose();
    super.dispose();
  }

  Future<void> _publicar(String empresaId) async {
    if (_tituloCtrl.text.trim().isEmpty) {
      setState(() => _erro = 'Título é obrigatório.');
      return;
    }
    if (_origem == null) {
      setState(() => _erro = 'Escolha a origem na lista de sugestões.');
      return;
    }
    if (_destino == null) {
      setState(() => _erro = 'Escolha o destino na lista de sugestões.');
      return;
    }
    final valor = double.tryParse(_valorCtrl.text.replaceAll(',', '.'));
    if (valor == null || valor <= 0) {
      setState(() => _erro = 'Informe um valor de frete válido.');
      return;
    }
    if (_modo == 'direto' && _motoristaId == null) {
      setState(() => _erro = 'Selecione o motorista.');
      return;
    }

    setState(() {
      _enviando = true;
      _erro = null;
    });
    final erro = await FretesService().criarFrete(
      empresaId: empresaId,
      titulo: _tituloCtrl.text,
      descricao: _descricaoCtrl.text,
      origemLabel: _origem!.label,
      origemLat: _origem!.lat,
      origemLon: _origem!.lon,
      destinoLabel: _destino!.label,
      destinoLat: _destino!.lat,
      destinoLon: _destino!.lon,
      tipoCarga: _tipoCargaCtrl.text,
      pesoCargaKg: double.tryParse(_pesoCtrl.text.replaceAll(',', '.')),
      dataSaidaPrevista: _dataSaida?.toIso8601String().split('T').first,
      prazoEntrega: _prazoEntrega?.toIso8601String().split('T').first,
      kmEstimado: double.tryParse(_kmCtrl.text.replaceAll(',', '.')),
      valorOferecido: valor,
      motoristaId: _modo == 'direto' ? _motoristaId : null,
    );
    if (!mounted) return;
    if (erro != null) {
      setState(() {
        _erro = erro;
        _enviando = false;
      });
      return;
    }
    ref.invalidate(meusFretesProvider);
    context.go('/fretes');
  }

  @override
  Widget build(BuildContext context) {
    final sessao = ref.watch(sessaoProvider).valueOrNull;
    final empresaId = sessao?.empresaId;

    return Scaffold(
      appBar: AppBar(title: const Text('Publicar frete')),
      body: empresaId == null
          ? const Center(child: Text('Selecione uma empresa primeiro.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_erro != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                    child: Text(_erro!, style: const TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('Dados do frete', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(controller: _tituloCtrl, decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                _CampoLocalFrete(label: 'Origem', valor: _origem, onEscolhido: (v) => setState(() => _origem = v)),
                const SizedBox(height: 12),
                _CampoLocalFrete(label: 'Destino', valor: _destino, onEscolhido: (v) => setState(() => _destino = v)),
                const SizedBox(height: 12),
                TextField(
                  controller: _tipoCargaCtrl,
                  decoration: const InputDecoration(labelText: 'Tipo de carga', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pesoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Peso da carga (kg)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                _CampoData(
                  label: 'Data de saída prevista',
                  valor: _dataSaida,
                  onEscolhido: (d) => setState(() => _dataSaida = d),
                ),
                const SizedBox(height: 12),
                _CampoData(
                  label: 'Prazo de entrega',
                  valor: _prazoEntrega,
                  onEscolhido: (d) => setState(() => _prazoEntrega = d),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _kmCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Km estimado (opcional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _valorCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Valor do frete (R\$)${_modo == 'mercado' ? ' — valor de partida' : ''}',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descricaoCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descrição (opcional)', border: OutlineInputBorder()),
                ),
                const Divider(height: 32),
                const Text('Quem vai dirigir?', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'Se você já sabe quem vai fazer o frete, atribua direto — ele só confirma ou recusa, sem negociação. '
                  'Se deixar em aberto, qualquer motorista da rede pode ver e propor um valor.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Mercado aberto'),
                        selected: _modo == 'mercado',
                        onSelected: (_) => setState(() => _modo = 'mercado'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Atribuir a um motorista'),
                        selected: _modo == 'direto',
                        onSelected: (_) => setState(() => _modo = 'direto'),
                      ),
                    ),
                  ],
                ),
                if (_modo == 'direto') ...[
                  const SizedBox(height: 12),
                  Consumer(builder: (context, ref, _) {
                    final motoristasAsync = ref.watch(motoristasOpcaoProvider(empresaId));
                    return motoristasAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text('Erro ao carregar motoristas: $e'),
                      data: (motoristas) {
                        if (motoristas.isEmpty) {
                          return const Text(
                            'Nenhum motorista próprio ou parceiro ativo ainda. Cadastre motoristas ou convide parceiros em Motoristas Parceiros.',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          );
                        }
                        return DropdownButtonFormField<String>(
                          initialValue: _motoristaId,
                          decoration: const InputDecoration(labelText: 'Motorista', border: OutlineInputBorder()),
                          items: motoristas
                              .map((m) => DropdownMenuItem(
                                    value: m.id,
                                    child: Text('${m.nome} ${m.origem == 'parceiro' ? '(parceiro)' : ''}'),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _motoristaId = v),
                        );
                      },
                    );
                  }),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _enviando ? null : () => _publicar(empresaId),
                  child: _enviando
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Publicar frete'),
                ),
              ],
            ),
    );
  }
}

class _CampoLocalFrete extends StatefulWidget {
  final String label;
  final SugestaoGeocoding? valor;
  final ValueChanged<SugestaoGeocoding> onEscolhido;

  const _CampoLocalFrete({required this.label, required this.valor, required this.onEscolhido});

  @override
  State<_CampoLocalFrete> createState() => _CampoLocalFreteState();
}

class _CampoLocalFreteState extends State<_CampoLocalFrete> {
  final _controller = TextEditingController();
  List<SugestaoGeocoding> _sugestoes = [];
  bool _buscando = false;

  @override
  void initState() {
    super.initState();
    if (widget.valor != null) _controller.text = widget.valor!.label;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    if (_controller.text.trim().length < 3) return;
    setState(() => _buscando = true);
    final opcoes = await geocodificar(_controller.text);
    if (!mounted) return;
    setState(() {
      _sugestoes = opcoes;
      _buscando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(hintText: 'Digite a cidade e busque...', isDense: true, border: OutlineInputBorder()),
                onSubmitted: (_) => _buscar(),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _buscando ? null : _buscar,
              child: _buscando
                  ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Buscar'),
            ),
          ],
        ),
        if (_sugestoes.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
            child: ListView(
              shrinkWrap: true,
              children: _sugestoes
                  .map((s) => ListTile(
                        dense: true,
                        title: Text(s.label, style: const TextStyle(fontSize: 13)),
                        onTap: () {
                          widget.onEscolhido(s);
                          setState(() {
                            _controller.text = s.label;
                            _sugestoes = [];
                          });
                        },
                      ))
                  .toList(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            widget.valor != null ? '✓ ${widget.valor!.label}' : 'Escolha uma sugestão da busca.',
            style: TextStyle(fontSize: 11, color: widget.valor != null ? Colors.green : Colors.black45),
          ),
        ),
      ],
    );
  }
}

class _CampoData extends StatelessWidget {
  final String label;
  final DateTime? valor;
  final ValueChanged<DateTime> onEscolhido;

  const _CampoData({required this.label, required this.valor, required this.onEscolhido});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final agora = DateTime.now();
        final escolhida = await showDatePicker(
          context: context,
          initialDate: valor ?? agora,
          firstDate: DateTime(agora.year - 1),
          lastDate: DateTime(agora.year + 2),
        );
        if (escolhida != null) onEscolhido(escolhida);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: Text(
          valor != null ? '${valor!.day.toString().padLeft(2, '0')}/${valor!.month.toString().padLeft(2, '0')}/${valor!.year}' : '—',
        ),
      ),
    );
  }
}
