import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../providers/anomalias_provider.dart';
import '../services/anomalias_service.dart';

final _dataBr = DateFormat('dd/MM/yyyy');

String _fmtData(String? iso) {
  if (iso == null) return '—';
  try {
    return _dataBr.format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return iso;
  }
}

class AnomaliasScreen extends ConsumerStatefulWidget {
  const AnomaliasScreen({super.key});

  @override
  ConsumerState<AnomaliasScreen> createState() => _AnomaliasScreenState();
}

class _AnomaliasScreenState extends ConsumerState<AnomaliasScreen> {
  String? _tipo;
  String _status = 'pendentes';
  bool _detectando = false;

  Future<void> _detectar() async {
    final sessao = await ref.read(sessaoProvider.future);
    final empresaId = sessao.empresaId;
    if (empresaId == null || !mounted) return;
    setState(() => _detectando = true);
    final resultado = await AnomaliasService().detectar(empresaId: empresaId);
    if (!mounted) return;
    setState(() => _detectando = false);
    final filtros = FiltrosAnomalias(tipo: _tipo, status: _status);
    ref.invalidate(anomaliasProvider(filtros));
    ref.invalidate(kpisAnomaliasProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(resultado.erro ?? '${resultado.inseridas ?? 0} anomalia(s) nova(s) encontrada(s).'),
    ));
  }

  Future<void> _alternarRevisao(Anomalia a) async {
    final erro = a.revisadoEm == null
        ? await AnomaliasService().marcarRevisada(a.id)
        : await AnomaliasService().desfazerRevisao(a.id);
    if (!mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    ref.invalidate(anomaliasProvider(FiltrosAnomalias(tipo: _tipo, status: _status)));
    ref.invalidate(kpisAnomaliasProvider);
  }

  @override
  Widget build(BuildContext context) {
    final filtros = FiltrosAnomalias(tipo: _tipo, status: _status);
    final listaAsync = ref.watch(anomaliasProvider(filtros));
    final kpisAsync = ref.watch(kpisAnomaliasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Anomalias em Abastecimentos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _detectando ? null : _detectar,
        icon: _detectando
            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.search),
        label: Text(_detectando ? 'Detectando...' : 'Detectar agora'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(anomaliasProvider(filtros));
          ref.invalidate(kpisAnomaliasProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            const Text(
              'Achados automáticos de possível fraude ou erro de lançamento — volume acima do tanque, '
              'postos distantes no mesmo dia, hodômetro retrocedendo e preço fora da média regional.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            kpisAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (k) => Row(
                children: [
                  Expanded(child: _kpi('Não revisadas', k.naoRevisadas.toString())),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _kpi('Críticas (não revisadas)', k.criticasNaoRevisadas.toString(),
                        destaque: k.criticasNaoRevisadas > 0),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DropdownButton<String?>(
                  value: _tipo,
                  hint: const Text('Todos os tipos'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Todos os tipos')),
                    for (final e in tipoLabelAnomalia.entries) DropdownMenuItem<String?>(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _tipo = v),
                ),
                DropdownButton<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: 'pendentes', child: Text('Não revisadas')),
                    DropdownMenuItem(value: 'revisadas', child: Text('Revisadas')),
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
                        'Nenhuma anomalia encontrada com esses filtros. Toque em "Detectar agora" para analisar os abastecimentos mais recentes.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  );
                }
                return Column(children: lista.map(_cardAnomalia).toList());
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

  Widget _cardAnomalia(Anomalia a) {
    final critica = a.severidade == 'critica';
    final revisada = a.revisadoEm != null;
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
                  child: Text(tipoLabelAnomalia[a.tipo] ?? a.tipo,
                      style: TextStyle(
                          fontSize: 11,
                          color: critica ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                          fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                Text(_fmtData(a.dataAbastecimento), style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              [if (a.placa != null) a.placa!, if (a.motoristaNome != null) a.motoristaNome!].join(' · '),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(a.descricao, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (revisada ? const Color(0xFF16A34A) : const Color(0xFFD97706)).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    revisada ? 'Revisado${a.revisadoPor != null ? ' por ${a.revisadoPor}' : ''}' : 'Pendente',
                    style: TextStyle(
                        fontSize: 11,
                        color: revisada ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _alternarRevisao(a),
                  child: Text(revisada ? 'Desfazer' : 'Marcar como revisada'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
