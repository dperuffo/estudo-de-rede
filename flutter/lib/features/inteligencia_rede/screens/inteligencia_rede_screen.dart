import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/inteligencia_rede_provider.dart';

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _numero = NumberFormat.decimalPattern('pt_BR');

// Fase FLT-3 — porta reduzida de inteligencia-rede/page.tsx (ver escopo
// completo, e o que ficou de fora, no comentário de
// inteligencia_rede_provider.dart).
class InteligenciaRedeScreen extends ConsumerWidget {
  const InteligenciaRedeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(inteligenciaRedeClienteProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Inteligência de Rede')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (dados) {
          if (dados == null) return const Center(child: Text('Nenhuma empresa selecionada.'));
          return _buildConteudo(dados);
        },
      ),
    );
  }

  Widget _buildConteudo(InteligenciaRedeDados d) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const Text('Visão geral da rede de postos que sua empresa já pesquisou/cadastrou, comparada com a referência ANP.',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _indicador('Postos na rede', _numero.format(d.totalPostos)),
            _indicador('Municípios', _numero.format(d.municipiosUnicos)),
            _indicador('Estados (UF)', _numero.format(d.estadosCobertos)),
          ],
        ),
        if (d.precoPorCombustivel.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Preço médio da rede por combustível', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('Preço mais recente de cada posto da rede, na média por combustível.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 10),
          ...d.precoPorCombustivel.map((p) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(p.combustivel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text('${p.qtdPostos} posto(s)'),
                  trailing: Text('${_moeda.format(p.precoMedio)}/L', style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              )),
        ],
        if (d.alertas.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Postos acima da referência ANP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('Maiores desvios de preço em relação à referência ANP (município/estado/Brasil).',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 10),
          ...d.alertas.map((a) => _linhaAlerta(a)),
        ],
        if (d.topMunicipios.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Top municípios da rede', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('Municípios com mais postos cadastrados na sua rede.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 10),
          ...d.topMunicipios.asMap().entries.map((e) => _linhaMunicipio(e.key + 1, e.value)),
        ],
        if (d.precoPorCombustivel.isEmpty && d.alertas.isEmpty && d.topMunicipios.isEmpty) ...[
          const SizedBox(height: 40),
          const Center(
            child: Text('Ainda não há dados de preço suficientes pra essa rede.', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ],
    );
  }

  Widget _linhaAlerta(PostoDesvioAnp a) {
    final corDesvio = a.diffPct >= 10 ? const Color(0xFFB91C1C) : const Color(0xFF92400E);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.razaoSocial, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text('${a.municipio ?? '—'}/${a.uf ?? '—'} · ${a.combustivel}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(height: 2),
                  Text(
                    '${_moeda.format(a.precoGf)}/L (ANP ${a.precoAnp == null ? '—' : _moeda.format(a.precoAnp)}/L · ${a.nivelAnp ?? '—'})',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('+${a.diffPct.toStringAsFixed(1)}%',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: corDesvio)),
          ],
        ),
      ),
    );
  }

  Widget _linhaMunicipio(int posicao, MunicipioRede m) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE3F2FD),
          child: Text('$posicao', style: const TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold)),
        ),
        title: Text('${m.municipio}/${m.uf}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        trailing: Text('${m.total} posto(s)', style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _indicador(String label, String valor, {Color? cor}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(valor,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cor),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
