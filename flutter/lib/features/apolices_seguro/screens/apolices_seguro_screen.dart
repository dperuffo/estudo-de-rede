import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/sessao_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../services/apolices_seguro_service.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _data = DateFormat('dd/MM/yyyy');

// Fase FLT-Apólices-Seguro (02/09/2026) — porta de apolices-seguro/page.tsx.
// Indicadores (Ativas/Vencendo/Vencidas) e ordenação por vigencia_fim iguais
// à web; ações (editar/excluir) em bottom sheet.
class ApolicesSeguroScreen extends ConsumerStatefulWidget {
  const ApolicesSeguroScreen({super.key});

  @override
  ConsumerState<ApolicesSeguroScreen> createState() =>
      _ApolicesSeguroScreenState();
}

class _ApolicesSeguroScreenState extends ConsumerState<ApolicesSeguroScreen> {
  final _service = ApolicesSeguroService();
  Future<List<ApoliceSeguro>>? _futuro;

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
  }

  Future<void> _excluir(ApoliceSeguro a) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir apólice'),
        content: Text(
            'Excluir a apólice "${a.numeroApolice}"? Essa ação não pode ser desfeita.'),
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
    final erro = await _service.excluir(a.id);
    if (!mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    } else {
      _carregar();
    }
  }

  void _abrirAcoes(ApoliceSeguro a) {
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
                context.push('/apolices-seguro/${a.id}/editar');
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
              title: Text('Excluir', style: TextStyle(color: Colors.red.shade700)),
              onTap: () {
                Navigator.pop(ctx);
                _excluir(a);
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
          title: const Text('Apólices de Seguro')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/apolices-seguro/nova'),
        icon: const Icon(Icons.add),
        label: const Text('Nova Apólice'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _carregar(),
        child: FutureBuilder<List<ApoliceSeguro>>(
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
            final apolices = snap.data ?? const [];
            final vencidas = apolices.where((a) => a.vencida).length;
            final vencendo =
                apolices.where((a) => a.vencendoEm30Dias).length;
            final ativas = apolices.length - vencidas;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                Text(
                  'Número da apólice, seguradora, vigência, cobertura e franquia, com alerta de vencimento.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: [
                    _indicador('Ativas', '$ativas'),
                    _indicador('Vencendo em 30 dias', '$vencendo',
                        destaque: vencendo > 0),
                    _indicador('Vencidas', '$vencidas',
                        alerta: vencidas > 0),
                  ],
                ),
                const SizedBox(height: 16),
                if (apolices.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                            'Nenhuma apólice cadastrada. Toque em "Nova Apólice" para começar.',
                            style: TextStyle(color: Colors.grey.shade600),
                            textAlign: TextAlign.center),
                      ),
                    ),
                  )
                else
                  ...apolices.map(_card),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _card(ApoliceSeguro a) {
    final vencida = a.vencida;
    final vencendo = a.vencendoEm30Dias;
    final corStatus = vencida
        ? const Color(0xFFFEE2E2)
        : vencendo
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFDCFCE7);
    final corStatusTexto = vencida
        ? const Color(0xFFB91C1C)
        : vencendo
            ? const Color(0xFF92400E)
            : const Color(0xFF15803D);
    final statusLabel = vencida ? 'Vencida' : vencendo ? 'Vencendo' : 'Ativa';

    DateTime? tryParse(String iso) => DateTime.tryParse(iso);
    final inicio = tryParse(a.vigenciaInicio);
    final fim = tryParse(a.vigenciaFim);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _abrirAcoes(a),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('${a.seguradora} · ${a.numeroApolice}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: corStatus, borderRadius: BorderRadius.circular(12)),
                    child: Text(statusLabel,
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
              Text(a.placa == null || a.placa!.isEmpty ? 'Frota toda' : a.placa!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              if (a.cobertura != null && a.cobertura!.isNotEmpty)
                Text(a.cobertura!,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                      'Vigência: ${inicio != null ? _data.format(inicio) : '—'} a ${fim != null ? _data.format(fim) : '—'}',
                      style: const TextStyle(fontSize: 12)),
                  if (a.valorFranquia != null)
                    Text('Franquia: ${_moeda.format(a.valorFranquia)}',
                        style: const TextStyle(fontSize: 12)),
                  if (a.valorPremio != null)
                    Text('Prêmio: ${_moeda.format(a.valorPremio)}',
                        style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _indicador(String label, String valor,
          {bool destaque = false, bool alerta = false}) =>
      Card(
        color: alerta
            ? const Color(0xFFFEE2E2)
            : destaque
                ? const Color(0xFFFEF3C7)
                : null,
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
