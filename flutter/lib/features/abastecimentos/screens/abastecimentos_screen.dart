import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../../posto/services/abastecimentos_posto_service.dart' show RegistroAbastecimentoPosto, coresProvedor, nomeProvedor, produtosPosto;
import '../services/abastecimentos_cliente_service.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _numero = NumberFormat.decimalPattern('pt_BR');
final _dataHoraBr = DateFormat('dd/MM/yyyy HH:mm');

String _fmtDataHora(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    return _dataHoraBr.format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

// Fase FLT-3 — Abastecimentos (cliente), porta de abastecimentos/page.tsx
// (lado cliente). Modelada de perto em AbastecimentosPostoScreen (FLT-2) —
// mesmo layout/indicadores/filtros —, só troca o serviço/provider (consumo
// da PRÓPRIA frota, não o que um posto forneceu) e adiciona o filtro "🔴
// Pendente de ajuste" que a web tem nesta tela. Ver escopo completo
// (sem paginação real, sem badge de NF-e rejeitada) no comentário de
// abastecimentos_cliente_service.dart.
class AbastecimentosScreen extends ConsumerStatefulWidget {
  const AbastecimentosScreen({super.key});

  @override
  ConsumerState<AbastecimentosScreen> createState() => _AbastecimentosScreenState();
}

class _AbastecimentosScreenState extends ConsumerState<AbastecimentosScreen> {
  final _service = AbastecimentosClienteService();
  final _buscaCtrl = TextEditingController();
  final _deCtrl = TextEditingController();
  final _ateCtrl = TextEditingController();

  String? _combustivel;
  String? _provedor;
  bool _somenteAjustePendente = false;
  Future<ResultadoAbastecimentosCliente>? _futuro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    _deCtrl.dispose();
    _ateCtrl.dispose();
    super.dispose();
  }

  void _carregar() {
    final empresaId = ref.read(sessaoProvider).valueOrNull?.empresaId;
    if (empresaId == null) {
      setState(() => _futuro = Future.value(ResultadoAbastecimentosCliente.vazio));
      return;
    }
    setState(() {
      _futuro = _service.buscar(
        empresaId: empresaId,
        filtros: FiltrosAbastecimentosCliente(
          combustivel: _combustivel,
          provedor: _provedor,
          q: _buscaCtrl.text.trim().isEmpty ? null : _buscaCtrl.text.trim(),
          de: _deCtrl.text.trim().isEmpty ? null : _deCtrl.text.trim(),
          ate: _ateCtrl.text.trim().isEmpty ? null : _ateCtrl.text.trim(),
          somenteAjustePendente: _somenteAjustePendente,
        ),
      );
    });
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
    return Scaffold(
      appBar: AppBar(title: const Text('Abastecimentos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/abastecimentos/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Lançar'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _carregar(),
        child: FutureBuilder<ResultadoAbastecimentosCliente>(
          future: _futuro,
          builder: (context, snap) {
            if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(padding: EdgeInsets.only(top: 80), child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [Text('Não deu pra carregar: ${snap.error}', textAlign: TextAlign.center)],
              );
            }
            final dados = snap.data ?? ResultadoAbastecimentosCliente.vazio;
            final precoMedio = dados.volumeTotal > 0 ? dados.receitaTotal / dados.volumeTotal : 0.0;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                Text(
                  'Alimentado automaticamente pelas integrações com meios de pagamento. '
                  'Lançamento manual também disponível.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: [
                    _indicador('Registros', _numero.format(dados.total)),
                    _indicador('Volume', '${_numero.format(dados.volumeTotal.round())} L'),
                    _indicador('Valor total', _moeda.format(dados.receitaTotal)),
                    _indicador('Custo médio/L', _moeda.format(precoMedio)),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('Todos', _combustivel == null, () {
                      _combustivel = null;
                      _carregar();
                    }),
                    for (final p in produtosPosto)
                      _chip(p, _combustivel == p, () {
                        _combustivel = _combustivel == p ? null : p;
                        _carregar();
                      }),
                  ],
                ),
                if (dados.provedoresOpcoes.length > 1) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip('Todos os meios', _provedor == null, () {
                        _provedor = null;
                        _carregar();
                      }),
                      for (final p in dados.provedoresOpcoes)
                        _chip(nomeProvedor(p), _provedor == p, () {
                          _provedor = _provedor == p ? null : p;
                          _carregar();
                        }),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                FilterChip(
                  label: const Text('🔴 Pendente de ajuste'),
                  selected: _somenteAjustePendente,
                  onSelected: (v) {
                    _somenteAjustePendente = v;
                    _carregar();
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _buscaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Buscar por ID, placa, motorista ou posto',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _carregar(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _deCtrl,
                        readOnly: true,
                        onTap: () => _selecionarData(_deCtrl),
                        decoration:
                            const InputDecoration(labelText: 'De', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _ateCtrl,
                        readOnly: true,
                        onTap: () => _selecionarData(_ateCtrl),
                        decoration:
                            const InputDecoration(labelText: 'Até', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(onPressed: _carregar, child: const Text('Filtrar')),
                ),
                const SizedBox(height: 16),
                if (dados.registros.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text('Nenhum abastecimento encontrado.', style: TextStyle(color: Colors.grey.shade600)),
                      ),
                    ),
                  )
                else
                  ...dados.registros.map((r) => _linhaRegistro(r, dados)),
                if (dados.total > dados.registros.length) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Mostrando os ${dados.registros.length} mais recentes de ${_numero.format(dados.total)}. '
                    'Use os filtros pra refinar — a paginação completa ainda não existe nesta versão do app.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _linhaRegistro(RegistroAbastecimentoPosto r, ResultadoAbastecimentosCliente dados) {
    final temNota = dados.notaPorAbastecimento.containsKey(r.chave);
    final numeroNf = dados.notaPorAbastecimento[r.chave];
    final ajustePendente = dados.comAjustePendente.contains(r.chave);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.push('/abastecimentos/${r.chave}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (ajustePendente)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                  Expanded(
                    child: Text(r.codigoAbastecimento ?? '—', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                  _badgeProvedor(r.provedor),
                ],
              ),
              const SizedBox(height: 4),
              Text(_fmtDataHora(r.dataAbastecimento), style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                '${r.placa ?? '—'} · ${r.motoristaNome ?? '—'}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 6),
              Text('${r.produto ?? '—'} · ${_numero.format(r.litros ?? 0)} L · ${_moeda.format(r.valorTotal ?? 0)}'),
              const SizedBox(height: 6),
              if (temNota)
                _badgeTexto('Emitida${numeroNf != null ? ' · Nº $numeroNf' : ''}', const Color(0xFFDCFCE7), const Color(0xFF15803D))
              else
                _badgeTexto('Pendente', const Color(0xFFFEF3C7), const Color(0xFF92400E)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badgeProvedor(String provedor) {
    final cor = coresProvedor[provedor];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cor != null ? Color(cor) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(nomeProvedor(provedor), style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _badgeTexto(String texto, Color fundo, Color corTexto) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(12)),
        child: Text(texto, style: TextStyle(fontSize: 11, color: corTexto, fontWeight: FontWeight.w600)),
      );

  Widget _indicador(String label, String valor) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(valor, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );

  Widget _chip(String label, bool selecionado, VoidCallback onTap) => ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selecionado,
        onSelected: (_) => onTap(),
      );
}
