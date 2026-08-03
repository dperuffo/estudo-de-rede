import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/torre_de_controle_provider.dart';
import 'mapa_veiculos.dart';

final _dataHora = DateFormat('dd/MM HH:mm');

const Map<String, String> _labelStatus = {
  'aceito': 'Aceito',
  'em_andamento': 'Em andamento',
};

const Map<String, String> _labelEvento = {
  'chegou_origem': 'Chegou na origem',
  'saiu_origem': 'Saiu da origem',
  'chegou_posto': 'Chegou no posto',
  'abasteceu': 'Abasteceu',
  'parada': 'Parada',
  'chegou_destino': 'Chegou no destino',
  'ocorrencia': 'Ocorrência',
  'concluido': 'Concluiu o frete',
  'panico': '🚨 Alerta de emergência',
};

String _tempoRelativo(DateTime data) {
  final diff = DateTime.now().difference(data);
  if (diff.inMinutes < 1) return 'agora';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'há ${diff.inHours}h';
  return 'há ${diff.inDays} dia${diff.inDays == 1 ? '' : 's'}';
}

// Fase Torre-de-Controle-Leve (03/08/2026) — porta de torre-de-controle/page.tsx
// (web) pro PWA Cliente. Ver escopo completo em torre_de_controle_provider.dart.
class TorreDeControleScreen extends ConsumerWidget {
  const TorreDeControleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fretesAsync = ref.watch(torreDeControleProvider);
    final posicoesAsync = ref.watch(posicoesVeiculosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Torre de Controle')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(torreDeControleProvider);
          ref.invalidate(posicoesVeiculosProvider);
        },
        child: fretesAsync.when(
          data: (fretes) => _corpo(context, fretes, posicoesAsync.value ?? const []),
          loading: () => ListView(children: const [
            SizedBox(height: 120),
            Center(child: CircularProgressIndicator()),
          ]),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 24),
            Padding(padding: const EdgeInsets.all(16), child: Text('Erro ao carregar: $e')),
          ]),
        ),
      ),
    );
  }

  Widget _corpo(BuildContext context, List<FreteAndamento> fretes, List<PosicaoVeiculo> posicoes) {
    final totalVencendo = fretes.where((f) => f.vencendoEmBreve).length;
    final totalAtrasados = fretes.where((f) => f.atrasado).length;
    final totalPanico = fretes.where((f) => f.tevePanico).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Visão única dos fretes em andamento agora, com o último checkpoint registrado pelo motorista e alerta '
          'de prazo. Não é rastreamento por GPS — é baseado nos eventos que o motorista confirma no app.'
          '${posicoes.isEmpty ? ' Se você conectar um sistema de rastreamento (qualquer provedor) em Integrações, um mapa ao vivo aparece aqui também.' : ''}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        if (posicoes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Mapa ao vivo (${posicoes.length} veículo${posicoes.length == 1 ? '' : 's'})',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          MapaVeiculos(posicoes: posicoes),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _cardResumo('Em andamento', '${fretes.length}', null)),
            const SizedBox(width: 8),
            Expanded(child: _cardResumo('Vencendo ≤6h', '$totalVencendo', totalVencendo > 0 ? Colors.amber : null)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _cardResumo('Prazo estourado', '$totalAtrasados', totalAtrasados > 0 ? Colors.red : null)),
            const SizedBox(width: 8),
            Expanded(child: _cardResumo('🚨 Emergência', '$totalPanico', totalPanico > 0 ? Colors.red.shade700 : null)),
          ],
        ),
        const SizedBox(height: 16),
        if (fretes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('Nenhum frete em andamento agora.', style: TextStyle(color: Colors.grey)),
          )
        else
          ...fretes.map((f) => _cardFrete(context, f)),
      ],
    );
  }

  Widget _cardResumo(String titulo, String valor, Color? cor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor?.withValues(alpha: 0.08) ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor?.withValues(alpha: 0.3) ?? Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(valor, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cor)),
        ],
      ),
    );
  }

  Widget _cardFrete(BuildContext context, FreteAndamento f) {
    final corBorda = f.tevePanico
        ? Colors.red.shade700
        : f.atrasado
            ? Colors.red.shade300
            : f.vencendoEmBreve
                ? Colors.amber.shade300
                : Colors.grey.shade300;
    final corFundo = f.tevePanico
        ? Colors.red.shade50
        : f.atrasado
            ? Colors.red.shade50
            : f.vencendoEmBreve
                ? Colors.amber.shade50
                : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: corFundo,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: corBorda)),
      child: InkWell(
        onTap: () => context.push('/fretes/${f.id}'),
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
                    child: Text(f.titulo, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  ),
                  if (f.tevePanico)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.red.shade700, borderRadius: BorderRadius.circular(12)),
                      child: const Text('🚨 Emergência', style: TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                ],
              ),
              Text('${f.origemLabel} → ${f.destinoLabel}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text('Motorista: ${f.nomeMotorista ?? '—'}', style: const TextStyle(fontSize: 12)),
                  Text(
                    'Checkpoint: ${f.ultimoEventoTipo != null ? (_labelEvento[f.ultimoEventoTipo] ?? f.ultimoEventoTipo!) : 'Nenhum ainda'}'
                    '${f.ultimoEventoEm != null ? ' (${_tempoRelativo(f.ultimoEventoEm!)})' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (f.prazoLimite != null)
                    Text(
                      '${f.atrasado ? 'Prazo estourado' : 'Prazo'}: ${_dataHora.format(f.prazoLimite!)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: f.atrasado ? Colors.red : (f.vencendoEmBreve ? Colors.amber.shade800 : null),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Status: ${_labelStatus[f.status] ?? f.status}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
