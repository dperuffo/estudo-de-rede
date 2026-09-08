import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../../veiculos/providers/veiculos_provider.dart';
import '../services/pneus_service.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _numero = NumberFormat.decimalPattern('pt_BR');

// Fase FLT-Gestão-Pneus (02/09/2026) — porta de pneus/page.tsx +
// AcoesPneu.tsx. Km rodado e custo/km calculados ao vivo cruzando
// hodometro_instalacao do pneu com o hodômetro ATUAL do veículo
// (veiculosClienteProvider, já usado em /veiculos) — ou, se já removido,
// com o hodômetro de remoção registrado. Ações (recapar/remover/descartar/
// excluir) em bottom sheet em vez dos botões inline em linha da web —
// cabe melhor no card mobile.
class PneusScreen extends ConsumerStatefulWidget {
  const PneusScreen({super.key});

  @override
  ConsumerState<PneusScreen> createState() => _PneusScreenState();
}

class _PneusScreenState extends ConsumerState<PneusScreen> {
  final _service = PneusService();
  Future<List<Pneu>>? _futuro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    final empresaId = ref.read(sessaoProvider).valueOrNull?.empresaId;
    if (empresaId == null) {
      setState(() => _futuro = Future.value(const []));
      return;
    }
    setState(() => _futuro = _service.buscar(empresaId));
    ref.invalidate(veiculosClienteProvider);
  }

  double? _kmRodado(Pneu p, Map<String, double> hodometroPorPlaca) {
    final hodometroFinal =
        p.ativo ? hodometroPorPlaca[p.placa] : p.hodometroRemocao;
    if (hodometroFinal == null) return null;
    final km = hodometroFinal - p.hodometroInstalacao;
    return km > 0 ? km : null;
  }

  double? _custoPorKm(Pneu p, double? km) {
    if (km == null || km <= 0) return null;
    final custoTotal = (p.valorAquisicao ?? 0) + p.custoRecapagensTotal;
    return custoTotal > 0 ? custoTotal / km : null;
  }

  Future<void> _recapar(Pneu p) async {
    final ctrl = TextEditingController();
    final valorTexto = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar recapagem'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
              labelText: 'Valor pago nesta recapagem (R\$)',
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Registrar')),
        ],
      ),
    );
    ctrl.dispose();
    if (valorTexto == null) return;
    final valor = double.tryParse(valorTexto.trim().replaceAll(',', '.'));
    if (valor == null || valor < 0) {
      _mostrarErro('Valor inválido.');
      return;
    }
    final erro = await _service.registrarRecapagem(p.id, valor);
    if (!mounted) return;
    if (erro != null) {
      _mostrarErro(erro);
    } else {
      _carregar();
    }
  }

  Future<void> _remover(Pneu p, String status) async {
    final motivoCtrl = TextEditingController();
    final hodometroCtrl = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text(status == 'Descartado' ? 'Descartar pneu' : 'Remover pneu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: motivoCtrl,
              decoration: InputDecoration(
                  labelText: 'Motivo (${status.toLowerCase()})',
                  border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: hodometroCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Hodômetro do veículo na remoção (km, opcional)',
                  border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(status == 'Descartado' ? 'Descartar' : 'Remover')),
        ],
      ),
    );
    final motivo = motivoCtrl.text;
    final hodometroTexto = hodometroCtrl.text;
    motivoCtrl.dispose();
    hodometroCtrl.dispose();
    if (confirmado != true) return;
    final hodometro =
        hodometroTexto.trim().isEmpty ? null : double.tryParse(hodometroTexto.trim().replaceAll(',', '.'));
    final erro = await _service.remover(
        id: p.id, status: status, hodometroRemocao: hodometro, motivo: motivo);
    if (!mounted) return;
    if (erro != null) {
      _mostrarErro(erro);
    } else {
      _carregar();
    }
  }

  Future<void> _excluir(Pneu p) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir pneu'),
        content: const Text(
            'Excluir este registro de pneu? Essa ação não pode ser desfeita.'),
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
    final erro = await _service.excluir(p.id);
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

  void _abrirAcoes(Pneu p) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/pneus/${p.id}/editar');
              },
            ),
            if (p.status == 'Em uso') ...[
              ListTile(
                leading: const Icon(Icons.autorenew),
                title: const Text('Recapar'),
                onTap: () {
                  Navigator.pop(ctx);
                  _recapar(p);
                },
              ),
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: const Text('Remover'),
                onTap: () {
                  Navigator.pop(ctx);
                  _remover(p, 'Removido');
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.delete_forever_outlined, color: Colors.red.shade700),
                title: Text('Descartar',
                    style: TextStyle(color: Colors.red.shade700)),
                onTap: () {
                  Navigator.pop(ctx);
                  _remover(p, 'Descartado');
                },
              ),
            ],
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
              title: Text('Excluir', style: TextStyle(color: Colors.red.shade700)),
              onTap: () {
                Navigator.pop(ctx);
                _excluir(p);
              },
            ),
          ],
        ),
      ),
    );
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
          title: const Text('Gestão de Pneus')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/pneus/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Novo Pneu'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _carregar(),
        child: FutureBuilder<List<Pneu>>(
          future: _futuro,
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
            final pneus = snap.data ?? const [];
            final veiculos =
                ref.watch(veiculosClienteProvider).valueOrNull ?? const [];
            final hodometroPorPlaca = <String, double>{
              for (final v in veiculos)
                if (v.hodometroAtual != null) v.placa: v.hodometroAtual!,
            };

            final ativos = pneus.where((p) => p.ativo).length;
            final comMaisDe3Recapagens =
                pneus.where((p) => p.numeroRecapagens >= 3).length;
            final custoTotalInvestido = pneus.fold<double>(
                0, (s, p) => s + (p.valorAquisicao ?? 0) + p.custoRecapagensTotal);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                Text(
                  'Posição no veículo, km rodado, recapagens e custo por km.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: Responsive.colunasGrade(context, mobile: 3, desktop: 4),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: [
                    _indicador('Em uso/estepe', '$ativos'),
                    _indicador('3+ recapagens', '$comMaisDe3Recapagens',
                        destaque: comMaisDe3Recapagens > 0),
                    _indicador(
                        'Investido', _moeda.format(custoTotalInvestido)),
                  ],
                ),
                const SizedBox(height: 16),
                if (pneus.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                            'Nenhum pneu cadastrado. Toque em "Novo Pneu" para começar.',
                            style: TextStyle(color: Colors.grey.shade600),
                            textAlign: TextAlign.center),
                      ),
                    ),
                  )
                else
                  ...pneus.map((p) => _card(p, hodometroPorPlaca)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _card(Pneu p, Map<String, double> hodometroPorPlaca) {
    final km = _kmRodado(p, hodometroPorPlaca);
    final custoKm = _custoPorKm(p, km);
    final corStatus = p.ativo
        ? const Color(0xFFDCFCE7)
        : p.status == 'Descartado'
            ? const Color(0xFFFEE2E2)
            : const Color(0xFFFEF3C7);
    final corStatusTexto = p.ativo
        ? const Color(0xFF15803D)
        : p.status == 'Descartado'
            ? const Color(0xFFB91C1C)
            : const Color(0xFF92400E);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _abrirAcoes(p),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('${p.placa} · ${p.posicao}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: corStatus, borderRadius: BorderRadius.circular(12)),
                    child: Text(p.status,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: corStatusTexto)),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [p.marca, p.modelo].where((s) => s != null && s.isNotEmpty).join(' ').isEmpty
                    ? '—'
                    : [p.marca, p.modelo].where((s) => s != null && s.isNotEmpty).join(' '),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              if (p.medida != null)
                Text(p.medida!,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                      'Km rodado: ${km != null ? "${_numero.format(km.round())} km" : "—"}',
                      style: const TextStyle(fontSize: 12)),
                  Text('Recapagens: ${p.numeroRecapagens}',
                      style: const TextStyle(fontSize: 12)),
                  Text(
                      'Custo/km: ${custoKm != null ? _moeda.format(custoKm) : "—"}',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _indicador(String label, String valor, {bool destaque = false}) =>
      Card(
        color: destaque ? const Color(0xFFFEF3C7) : null,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(valor,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}
