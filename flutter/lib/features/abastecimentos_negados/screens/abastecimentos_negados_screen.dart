import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/negados_pdv_provider.dart';
import '../services/negados_pdv_service.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _dataHora = DateFormat('dd/MM/yyyy HH:mm');

// Fase 5 PDV (03/10/2026, pedido do Daniel) — porta de
// abastecimentos-negados/page.tsx. O gestor vê as regras impactadas de cada
// abastecimento negado no PDV e libera (ou mantém negado) dentro da validade
// do pedido.
const _vermelho = Color(0xFFEF4444);
const _ambar = Color(0xFFF59E0B);
const _verde = Color(0xFF22C55E);

class AbastecimentosNegadosScreen extends ConsumerStatefulWidget {
  const AbastecimentosNegadosScreen({super.key});

  @override
  ConsumerState<AbastecimentosNegadosScreen> createState() => _AbastecimentosNegadosScreenState();
}

class _AbastecimentosNegadosScreenState extends ConsumerState<AbastecimentosNegadosScreen> {
  Timer? _relogio;
  Timer? _recarga;
  DateTime _agora = DateTime.now();

  @override
  void initState() {
    super.initState();
    _relogio = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _agora = DateTime.now());
    });
    _recarga = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) ref.invalidate(negadosPdvProvider);
    });
  }

  @override
  void dispose() {
    _relogio?.cancel();
    _recarga?.cancel();
    super.dispose();
  }

  Future<void> _decidir(AbastecimentoNegadoPdv item, bool liberar) async {
    final ctrl = TextEditingController();
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(liberar ? 'Liberar abastecimento' : 'Manter negado'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: liberar ? 'Justificativa (obrigatória)' : 'Motivo (opcional)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(liberar ? 'Liberar' : 'Manter negado')),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;
    final erro = await NegadosPdvService().decidir(id: item.id, liberar: liberar, justificativa: ctrl.text);
    if (!mounted) return;
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
    }
    ref.invalidate(negadosPdvProvider);
    ref.invalidate(negadosPdvPendentesProvider);
  }

  String _restante(DateTime expiraEm) {
    final seg = expiraEm.difference(_agora).inSeconds;
    if (seg <= 0) return '0:00';
    return '${seg ~/ 60}:${(seg % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(negadosPdvProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppTheme.glassNavGradient)),
        foregroundColor: AppTheme.glassTexto,
        iconTheme: const IconThemeData(color: AppTheme.glassIcone),
        title: const Text('Abastecimentos negados (PDV)'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(negadosPdvProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ListView(children: const [
            Padding(
              padding: EdgeInsets.all(24),
              child: Text('Não consegui carregar agora. Puxe pra baixo para tentar de novo.', textAlign: TextAlign.center),
            ),
          ]),
          data: (lista) {
            if (lista.isEmpty) {
              return ListView(children: const [
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Nenhum abastecimento negado nos últimos 30 dias.', textAlign: TextAlign.center),
                ),
              ]);
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: lista.length,
              itemBuilder: (_, i) => _cartao(lista[i]),
            );
          },
        ),
      ),
    );
  }

  Widget _cartao(AbastecimentoNegadoPdv item) {
    final vencido = item.situacao == 'pendente' && !item.expiraEm.isAfter(_agora);
    final situacao = vencido ? 'expirado' : item.situacao;
    final cores = {
      'pendente': _ambar,
      'liberado': _verde,
      'recusado': Colors.grey,
      'expirado': Colors.grey,
    };
    final rotulos = {
      'pendente': 'Aguardando decisão',
      'liberado': 'Liberado',
      'recusado': 'Mantido negado',
      'expirado': 'Expirado',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Código ${item.codigo}', style: const TextStyle(fontSize: 11, color: Colors.black45)),
                      Text('${item.placa ?? ''} — ${item.motoristaNome ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (item.motoristaCpf != null)
                        Text('CPF ${item.motoristaCpf}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cores[situacao]!.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(rotulos[situacao]!,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cores[situacao])),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${item.postoNome ?? 'Posto'} · ${_dataHora.format(item.criadoEm)}'
              '${item.valorCombustivel != null ? ' · ${item.combustivel ?? ''} ${item.litros ?? ''} L · ${_moeda.format(item.valorCombustivel)}' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            const Row(children: [
              Icon(Icons.gpp_maybe_outlined, size: 16, color: _vermelho),
              SizedBox(width: 4),
              Text('Regras impactadas',
                  style: TextStyle(fontWeight: FontWeight.w600, color: _vermelho, fontSize: 13)),
            ]),
            const SizedBox(height: 4),
            for (final r in item.regras)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _vermelho.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.titulo,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _vermelho)),
                    Text(r.detalhe, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            if (situacao == 'pendente') ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.timer_outlined, size: 16, color: _ambar),
                const SizedBox(width: 4),
                Text('Validade do pedido: ${_restante(item.expiraEm)} restantes',
                    style: const TextStyle(fontSize: 12, color: _ambar)),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                FilledButton(onPressed: () => _decidir(item, true), child: const Text('Liberar abastecimento')),
                OutlinedButton(onPressed: () => _decidir(item, false), child: const Text('Manter negado')),
              ]),
            ] else if (situacao == 'expirado')
              const Text('O prazo deste pedido expirou — não é mais possível liberar.',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
            if (item.decididoPor != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${item.situacao == 'liberado' ? 'Liberado' : 'Mantido negado'} por ${item.decididoPor}'
                  '${item.decididoEm != null ? ' em ${_dataHora.format(item.decididoEm!)}' : ''}'
                  '${(item.justificativa ?? '').isNotEmpty ? ' — "${item.justificativa}"' : ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
