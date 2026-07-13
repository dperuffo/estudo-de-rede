import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../posto/providers/financeiro_posto_provider.dart' show CicloAbertoResumo, FaturaFinanceiro;

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _numero = NumberFormat.decimalPattern('pt_BR');

const _statusFaturaLabel = <String, String>{
  'aberta': 'Em aberto',
  'vencida': 'Vencida',
  'paga': 'Paga',
  'cancelada': 'Cancelada',
};

String _fmtData(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    return DateFormat('dd/MM/yyyy').format(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
}

String _statusExibicao(String status, String? vencimento) {
  if (status == 'aberta' && vencimento != null) {
    final hoje = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (vencimento.substring(0, 10).compareTo(hoje) < 0) return 'vencida';
  }
  return status;
}

// Fase FLT-3 — pedido do Daniel: "Ver histórico" na Cobrança em Aberto
// (visão Cliente), equivalente ao ClientePostoDetalheScreen do Posto, mas
// com escopo bem mais enxuto: como aqui não tem uma tela "Postos
// Revendedores" ainda (cadastro do posto, negociações — ver lista de
// tarefas FLT-3), esta versão só mostra o que já estava carregado na tela
// de Financeiro (ciclo em andamento + TODAS as faturas com este posto, não
// só as 10 mais recentes) — recebido via `extra` do GoRouter, sem consulta
// nova ao banco.
class PostoCobrancaDetalheScreen extends StatelessWidget {
  final String postoNome;
  final int cicloFaturamentoDias;
  final int prazoVencimentoDias;
  final CicloAbertoResumo? cicloAtual;
  final List<FaturaFinanceiro> faturas;

  const PostoCobrancaDetalheScreen({
    super.key,
    required this.postoNome,
    required this.cicloFaturamentoDias,
    required this.prazoVencimentoDias,
    required this.cicloAtual,
    required this.faturas,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(postoNome),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(postoNome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (cicloFaturamentoDias > 0) ...[
                    const SizedBox(height: 6),
                    Text('Ciclo $cicloFaturamentoDias+$prazoVencimentoDias dias',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Ciclo em andamento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (cicloAtual == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Nenhum ciclo em andamento agora.', style: TextStyle(color: Colors.grey.shade600)),
              ),
            )
          else
            Card(
              child: InkWell(
                onTap: () => context.push('/ciclos-abertos/${cicloAtual!.negociacaoId}'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                                '${_fmtData(cicloAtual!.periodoInicio)} — ${_fmtData(cicloAtual!.periodoFimPrevisto)}',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${_numero.format(cicloAtual!.quantidadeAbastecimentos)} abastecimentos · '
                          '${_moeda.format(cicloAtual!.valorAcumulado)}'),
                      if (cicloAtual!.quantidadePendenteNfe > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${cicloAtual!.quantidadePendenteNfe} sem NF-e ainda (${_moeda.format(cicloAtual!.valorPendenteNfe)}, fora do acumulado)',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text('Faturas (${faturas.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (faturas.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Nenhuma fatura ainda.', style: TextStyle(color: Colors.grey.shade600)),
              ),
            )
          else
            ...faturas.map((f) => _linhaFatura(context, f)),
        ],
      ),
    );
  }

  Widget _linhaFatura(BuildContext context, FaturaFinanceiro f) {
    final statusExib = _statusExibicao(f.status, f.vencimento);
    final cor = switch (statusExib) {
      'paga' => const Color(0xFF15803D),
      'vencida' => const Color(0xFFB91C1C),
      'cancelada' => Colors.grey,
      _ => const Color(0xFF92400E),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.push('/faturas/${f.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text('Vencimento: ${_fmtData(f.vencimento)}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_moeda.format(f.valorTotal), style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(_statusFaturaLabel[statusExib] ?? statusExib,
                      style: TextStyle(fontSize: 11, color: cor, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
