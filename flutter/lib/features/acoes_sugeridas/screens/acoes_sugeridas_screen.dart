import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/acoes_sugeridas_provider.dart';
import '../services/acoes_sugeridas_service.dart';

final _dataHoraBr = DateFormat('dd/MM/yyyy HH:mm');

String _fmtDataHora(String? iso) {
  if (iso == null) return '—';
  try {
    return _dataHoraBr.format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

// Fase FLT-Ações-Sugeridas — porta de acoes-sugeridas/page.tsx +
// _components/CardAcaoSugerida.tsx. Pedido do Daniel: "Aba de Ações
// Sugeridas tem que estar no PWA cliente também".
class AcoesSugeridasScreen extends ConsumerStatefulWidget {
  const AcoesSugeridasScreen({super.key});

  @override
  ConsumerState<AcoesSugeridasScreen> createState() => _AcoesSugeridasScreenState();
}

class _AcoesSugeridasScreenState extends ConsumerState<AcoesSugeridasScreen> {
  String? _tipo;
  String _status = 'pendentes';
  String? _busca;
  final _buscaController = TextEditingController();
  bool _detectando = false;
  int? _executandoId;

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _detectar() async {
    final sessao = await ref.read(sessaoProvider.future);
    final empresaId = sessao.empresaId;
    if (empresaId == null || !mounted) return;
    setState(() => _detectando = true);
    final resultado = await AcoesSugeridasService().detectar(empresaId: empresaId);
    if (!mounted) return;
    setState(() => _detectando = false);
    _invalidarListas();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(resultado.erro ?? '${resultado.inseridas ?? 0} oportunidade(s) nova(s) encontrada(s).'),
    ));
  }

  void _invalidarListas() {
    ref.invalidate(acoesSugeridasProvider(FiltrosAcoesSugeridas(tipo: _tipo, status: _status, busca: _busca)));
    ref.invalidate(kpisAcoesSugeridasProvider);
  }

  void _aplicarBusca() {
    final texto = _buscaController.text.trim();
    setState(() => _busca = texto.isEmpty ? null : texto);
  }

  Future<void> _aprovar(AcaoSugerida a) async {
    final pergunta = confirmacaoPorTipoAcaoSugerida[a.tipo] ?? 'Executar esta ação agora?';
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar ação'),
        content: Text(pergunta),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _executandoId = a.id);
    final erro = await AcoesSugeridasService().aprovarEExecutar(id: a.id, tipo: a.tipo);
    if (!mounted) return;
    setState(() => _executandoId = null);
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    _invalidarListas();
  }

  Future<void> _rejeitar(AcaoSugerida a) async {
    setState(() => _executandoId = a.id);
    final erro = await AcoesSugeridasService().rejeitar(a.id);
    if (!mounted) return;
    setState(() => _executandoId = null);
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    _invalidarListas();
  }

  @override
  Widget build(BuildContext context) {
    final filtros = FiltrosAcoesSugeridas(tipo: _tipo, status: _status, busca: _busca);
    final listaAsync = ref.watch(acoesSugeridasProvider(filtros));
    final kpisAsync = ref.watch(kpisAcoesSugeridasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ações Sugeridas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _detectando ? null : _detectar,
        icon: _detectando
            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.search),
        label: Text(_detectando ? 'Detectando...' : 'Detectar oportunidades'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _invalidarListas(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            const Text(
              'Oportunidades detectadas automaticamente — CNH vencida, posto acima da média regional, hodômetro '
              'fora do padrão, volume acima do tanque, postos distantes no mesmo dia e preço fora da média '
              'regional. Aprovar executa a ação de verdade no sistema.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            kpisAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (k) => Row(
                children: [
                  Expanded(child: _kpi('Pendentes', k.pendentes.toString())),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _kpi('Críticas (pendentes)', k.criticasPendentes.toString(),
                        destaque: k.criticasPendentes > 0),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _buscaController,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Buscar por posto, placa ou motorista...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _aplicarBusca(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _aplicarBusca, child: const Text('Buscar')),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DropdownButton<String?>(
                  value: _tipo,
                  hint: const Text('Todos os tipos'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Todos os tipos')),
                    for (final e in tipoLabelAcaoSugerida.entries) DropdownMenuItem<String?>(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _tipo = v),
                ),
                DropdownButton<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: 'pendentes', child: Text('Pendentes')),
                    DropdownMenuItem(value: 'decididas', child: Text('Decididas')),
                    DropdownMenuItem(value: 'todas', child: Text('Todas')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'pendentes'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            listaAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Erro ao carregar: $e'),
              data: (lista) {
                if (lista.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Nenhuma ação sugerida encontrada com esses filtros. Toque em "Detectar oportunidades" '
                        'para analisar CNH, postos, hodômetro e demais indicadores.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  );
                }
                return Column(children: lista.map(_cardAcao).toList());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpi(String label, String valor, {bool destaque = false}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 0.3)),
            const SizedBox(height: 4),
            Text(valor,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: destaque ? const Color(0xFFDC2626) : null)),
          ],
        ),
      ),
    );
  }

  Widget _cardAcao(AcaoSugerida a) {
    final critica = a.severidade == 'critica';
    final pendente = a.status == 'pendente';
    final executandoEsta = _executandoId == a.id;

    String? statusTexto;
    Color? statusCor;
    if (a.status == 'executada') {
      statusTexto = 'Executada${a.decididoPor != null ? ' por ${a.decididoPor}' : ''}';
      statusCor = const Color(0xFF16A34A);
    } else if (a.status == 'rejeitada') {
      statusTexto = 'Rejeitada${a.decididoPor != null ? ' por ${a.decididoPor}' : ''}';
      statusCor = Colors.grey;
    } else if (a.status == 'falhou') {
      statusTexto = 'Falhou: ${a.erroExecucao ?? 'erro desconhecido'}';
      statusCor = const Color(0xFFDC2626);
    }

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
                  decoration: BoxDecoration(
                    color: (critica ? const Color(0xFFDC2626) : const Color(0xFFD97706)).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(a.severidade,
                      style: TextStyle(
                          fontSize: 11,
                          color: critica ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(a.alvoLabel,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                Text(_fmtDataHora(a.criadoEm), style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Text(a.titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(a.descricao, style: const TextStyle(fontSize: 13)),
            if (statusTexto != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusCor!.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(statusTexto, style: TextStyle(fontSize: 11, color: statusCor, fontWeight: FontWeight.w600)),
              ),
            ],
            if (pendente) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: executandoEsta ? null : () => _rejeitar(a),
                    child: const Text('Rejeitar'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: executandoEsta ? null : () => _aprovar(a),
                    child: Text(executandoEsta ? 'Executando...' : 'Aprovar e executar'),
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
