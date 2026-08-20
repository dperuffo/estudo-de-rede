import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/programacao_frota_provider.dart';

import '../../../core/theme/app_theme.dart';

final _dataHora = DateFormat('dd/MM HH:mm');

const Map<String, String> _labelStatus = {
  'aceito': 'Aceito',
  'em_andamento': 'Em andamento',
};

// Fase Programacao-Frota (03/08/2026) — porta de programacao/page.tsx (web)
// pro PWA Cliente. Ver escopo completo em programacao_frota_provider.dart.
class ProgramacaoFrotaScreen extends ConsumerWidget {
  const ProgramacaoFrotaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final veiculosAsync = ref.watch(programacaoFrotaProvider);

    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppTheme.glassNavGradient)),
          foregroundColor: AppTheme.glassTexto,
          iconTheme: const IconThemeData(color: AppTheme.glassIcone),
          title: const Text('Programação de Frota')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(programacaoFrotaProvider),
        child: veiculosAsync.when(
          data: (veiculos) => _corpo(context, veiculos),
          loading: () => ListView(children: const [
            SizedBox(height: 120),
            Center(child: CircularProgressIndicator()),
          ]),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 24),
            Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Erro ao carregar: $e')),
          ]),
        ),
      ),
    );
  }

  Widget _corpo(BuildContext context, List<VeiculoProgramacao> veiculos) {
    final ativos = veiculos.where((v) => v.ativo).toList();
    final emViagem = ativos.where((v) => v.freteId != null).length;
    final semMotorista = ativos.where((v) => v.motoristaId == null).length;
    final livres =
        ativos.where((v) => v.motoristaId != null && v.freteId == null).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Quadro de alocação: qual veículo está em viagem (e até quando fica ocupado), qual está livre e qual '
          'ainda não tem motorista vinculado. Não é rastreamento por GPS.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _cardResumo('Ativos', '${ativos.length}', null)),
            const SizedBox(width: 8),
            Expanded(child: _cardResumo('Em viagem', '$emViagem', null)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _cardResumo('Livres', '$livres', Colors.green)),
            const SizedBox(width: 8),
            Expanded(
                child: _cardResumo('Sem motorista', '$semMotorista',
                    semMotorista > 0 ? Colors.amber : null)),
          ],
        ),
        const SizedBox(height: 16),
        if (ativos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('Nenhum veículo ativo cadastrado ainda.',
                style: TextStyle(color: Colors.grey)),
          )
        else
          ...ativos.map((v) => _cardVeiculo(context, v)),
      ],
    );
  }

  Widget _cardResumo(String titulo, String valor, Color? cor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor?.withValues(alpha: 0.08) ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: cor?.withValues(alpha: 0.3) ?? Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(valor,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w600, color: cor)),
        ],
      ),
    );
  }

  Widget _cardVeiculo(BuildContext context, VeiculoProgramacao v) {
    final situacao = v.motoristaId == null
        ? _SituacaoChip(texto: 'Sem motorista', cor: Colors.amber)
        : v.freteId != null
            ? _SituacaoChip(
                texto:
                    '${_labelStatus[v.freteStatus] ?? v.freteStatus} — ${v.freteTitulo}',
                cor: Colors.blue)
            : const _SituacaoChip(texto: 'Livre agora', cor: Colors.green);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade300)),
      child: InkWell(
        onTap: v.freteId != null
            ? () => context.push('/fretes/${v.freteId}')
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(v.placa,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  situacao,
                ],
              ),
              Text(
                [v.marca, v.modelo]
                        .where((s) => s != null && s.isNotEmpty)
                        .join(' ')
                        .isNotEmpty
                    ? [v.marca, v.modelo]
                        .where((s) => s != null && s.isNotEmpty)
                        .join(' ')
                    : (v.tipoVeiculo ?? '—'),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              Text('Motorista: ${v.nomeMotorista ?? '—'}',
                  style: const TextStyle(fontSize: 12)),
              if (v.freteId != null) ...[
                Text('Destino: ${v.freteDestinoLabel ?? '—'}',
                    style: const TextStyle(fontSize: 12)),
                if (v.disponivelAPartir != null)
                  Text(
                      'Livre a partir de: ${_dataHora.format(v.disponivelAPartir!)}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SituacaoChip extends StatelessWidget {
  final String texto;
  final Color cor;
  const _SituacaoChip({required this.texto, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12)),
      child: Text(texto,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: cor.withValues(alpha: 0.9))),
    );
  }
}
