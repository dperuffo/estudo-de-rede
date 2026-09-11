import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../services/fidelidade_motoristas_service.dart';

final _numero = NumberFormat.decimalPattern('pt_BR');

// Fase FLT-Fidelidade-Motoristas (02/09/2026) — porta de
// fidelidade-motoristas/page.tsx + MissoesGestao.tsx. Sem seletor de
// cliente (diferente da web multi-empresa do admin) — o app Cliente só
// tem 1 empresa por sessão, igual às outras telas do PWA.
class FidelidadeMotoristasScreen extends ConsumerStatefulWidget {
  const FidelidadeMotoristasScreen({super.key});

  @override
  ConsumerState<FidelidadeMotoristasScreen> createState() =>
      _FidelidadeMotoristasScreenState();
}

class _FidelidadeMotoristasScreenState
    extends ConsumerState<FidelidadeMotoristasScreen> {
  final _service = FidelidadeMotoristasService();
  Future<List<IndicadorFidelidadeMotorista>>? _futuroIndicadores;
  Future<List<MissaoFidelidade>>? _futuroMissoes;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    final empresaId = ref.read(sessaoProvider).valueOrNull?.empresaId;
    if (empresaId == null) {
      setState(() {
        _futuroIndicadores = Future.value(const []);
        _futuroMissoes = Future.value(const []);
      });
      return;
    }
    setState(() {
      _futuroIndicadores = _service.buscarIndicadores(empresaId);
      _futuroMissoes = _service.buscarMissoes(empresaId);
    });
  }

  Future<void> _novaMissao() async {
    final empresaId = ref.read(sessaoProvider).valueOrNull?.empresaId;
    if (empresaId == null) return;
    final codigoCtrl = TextEditingController();
    final tituloCtrl = TextEditingController();
    final descricaoCtrl = TextEditingController();
    final tipoMetricaCtrl = TextEditingController();
    final metaCtrl = TextEditingController();
    final bonusCtrl = TextEditingController();

    final salvar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova missão'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codigoCtrl,
                decoration: const InputDecoration(
                    labelText: 'Código *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: tituloCtrl,
                decoration: const InputDecoration(
                    labelText: 'Título *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descricaoCtrl,
                decoration: const InputDecoration(
                    labelText: 'Descrição', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: tipoMetricaCtrl,
                decoration: const InputDecoration(
                    labelText: 'Tipo de métrica *',
                    hintText: 'ex: litros_abastecidos',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: metaCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Meta *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bonusCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Bônus em pontos *',
                    border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Criar')),
        ],
      ),
    );
    if (salvar != true) return;
    final meta = double.tryParse(metaCtrl.text.trim().replaceAll(',', '.'));
    final bonus = double.tryParse(bonusCtrl.text.trim().replaceAll(',', '.'));
    if (meta == null || bonus == null) {
      _mostrarErro('Meta e bônus precisam ser números válidos.');
      return;
    }
    final erro = await _service.criarMissao(
      empresaId: empresaId,
      codigo: codigoCtrl.text,
      titulo: tituloCtrl.text,
      descricao: descricaoCtrl.text,
      tipoMetrica: tipoMetricaCtrl.text,
      meta: meta,
      bonus: bonus,
    );
    if (!mounted) return;
    if (erro != null) {
      _mostrarErro(erro);
    } else {
      _carregar();
    }
  }

  Future<void> _excluirMissao(MissaoFidelidade missao) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir missão'),
        content: Text('Excluir a missão "${missao.titulo}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmado != true) return;
    final erro = await _service.excluirMissao(missao.id);
    if (!mounted) return;
    if (erro != null) {
      _mostrarErro(erro);
    } else {
      _carregar();
    }
  }

  Future<void> _alternarAtiva(MissaoFidelidade missao) async {
    final erro = await _service.alternarAtiva(missao.id, !missao.ativa);
    if (!mounted) return;
    if (erro != null) {
      _mostrarErro(erro);
    } else {
      _carregar();
    }
  }

  void _mostrarErro(String texto) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessaoProvider, (prev, next) {
      final idAnterior = prev?.valueOrNull?.empresaId;
      final idAtual = next.valueOrNull?.empresaId;
      if (idAtual != null && idAtual != idAnterior) _carregar();
    });
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Fidelidade dos Motoristas')),
      body: RefreshIndicator(
        onRefresh: () async => _carregar(),
        child: FutureBuilder<List<IndicadorFidelidadeMotorista>>(
          future: _futuroIndicadores,
          builder: (context, snap) {
            if (!snap.hasData &&
                snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text('Não deu pra carregar: ${snap.error}',
                      textAlign: TextAlign.center)
                ],
              );
            }
            final indicadores = snap.data ?? const [];
            final aderidos = indicadores.where((m) => m.aderido).length;
            final abastecimentos = indicadores.fold<int>(
                0, (s, m) => s + m.abastecimentosConfirmados);
            final missoesConcluidas =
                indicadores.fold<int>(0, (s, m) => s + m.missoesConcluidas);
            final resgatesConcluidos =
                indicadores.fold<int>(0, (s, m) => s + m.resgatesConcluidos);
            final resgatesTotal =
                indicadores.fold<int>(0, (s, m) => s + m.resgatesTotal);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  'Pontos, nível e engajamento dos motoristas no programa de fidelidade.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: Responsive.colunasGrade(context, mobile: 2, desktop: 4),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.6,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: [
                    _indicador('Motoristas aderidos',
                        '$aderidos/${indicadores.length}'),
                    _indicador('Abastecimentos confirmados',
                        _numero.format(abastecimentos)),
                    _indicador(
                        'Missões concluídas', _numero.format(missoesConcluidas)),
                    _indicador('Resgates concluídos',
                        '$resgatesConcluidos/$resgatesTotal'),
                  ],
                ),
                const SizedBox(height: 20),
                if (indicadores.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text('Nenhum motorista com dados de fidelidade.',
                            style: TextStyle(color: Colors.grey.shade600),
                            textAlign: TextAlign.center),
                      ),
                    ),
                  )
                else
                  ...indicadores.map(_cardMotorista),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Missões',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: _novaMissao,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nova missão'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<MissaoFidelidade>>(
                  future: _futuroMissoes,
                  builder: (context, snapM) {
                    final missoes = snapM.data ?? const [];
                    if (missoes.isEmpty) {
                      return Text('Nenhuma missão cadastrada.',
                          style: TextStyle(color: Colors.grey.shade600));
                    }
                    return Column(children: missoes.map(_cardMissao).toList());
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _cardMotorista(IndicadorFidelidadeMotorista m) {
    final nivel = nivelDoSaldo(m.saldoPontos);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Tooltip(
                    message: m.nomeCompleto,
                    child: Text(m.nomeCompleto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: m.aderido
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(m.aderido ? 'Aderido' : 'Não aderiu',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: m.aderido
                              ? const Color(0xFF15803D)
                              : Colors.grey.shade600)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text('Nível: $nivel',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                Text('Pontos: ${_numero.format(m.saldoPontos.round())}',
                    style: const TextStyle(fontSize: 12)),
                Text('Abastecimentos: ${m.abastecimentosConfirmados}',
                    style: const TextStyle(fontSize: 12)),
                Text('Missões: ${m.missoesConcluidas}',
                    style: const TextStyle(fontSize: 12)),
                Text('Resgates: ${m.resgatesConcluidos}/${m.resgatesTotal}',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardMissao(MissaoFidelidade missao) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(missao.titulo),
          subtitle: Text(
              '${missao.tipoMetrica} · meta ${_numero.format(missao.meta)} · bônus ${_numero.format(missao.bonus)} pts'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: missao.ativa,
                onChanged: (_) => _alternarAtiva(missao),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                onPressed: () => _excluirMissao(missao),
              ),
            ],
          ),
        ),
      );

  Widget _indicador(String label, String valor) => Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(valor,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}
