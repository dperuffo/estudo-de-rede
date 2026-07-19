import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/sessao_provider.dart';
import '../../roteirizacao/services/geo_service.dart';
import '../fretes_veiculos_constantes.dart';
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
  final _comprimentoCtrl = TextEditingController();
  final _larguraCtrl = TextEditingController();
  final _alturaCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  // Fase Fretes-Adiantamento-Combustível (19/07).
  final _percentualAdiantamentoCtrl = TextEditingController(text: '30');
  final _saldoCombustivelCtrl = TextEditingController();
  String _tipoSaldoCombustivel = ''; // '' | 'Valor' | 'Volume'

  SugestaoGeocoding? _origem;
  SugestaoGeocoding? _destino;

  // Fase Fretes-Dados-Completos — endereço completo (não só a cidade de
  // origem/destino acima, que serve só pro cálculo de km/mapa) e horário
  // exato de coleta/entrega, pra o motorista decidir se aceita o frete.
  final _coleta = _EnderecoCompletoDados();
  final _entrega = _EnderecoCompletoDados();

  // Fase Fretes-Dados-Completos-2 — opcional: se vazio, o frete vale pra
  // qualquer motorista; marcando, só quem tem veículo/carroceria compatível
  // vê esse frete na lista dele.
  final Set<String> _veiculosSelecionados = {};
  final Set<String> _carroceriasSelecionadas = {};

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
    _comprimentoCtrl.dispose();
    _larguraCtrl.dispose();
    _alturaCtrl.dispose();
    _kmCtrl.dispose();
    _valorCtrl.dispose();
    _percentualAdiantamentoCtrl.dispose();
    _saldoCombustivelCtrl.dispose();
    _coleta.dispose();
    _entrega.dispose();
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
    final percentualAdiantamento = double.tryParse(_percentualAdiantamentoCtrl.text.replaceAll(',', '.')) ?? 30;
    if (percentualAdiantamento < 0 || percentualAdiantamento > 100) {
      setState(() => _erro = 'Percentual de adiantamento precisa estar entre 0 e 100.');
      return;
    }
    final saldoCombustivelAlocado = double.tryParse(_saldoCombustivelCtrl.text.replaceAll(',', '.'));
    if (_tipoSaldoCombustivel.isNotEmpty && (saldoCombustivelAlocado == null || saldoCombustivelAlocado <= 0)) {
      setState(() => _erro = 'Informe um valor válido pra reserva de combustível.');
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
      kmEstimado: double.tryParse(_kmCtrl.text.replaceAll(',', '.')),
      valorOferecido: valor,
      motoristaId: _modo == 'direto' ? _motoristaId : null,
      cargaComprimentoM: double.tryParse(_comprimentoCtrl.text.replaceAll(',', '.')),
      cargaLarguraM: double.tryParse(_larguraCtrl.text.replaceAll(',', '.')),
      cargaAlturaM: double.tryParse(_alturaCtrl.text.replaceAll(',', '.')),
      coleta: _coleta.paraMapa(),
      entrega: _entrega.paraMapa(),
      veiculosAceitos: _veiculosSelecionados.toList(),
      carroceriasAceitas: _carroceriasSelecionadas.toList(),
      percentualAdiantamento: percentualAdiantamento,
      saldoCombustivelTipo: _tipoSaldoCombustivel.isEmpty ? null : _tipoSaldoCombustivel,
      saldoCombustivelAlocado: saldoCombustivelAlocado,
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _comprimentoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Compr. (m)', isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _larguraCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Largura (m)', isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _alturaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Altura (m)', isDense: true, border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                const Text('Endereços completos', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'Aparece pro motorista antes de aceitar o frete — quanto mais completo, mais fácil pra ele avaliar '
                  'se topa (inclusive a distância até o ponto de coleta).',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                _BlocoEnderecoCompleto(titulo: '📍 Coleta', dados: _coleta),
                const SizedBox(height: 16),
                _BlocoEnderecoCompleto(titulo: '📍 Entrega', dados: _entrega),
                const Divider(height: 32),
                const Text('Veículo e carroceria (opcional)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'Se não marcar nada, o frete aparece pra qualquer motorista. Marcando, só quem tem veículo '
                  'compatível vê esse frete na busca dele.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                ...gruposVeiculoFrete.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.key, style: const TextStyle(fontSize: 11, color: Colors.black45)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: e.value
                              .map((v) => FilterChip(
                                    label: Text(v, style: const TextStyle(fontSize: 12)),
                                    selected: _veiculosSelecionados.contains(v),
                                    onSelected: (sel) => setState(() {
                                      if (sel) {
                                        _veiculosSelecionados.add(v);
                                      } else {
                                        _veiculosSelecionados.remove(v);
                                      }
                                    }),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Carroceria', style: TextStyle(fontSize: 11, color: Colors.black45)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: carroceriasFrete
                      .map((c) => FilterChip(
                            label: Text(c, style: const TextStyle(fontSize: 12)),
                            selected: _carroceriasSelecionadas.contains(c),
                            onSelected: (sel) => setState(() {
                              if (sel) {
                                _carroceriasSelecionadas.add(c);
                              } else {
                                _carroceriasSelecionadas.remove(c);
                              }
                            }),
                          ))
                      .toList(),
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
                const Text('Adiantamento e combustível', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'O motorista aceita o frete → você paga o % de entrada; o resto fica pra pagar na conclusão. '
                  'A reserva de combustível é opcional — se preencher, o motorista abastece com ela primeiro, antes '
                  'da cota normal do veículo.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _percentualAdiantamentoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Adiantamento na aceitação (%)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _tipoSaldoCombustivel,
                  decoration: const InputDecoration(labelText: 'Reserva de combustível', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Sem reserva de combustível')),
                    DropdownMenuItem(value: 'Valor', child: Text('Em R\$')),
                    DropdownMenuItem(value: 'Volume', child: Text('Em litros')),
                  ],
                  onChanged: (v) => setState(() => _tipoSaldoCombustivel = v ?? ''),
                ),
                if (_tipoSaldoCombustivel.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _saldoCombustivelCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: _tipoSaldoCombustivel == 'Valor' ? 'Valor da reserva (R\$)' : 'Volume da reserva (litros)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
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

class _CampoHora extends StatelessWidget {
  final String label;
  final TimeOfDay? valor;
  final ValueChanged<TimeOfDay> onEscolhido;

  const _CampoHora({required this.label, required this.valor, required this.onEscolhido});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final escolhida = await showTimePicker(context: context, initialTime: valor ?? TimeOfDay.now());
        if (escolhida != null) onEscolhido(escolhida);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: Text(valor != null ? valor!.format(context) : '—'),
      ),
    );
  }
}

// Fase Fretes-Dados-Completos — segura os controllers/estado de um bloco
// de endereço completo (coleta ou entrega): rua, número, bairro, cidade,
// UF, CEP, referência, data, hora e contato no local.
class _EnderecoCompletoDados {
  final ruaCtrl = TextEditingController();
  final numeroCtrl = TextEditingController();
  final bairroCtrl = TextEditingController();
  final cidadeCtrl = TextEditingController();
  final ufCtrl = TextEditingController();
  final cepCtrl = TextEditingController();
  final referenciaCtrl = TextEditingController();
  final contatoNomeCtrl = TextEditingController();
  final contatoTelefoneCtrl = TextEditingController();
  DateTime? data;
  TimeOfDay? hora;

  void dispose() {
    ruaCtrl.dispose();
    numeroCtrl.dispose();
    bairroCtrl.dispose();
    cidadeCtrl.dispose();
    ufCtrl.dispose();
    cepCtrl.dispose();
    referenciaCtrl.dispose();
    contatoNomeCtrl.dispose();
    contatoTelefoneCtrl.dispose();
  }

  String? _semAcento(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Map<String, String?> paraMapa() => {
        'rua': _semAcento(ruaCtrl),
        'numero': _semAcento(numeroCtrl),
        'bairro': _semAcento(bairroCtrl),
        'cidade': _semAcento(cidadeCtrl),
        'uf': _semAcento(ufCtrl),
        'cep': _semAcento(cepCtrl),
        'referencia': _semAcento(referenciaCtrl),
        'data': data?.toIso8601String().split('T').first,
        'hora': hora != null ? '${hora!.hour.toString().padLeft(2, '0')}:${hora!.minute.toString().padLeft(2, '0')}' : null,
        'contato_nome': _semAcento(contatoNomeCtrl),
        'contato_telefone': _semAcento(contatoTelefoneCtrl),
      };
}

class _BlocoEnderecoCompleto extends StatefulWidget {
  final String titulo;
  final _EnderecoCompletoDados dados;

  const _BlocoEnderecoCompleto({required this.titulo, required this.dados});

  @override
  State<_BlocoEnderecoCompleto> createState() => _BlocoEnderecoCompletoState();
}

class _BlocoEnderecoCompletoState extends State<_BlocoEnderecoCompleto> {
  @override
  Widget build(BuildContext context) {
    final d = widget.dados;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(controller: d.ruaCtrl, decoration: const InputDecoration(labelText: 'Rua / Av.', isDense: true, border: OutlineInputBorder())),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(controller: d.numeroCtrl, decoration: const InputDecoration(labelText: 'Número', isDense: true, border: OutlineInputBorder())),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(controller: d.bairroCtrl, decoration: const InputDecoration(labelText: 'Bairro', isDense: true, border: OutlineInputBorder())),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(controller: d.cidadeCtrl, decoration: const InputDecoration(labelText: 'Cidade', isDense: true, border: OutlineInputBorder())),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: d.ufCtrl,
                  maxLength: 2,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'UF', isDense: true, border: OutlineInputBorder(), counterText: ''),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(controller: d.cepCtrl, decoration: const InputDecoration(labelText: 'CEP', isDense: true, border: OutlineInputBorder())),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: d.referenciaCtrl,
            decoration: const InputDecoration(labelText: 'Ponto de referência (opcional)', isDense: true, border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _CampoData(label: 'Data', valor: d.data, onEscolhido: (v) => setState(() => d.data = v))),
              const SizedBox(width: 8),
              Expanded(child: _CampoHora(label: 'Hora', valor: d.hora, onEscolhido: (v) => setState(() => d.hora = v))),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: d.contatoNomeCtrl,
            decoration: const InputDecoration(labelText: 'Contato no local (nome)', isDense: true, border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: d.contatoTelefoneCtrl,
            decoration: const InputDecoration(labelText: 'Telefone do contato', isDense: true, border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }
}
