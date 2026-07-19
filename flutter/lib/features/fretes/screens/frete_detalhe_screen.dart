import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/fretes_provider.dart';
import '../services/fretes_service.dart';
import 'chips_reputacao_motorista.dart';

final _formatoMoedaFreteDet = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

// Fase PWA-Fretes — porta de fretes/[id]/page.tsx: card do frete, painel
// de propostas (mercado aberto), postos recomendados, linha do tempo (com
// fotos de evidência do motorista) e avaliação ao concluir.
class FreteDetalheScreen extends ConsumerWidget {
  final String freteId;
  const FreteDetalheScreen({super.key, required this.freteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final freteAsync = ref.watch(freteDetalheProvider(freteId));

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do frete')),
      body: freteAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (frete) {
          if (frete == null) return const Center(child: Text('Frete não encontrado.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _CartaoFrete(frete: frete),
              const SizedBox(height: 16),
              _BlocoPagamentos(freteId: freteId, freteConcluido: frete.status == 'concluido'),
              if (frete.coleta.preenchido || frete.entrega.preenchido) ...[
                const SizedBox(height: 16),
                _BlocoEndereco(titulo: '📍 Coleta', endereco: frete.coleta),
                const SizedBox(height: 8),
                _BlocoEndereco(titulo: '📍 Entrega', endereco: frete.entrega),
              ],
              const SizedBox(height: 16),
              if (frete.status == 'aguardando_confirmacao')
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Frete atribuído diretamente — aguardando o motorista aceitar ou recusar no app dele.'),
                  ),
                ),
              if (frete.status == 'disponivel') ...[
                const Text('Propostas recebidas', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _PainelPropostas(freteId: freteId, freteAberto: true),
                const SizedBox(height: 16),
              ],
              _BlocoDocumentos(freteId: freteId),
              const SizedBox(height: 16),
              if (frete.status != 'cancelado' && frete.status != 'recusado') ...[
                _BlocoPostosRecomendados(freteId: freteId),
                const SizedBox(height: 16),
              ],
              if (frete.status == 'aceito' || frete.status == 'em_andamento' || frete.status == 'concluido')
                _BlocoTimeline(freteId: freteId),
              if (frete.status == 'concluido') ...[
                const SizedBox(height: 16),
                _BlocoAvaliacao(freteId: freteId),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CartaoFrete extends StatelessWidget {
  final Frete frete;
  const _CartaoFrete({required this.frete});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(frete.titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                Text(labelStatusFrete[frete.status] ?? frete.status, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
            const SizedBox(height: 8),
            Text('${frete.origemLabel} → ${frete.destinoLabel}', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Text(_formatoMoedaFreteDet.format(frete.valorOferecido),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (frete.kmEstimado != null) Text('${frete.kmEstimado!.toStringAsFixed(0)} km', style: const TextStyle(fontSize: 12.5)),
                if (frete.tipoCarga != null) Text('Carga: ${frete.tipoCarga}', style: const TextStyle(fontSize: 12.5)),
                if (frete.pesoCargaKg != null) Text('${frete.pesoCargaKg!.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 12.5)),
              ],
            ),
            if (frete.descricao != null) ...[
              const SizedBox(height: 10),
              Text(frete.descricao!, style: const TextStyle(fontSize: 13)),
            ],
            if (frete.cargaComprimentoM != null || frete.cargaLarguraM != null || frete.cargaAlturaM != null) ...[
              const SizedBox(height: 8),
              Text(
                '📐 Dimensões: ${frete.cargaComprimentoM ?? '—'}m × ${frete.cargaLarguraM ?? '—'}m × ${frete.cargaAlturaM ?? '—'}m (C×L×A)',
                style: const TextStyle(fontSize: 11.5, color: Colors.black54),
              ),
            ],
            if (frete.veiculosAceitos.isNotEmpty || frete.carroceriasAceitas.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ...frete.veiculosAceitos.map((v) => _tagPeq('🚚 $v', Colors.blue)),
                  ...frete.carroceriasAceitas.map((c) => _tagPeq('📦 $c', Colors.black54)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tagPeq(String texto, Color cor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: cor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
        child: Text(texto, style: TextStyle(fontSize: 10.5, color: cor)),
      );
}

class _BlocoEndereco extends StatelessWidget {
  final String titulo;
  final EnderecoFrete endereco;
  const _BlocoEndereco({required this.titulo, required this.endereco});

  @override
  Widget build(BuildContext context) {
    if (!endereco.preenchido) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(endereco.linhaEndereco, style: const TextStyle(fontSize: 13)),
            if (endereco.cep != null) Text('CEP ${endereco.cep}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
            if (endereco.referencia != null)
              Text('Referência: ${endereco.referencia}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
            if (endereco.data != null || endereco.hora != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '🗓️ ${endereco.data ?? 'Data não informada'}${endereco.hora != null ? ' às ${endereco.hora!.substring(0, 5)}' : ''}',
                  style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                ),
              ),
            if (endereco.contatoNome != null || endereco.contatoTelefone != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '👤 ${endereco.contatoNome ?? 'Contato'}${endereco.contatoTelefone != null ? ' — ${endereco.contatoTelefone}' : ''}',
                  style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


class _PainelPropostas extends ConsumerWidget {
  final String freteId;
  final bool freteAberto;
  const _PainelPropostas({required this.freteId, required this.freteAberto});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propostasAsync = ref.watch(propostasFreteProvider(freteId));
    return propostasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Erro ao carregar propostas: $e'),
      data: (propostas) {
        if (propostas.isEmpty) return const Text('Nenhuma proposta recebida ainda.', style: TextStyle(color: Colors.black45));
        return Column(children: propostas.map((p) => _LinhaProposta(freteId: freteId, proposta: p, freteAberto: freteAberto)).toList());
      },
    );
  }
}

class _LinhaProposta extends ConsumerStatefulWidget {
  final String freteId;
  final Proposta proposta;
  final bool freteAberto;
  const _LinhaProposta({required this.freteId, required this.proposta, required this.freteAberto});

  @override
  ConsumerState<_LinhaProposta> createState() => _LinhaPropostaState();
}

class _LinhaPropostaState extends ConsumerState<_LinhaProposta> {
  bool _processando = false;
  bool _contrapropondo = false;
  final _valorCtrl = TextEditingController();
  String? _erro;

  static const _labelStatusNegociacao = {
    'aberta': 'Em negociação',
    'aceita': 'Aceita',
    'recusada': 'Recusada',
    'retirada': 'Motorista retirou',
    'perdida': 'Perdida (outro motorista foi escolhido)',
  };

  @override
  void dispose() {
    _valorCtrl.dispose();
    super.dispose();
  }

  Future<void> _rodar(Future<String?> Function() acao) async {
    setState(() {
      _processando = true;
      _erro = null;
    });
    final erro = await acao();
    if (!mounted) return;
    setState(() {
      _erro = erro;
      _processando = false;
    });
    if (erro == null) {
      ref.invalidate(propostasFreteProvider(widget.freteId));
      ref.invalidate(freteDetalheProvider(widget.freteId));
      ref.invalidate(meusFretesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.proposta;
    final aberta = p.status == 'aberta';
    final podeAgir = aberta && widget.freteAberto && p.ultimoAutor == 'motorista';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.nomeMotorista, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(p.telefoneMotorista ?? '—', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      const SizedBox(height: 4),
                      ChipsReputacaoMotorista(reputacao: p.reputacao),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_formatoMoedaFreteDet.format(p.ultimoValor), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Rodada ${p.rodadaAtual} · última de ${p.ultimoAutor == 'motorista' ? 'motorista' : 'você'}',
                        style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(_labelStatusNegociacao[p.status] ?? p.status, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            if (_erro != null) ...[
              const SizedBox(height: 6),
              Text(_erro!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            if (podeAgir) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: _processando ? null : () => _rodar(() => FretesService().aceitarProposta(p.negociacaoId)),
                    child: const Text('Aceitar'),
                  ),
                  OutlinedButton(
                    onPressed: _processando ? null : () => setState(() => _contrapropondo = !_contrapropondo),
                    child: const Text('Contrapropor'),
                  ),
                  TextButton(
                    onPressed: _processando ? null : () => _rodar(() => FretesService().recusarProposta(p.negociacaoId)),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Recusar'),
                  ),
                ],
              ),
            ],
            if (_contrapropondo) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _valorCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Novo valor (R\$)', isDense: true, border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _processando
                        ? null
                        : () {
                            final valor = double.tryParse(_valorCtrl.text.replaceAll(',', '.'));
                            if (valor == null || valor <= 0) {
                              setState(() => _erro = 'Informe um valor válido.');
                              return;
                            }
                            _rodar(() => FretesService().contraporProposta(p.negociacaoId, valor)).then((_) {
                              if (mounted) setState(() => _contrapropondo = false);
                            });
                          },
                    child: const Text('Enviar'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BlocoPostosRecomendados extends ConsumerWidget {
  final String freteId;
  const _BlocoPostosRecomendados({required this.freteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postosAsync = ref.watch(postosRecomendadosProvider(freteId));
    final itensAsync = ref.watch(itensConvenienciaPostoProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🛢️ Postos recomendados', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Sugira paradas de abastecimento no caminho — pode vincular a um benefício de Parcerias Locais daquele posto.',
              style: TextStyle(fontSize: 11.5, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            postosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Erro: $e'),
              data: (postos) {
                if (postos.isEmpty) return const Text('Nenhum posto recomendado ainda.', style: TextStyle(color: Colors.black45, fontSize: 13));
                return Column(
                  children: postos
                      .map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.nomePosto, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        if (p.itemCatalogoId != null)
                                          const Text('🎟️ com benefício vinculado', style: TextStyle(fontSize: 11, color: Colors.blue)),
                                        if (p.observacao != null) Text(p.observacao!, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      await FretesService().removerPostoRecomendado(p.id);
                                      ref.invalidate(postosRecomendadosProvider(freteId));
                                    },
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text('Remover', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 8),
            _FormPostoRecomendado(
              freteId: freteId,
              itens: itensAsync.valueOrNull ?? [],
              onAdicionado: () => ref.invalidate(postosRecomendadosProvider(freteId)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormPostoRecomendado extends StatefulWidget {
  final String freteId;
  final List<ItemParceriaOpcao> itens;
  final VoidCallback onAdicionado;
  const _FormPostoRecomendado({required this.freteId, required this.itens, required this.onAdicionado});

  @override
  State<_FormPostoRecomendado> createState() => _FormPostoRecomendadoState();
}

class _FormPostoRecomendadoState extends State<_FormPostoRecomendado> {
  final _nomeCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  String? _itemId;
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _adicionar() async {
    setState(() {
      _enviando = true;
      _erro = null;
    });
    final erro = await FretesService().adicionarPostoRecomendado(
      freteId: widget.freteId,
      nomePosto: _nomeCtrl.text,
      itemCatalogoId: _itemId,
      observacao: _obsCtrl.text,
    );
    if (!mounted) return;
    setState(() => _enviando = false);
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }
    _nomeCtrl.clear();
    _obsCtrl.clear();
    setState(() => _itemId = null);
    widget.onAdicionado();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nomeCtrl,
          decoration: const InputDecoration(labelText: 'Nome do posto', isDense: true, border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        if (widget.itens.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: _itemId,
            decoration: const InputDecoration(labelText: 'Vincular benefício (opcional)', isDense: true, border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('Nenhum')),
              ...widget.itens.map((i) => DropdownMenuItem(
                    value: i.id,
                    child: Text(i.parceiroNome != null ? '${i.titulo} — ${i.parceiroNome}' : i.titulo, overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: (v) => setState(() => _itemId = v),
          ),
        const SizedBox(height: 8),
        TextField(
          controller: _obsCtrl,
          decoration: const InputDecoration(labelText: 'Observação (opcional)', isDense: true, border: OutlineInputBorder()),
        ),
        if (_erro != null) ...[
          const SizedBox(height: 6),
          Text(_erro!, style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _enviando ? null : _adicionar,
          child: _enviando ? const Text('...') : const Text('Adicionar'),
        ),
      ],
    );
  }
}

class _BlocoTimeline extends ConsumerWidget {
  final String freteId;
  const _BlocoTimeline({required this.freteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventosAsync = ref.watch(eventosFreteProvider(freteId));
    return eventosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Erro ao carregar linha do tempo: $e'),
      data: (eventos) {
        if (eventos.isEmpty) return const SizedBox.shrink();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📍 Linha do tempo', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...eventos.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(labelEventoFrete[e.tipoEvento] ?? e.tipoEvento, style: const TextStyle(fontSize: 13)),
                              if (e.observacao != null)
                                Text(e.observacao!, style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
                              Text(
                                '${e.criadoEm.toLocal().day.toString().padLeft(2, '0')}/${e.criadoEm.toLocal().month.toString().padLeft(2, '0')} às '
                                '${e.criadoEm.toLocal().hour.toString().padLeft(2, '0')}:${e.criadoEm.toLocal().minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 10.5, color: Colors.black45),
                              ),
                            ],
                          ),
                        ),
                        if (e.fotoUrlAssinada != null)
                          GestureDetector(
                            onTap: () => showDialog(
                              context: context,
                              builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(e.fotoUrlAssinada!))),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(e.fotoUrlAssinada!, width: 44, height: 44, fit: BoxFit.cover),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BlocoAvaliacao extends ConsumerStatefulWidget {
  final String freteId;
  const _BlocoAvaliacao({required this.freteId});

  @override
  ConsumerState<_BlocoAvaliacao> createState() => _BlocoAvaliacaoState();
}

// Fase Destaques-Automaticos — mesma lista permitida pela constraint
// fretes_avaliacoes_tags_validas no banco.
const _tagsDisponiveis = ['Pontual', 'Cuidado com a carga', 'Comunicativo', 'Educado', 'Recomendo'];

class _BlocoAvaliacaoState extends ConsumerState<_BlocoAvaliacao> {
  int _estrelas = 5;
  final _comentarioCtrl = TextEditingController();
  final Set<String> _tagsSelecionadas = {};
  bool _enviando = false;
  bool _enviado = false;
  String? _erro;

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }

  Future<void> _avaliar() async {
    setState(() {
      _enviando = true;
      _erro = null;
    });
    final erro = await FretesService().avaliarMotorista(
      freteId: widget.freteId,
      estrelas: _estrelas,
      comentario: _comentarioCtrl.text,
      tags: _tagsSelecionadas.toList(),
    );
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _erro = erro;
      _enviado = erro == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final avaliacoesAsync = ref.watch(avaliacoesFreteProvider(widget.freteId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⭐ Avaliação', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            avaliacoesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Erro: $e'),
              data: (avaliacoes) {
                final doCliente = avaliacoes.where((a) => a.avaliador == 'cliente').isEmpty
                    ? null
                    : avaliacoes.firstWhere((a) => a.avaliador == 'cliente');
                final doMotorista = avaliacoes.where((a) => a.avaliador == 'motorista').isEmpty
                    ? null
                    : avaliacoes.firstWhere((a) => a.avaliador == 'motorista');

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (doMotorista != null)
                      Text('O motorista te avaliou: ${'★' * doMotorista.estrelas}', style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 8),
                    if (doCliente == null && !_enviado) ...[
                      Row(
                        children: List.generate(5, (i) {
                          final n = i + 1;
                          return IconButton(
                            onPressed: () => setState(() => _estrelas = n),
                            icon: Icon(n <= _estrelas ? Icons.star : Icons.star_border, color: Colors.amber),
                          );
                        }),
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _tagsDisponiveis
                            .map((tag) => FilterChip(
                                  label: Text(tag, style: const TextStyle(fontSize: 12)),
                                  selected: _tagsSelecionadas.contains(tag),
                                  onSelected: (sel) => setState(() => sel ? _tagsSelecionadas.add(tag) : _tagsSelecionadas.remove(tag)),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _comentarioCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Comentário (opcional)', isDense: true, border: OutlineInputBorder()),
                      ),
                      if (_erro != null) ...[
                        const SizedBox(height: 6),
                        Text(_erro!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _enviando ? null : _avaliar,
                        child: Text(_enviando ? 'Enviando...' : 'Avaliar motorista'),
                      ),
                    ] else if (_enviado)
                      const Text('Avaliação enviada. Obrigado!', style: TextStyle(color: Colors.green))
                    else if (doCliente != null)
                      Text(
                        'Você avaliou o motorista: ${'★' * doCliente.estrelas}'
                        '${doCliente.tags.isNotEmpty ? ' — ${doCliente.tags.join(', ')}' : ''}'
                        '${doCliente.comentario != null ? ' — ${doCliente.comentario}' : ''}',
                        style: const TextStyle(fontSize: 13),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Fase Fretes-Adiantamento-Combustível (19/07) — porta de
// PagamentosFrete.tsx (web): parcelas de pagamento do frete (entrada +
// saldo final), geradas automaticamente pelo banco quando o frete vira
// "aceito" (trg_gerar_pagamentos_frete). O saldo final só libera o botão
// depois que o frete está concluído — a regra real mora no banco
// (marcar_pagamento_frete), aqui é só pra não deixar clicar achando que
// vai funcionar.
class _BlocoPagamentos extends ConsumerWidget {
  final String freteId;
  final bool freteConcluido;
  const _BlocoPagamentos({required this.freteId, required this.freteConcluido});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagamentosAsync = ref.watch(pagamentosFreteProvider(freteId));
    return pagamentosAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (pagamentos) {
        if (pagamentos.isEmpty) return const SizedBox.shrink();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💰 Pagamento do frete', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'Confirme aqui quando cada parcela for paga ao motorista — não movimenta dinheiro automaticamente, é só pra controle.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                ...pagamentos.map((p) => _LinhaPagamento(
                      freteId: freteId,
                      pagamento: p,
                      bloqueado: p.tipo == 'saldo_final' && !freteConcluido,
                    )),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LinhaPagamento extends ConsumerStatefulWidget {
  final String freteId;
  final PagamentoFrete pagamento;
  final bool bloqueado;
  const _LinhaPagamento({required this.freteId, required this.pagamento, required this.bloqueado});

  @override
  ConsumerState<_LinhaPagamento> createState() => _LinhaPagamentoState();
}

class _LinhaPagamentoState extends ConsumerState<_LinhaPagamento> {
  bool _enviando = false;
  String? _erro;

  Future<void> _confirmar() async {
    setState(() {
      _enviando = true;
      _erro = null;
    });
    final erro = await FretesService().marcarPagamento(freteId: widget.freteId, tipo: widget.pagamento.tipo);
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _erro = erro;
    });
    if (erro == null) ref.invalidate(pagamentosFreteProvider(widget.freteId));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pagamento;
    final pago = p.status == 'pago';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${labelTipoPagamentoFrete[p.tipo] ?? p.tipo} — ${p.percentual.toStringAsFixed(0)}%',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(_formatoMoedaDoc.format(p.valor), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  if (_erro != null) Text(_erro!, style: const TextStyle(color: Colors.red, fontSize: 11)),
                ],
              ),
            ),
            if (pago)
              const Text('✓ Pago', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))
            else
              OutlinedButton(
                onPressed: (_enviando || widget.bloqueado) ? null : _confirmar,
                child: Text(
                  _enviando ? '...' : (widget.bloqueado ? 'Aguarda conclusão' : 'Confirmar pagamento'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final _formatoMoedaDoc = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

// Fase Fretes-CIOT-CTe (18/07) — porta de FretesDocumentos.tsx (web). CT-e
// entra por upload de XML (validado estruturalmente, ver cte_parser.dart);
// CIOT é cadastro manual (não existe XML público padronizado pra ele) com
// anexo opcional do comprovante da integradora.
class _BlocoDocumentos extends ConsumerStatefulWidget {
  final String freteId;
  const _BlocoDocumentos({required this.freteId});

  @override
  ConsumerState<_BlocoDocumentos> createState() => _BlocoDocumentosState();
}

class _BlocoDocumentosState extends ConsumerState<_BlocoDocumentos> {
  final _numeroCiotCtrl = TextEditingController();
  final _rntrcCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();
  final _valorFreteCtrl = TextEditingController();
  final _observacaoCtrl = TextEditingController();
  PlatformFile? _anexoCiot;
  bool _enviandoCte = false;
  bool _enviandoCiot = false;
  String? _mensagemCte;
  String? _mensagemCiot;
  bool _erroCte = false;
  bool _erroCiot = false;

  @override
  void dispose() {
    _numeroCiotCtrl.dispose();
    _rntrcCtrl.dispose();
    _placaCtrl.dispose();
    _valorFreteCtrl.dispose();
    _observacaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviarCte() async {
    final resultado = await FilePicker.pickFiles(withData: true, type: FileType.custom, allowedExtensions: ['xml']);
    if (resultado == null || resultado.files.isEmpty) return;
    final arquivo = resultado.files.first;
    if (arquivo.bytes == null) return;

    setState(() {
      _enviandoCte = true;
      _mensagemCte = null;
    });
    final texto = utf8.decode(arquivo.bytes!, allowMalformed: true);
    final erro = await FretesService().enviarCte(freteId: widget.freteId, xmlTexto: texto);
    setState(() {
      _enviandoCte = false;
      _erroCte = erro != null;
      _mensagemCte = erro ?? 'CT-e registrado.';
    });
    if (erro == null) ref.invalidate(ctesFreteProvider(widget.freteId));
  }

  Future<void> _registrarCiot() async {
    setState(() {
      _enviandoCiot = true;
      _mensagemCiot = null;
    });
    final valor = _valorFreteCtrl.text.trim().isEmpty ? null : double.tryParse(_valorFreteCtrl.text.trim().replaceAll(',', '.'));
    final erro = await FretesService().registrarCiot(
      freteId: widget.freteId,
      numeroCiot: _numeroCiotCtrl.text,
      rntrc: _rntrcCtrl.text,
      placaVeiculo: _placaCtrl.text,
      valorFrete: valor,
      observacao: _observacaoCtrl.text,
      anexoBytes: _anexoCiot?.bytes,
      anexoNomeArquivo: _anexoCiot?.name,
    );
    setState(() {
      _enviandoCiot = false;
      _erroCiot = erro != null;
      _mensagemCiot = erro ?? 'CIOT registrado.';
    });
    if (erro == null) {
      _numeroCiotCtrl.clear();
      _rntrcCtrl.clear();
      _placaCtrl.clear();
      _valorFreteCtrl.clear();
      _observacaoCtrl.clear();
      setState(() => _anexoCiot = null);
      ref.invalidate(ciotsFreteProvider(widget.freteId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctesAsync = ref.watch(ctesFreteProvider(widget.freteId));
    final ciotsAsync = ref.watch(ciotsFreteProvider(widget.freteId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📄 Documentos do frete (CT-e / CIOT)', style: TextStyle(fontWeight: FontWeight.bold)),
            const Text(
              'Emitidos fora da plataforma (SEFAZ / integradora credenciada na ANTT) — aqui é só o registro.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            const Text('CT-e', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 4),
            ctesAsync.when(
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator()),
              error: (e, _) => Text('Erro: $e', style: const TextStyle(fontSize: 11, color: Colors.red)),
              data: (ctes) => ctes.isEmpty
                  ? const Text('Nenhum CT-e registrado ainda.', style: TextStyle(fontSize: 12, color: Colors.black45))
                  : Column(
                      children: ctes
                          .map((c) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text('Nº ${c.numeroCte ?? "—"} / série ${c.serie ?? "—"}', style: const TextStyle(fontSize: 13)),
                                subtitle: Text(
                                  '${c.valorPrestacao != null ? _formatoMoedaDoc.format(c.valorPrestacao) : "—"} · protocolo ${c.protocoloAutorizacao ?? "—"}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: c.xmlUrlAssinada != null
                                    ? IconButton(icon: const Icon(Icons.description, size: 18), onPressed: () {})
                                    : null,
                              ))
                          .toList(),
                    ),
            ),
            const SizedBox(height: 6),
            ElevatedButton.icon(
              onPressed: _enviandoCte ? null : _enviarCte,
              icon: const Icon(Icons.upload_file, size: 16),
              label: Text(_enviandoCte ? 'Validando...' : 'Enviar XML do CT-e'),
            ),
            if (_mensagemCte != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_mensagemCte!, style: TextStyle(fontSize: 11, color: _erroCte ? Colors.red : Colors.green)),
              ),
            const Divider(height: 24),
            const Text('CIOT', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 4),
            ciotsAsync.when(
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator()),
              error: (e, _) => Text('Erro: $e', style: const TextStyle(fontSize: 11, color: Colors.red)),
              data: (ciots) => ciots.isEmpty
                  ? const Text('Nenhum CIOT registrado ainda.', style: TextStyle(fontSize: 12, color: Colors.black45))
                  : Column(
                      children: ciots
                          .map((c) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(c.numeroCiot, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                                subtitle: Text(
                                  '${c.placaVeiculo ?? "—"} · RNTRC ${c.rntrc ?? "—"} · ${c.valorFrete != null ? _formatoMoedaDoc.format(c.valorFrete) : "—"}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ))
                          .toList(),
                    ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _numeroCiotCtrl,
              decoration: const InputDecoration(labelText: 'Número do CIOT (12 dígitos)', isDense: true),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: TextField(controller: _rntrcCtrl, decoration: const InputDecoration(labelText: 'RNTRC', isDense: true))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _placaCtrl, decoration: const InputDecoration(labelText: 'Placa', isDense: true))),
            ]),
            const SizedBox(height: 6),
            TextField(
              controller: _valorFreteCtrl,
              decoration: const InputDecoration(labelText: 'Valor do frete', isDense: true),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 6),
            TextField(controller: _observacaoCtrl, decoration: const InputDecoration(labelText: 'Observação (opcional)', isDense: true)),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () async {
                final resultado = await FilePicker.pickFiles(withData: true);
                if (resultado != null && resultado.files.isNotEmpty) {
                  setState(() => _anexoCiot = resultado.files.first);
                }
              },
              icon: const Icon(Icons.attach_file, size: 16),
              label: Text(_anexoCiot?.name ?? 'Anexar comprovante (opcional)'),
            ),
            const SizedBox(height: 6),
            ElevatedButton(
              onPressed: _enviandoCiot ? null : _registrarCiot,
              child: Text(_enviandoCiot ? 'Registrando...' : 'Registrar CIOT'),
            ),
            if (_mensagemCiot != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_mensagemCiot!, style: TextStyle(fontSize: 11, color: _erroCiot ? Colors.red : Colors.green)),
              ),
          ],
        ),
      ),
    );
  }
}
